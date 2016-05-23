unit MainUnit;

interface

uses
  Forms, Messages, SysUtils, Windows, Graphics, Controls, ExtCtrls, Classes, XPMan,
  ShellAPI, Registry, Menus, MMSystem, ClipBrd, pngimage, SnappyCore, Prefs, UpThread;

const
  ver = 'v.1.4.3';
  buildDate = '(Dec 1, 2014)';

  clPlasmaBlue = $FFA020;
  crPencil = 7;

  WM_NOTIFYICON = WM_USER + 707;
  WM_SUICIDE = WM_USER + 708;

  recentItemsCount = 15;
type
  TMainForm = class(TForm)
    DimmingTimer: TTimer;
    CloudTimer: TTimer;
    URLMenu: TPopupMenu;
    PopupMenu: TPopupMenu;
    TakeSnapMenu: TMenuItem;
    PrefMenu: TMenuItem;
    N5: TMenuItem;
    HelpMenu: TMenuItem;
    AboutMenu: TMenuItem;
    N2: TMenuItem;
    ExitMenu: TMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure FormMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FormMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure FormMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure ExitMenuClick(Sender: TObject);
    procedure TakeSnapMenuClick(Sender: TObject);
    procedure DimmingTimerTimer(Sender: TObject);
    procedure AboutMenuClick(Sender: TObject);
    procedure CloudTimerTimer(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure PrefMenuClick(Sender: TObject);
    procedure HelpMenuClick(Sender: TObject);
    procedure FormKeyUp(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
  private
    function WMTaskbarCreated(var Msg: TMessage): Boolean;
    procedure WMHotKey(var Msg: TMessage); message WM_HOTKEY;
    procedure WMNotifyIcon(var Msg: TMessage); message WM_NOTIFYICON;
    procedure WMSuicide(var Msg: TMessage); message WM_SUICIDE;

    procedure Appear;
    procedure Disappear;
    procedure GoForIt(const forcePNG: Boolean);
    procedure MenuItemClick(Sender: TObject);
    procedure PauseDesktop;
    procedure RefreshCanvas;
  public
    bAutoStart: Boolean;
    bUserHotkey: Boolean;
    HotkeyInfo: TShortCut;
    SaveFolder: string;
    PicturesFolder: string;

    procedure ErrorBalloon;
    procedure LoadGuideMode;
    procedure NewRecentItem(const url: string);
    procedure SuccessBalloon(const title, text: string);
  end;

const
  pngIconsCount = 5;

  leftClickIcon = 1;
  rightClickIcon = 2;
  drawIcon = 3;
  plainIcon = 4;
  ctrlIcon = 5;

  tmInvToLight = 1;
  tmLightToDark = 2;

  invisibleValue = 244;
  lightDarkValue = 146;
  darkValue = 41;
  dimmingStep = 7;

  defaultNotifyFlags = NIF_MESSAGE or NIF_TIP or NIF_ICON;
var
  MainForm: TMainForm;
  // in case of running Win XP
  compatibilityMode: Boolean;
  menuHook: HHOOK;

  // tray info
  tray: NOTIFYICONDATA;
  trayIcon: TIcon;
  trayIconIndex: Byte = 0;

  // shortcut atoms
  wAtom: Integer;
  wUserAtom: Integer;
  // number of recent URLs in menu
  linksCount: Integer = 0;

  // bitmaps
  virtualLeft, virtualTop: Integer;
  scrOrig, scrDark, scrBuf: TBitmap;
  scrPiece, scrThumb: TBitmap;
  pngThumbs: array[0..recentItemsCount - 1] of TPNGObject;

  // old coordinates
  iX, iY: Integer;
  // selection coordinates
  selRect: TRect;
  activeWindow: HWND = INVALID_HANDLE_VALUE;
  windowUnderCursor: HWND = INVALID_HANDLE_VALUE;

  // state flags
  bSelecting: Boolean = False;
  bShot: Boolean = False;
  bDrawing: Boolean = False;
  bGuideMode: Boolean;
  transLimit: Byte;

  // guide icons
  pngIcons: array[1..pngIconsCount] of TPNGObject;

  // brush
  pngBrush: TPNGObject;
  undoCount: Integer = -1;
  scrUndo: array of TBitmap;

implementation

uses SplashUnit, PrefsUnit, PreviewUnit;

{$R *.dfm}

procedure ChangeTrayIcon(const num: Byte);
var
  res: TResourceStream;
begin
  res := TResourceStream.Create(HInstance, 't' + IntToStr(num), 'TRAY');
  trayIcon.LoadFromStream(res);
  res.Free;

  tray.hIcon := trayIcon.Handle;
end;


procedure AddTrayIcon;
const
  NOTIFYICONDATA_V3_SIZE = 504;
begin
  with Tray do begin
    union.uVersion := NOTIFYICON_VERSION;
    cbSize := NOTIFYICONDATA_V3_SIZE;
    Wnd := MainForm.Handle;
    uID := Wnd + 1;
    uFlags := defaultNotifyFlags;
    uCallbackMessage := WM_NOTIFYICON;
    szTip := 'snappy'#0;
    ChangeTrayIcon(trayIconIndex);
  end;

  Shell_NotifyIcon(NIM_ADD, @Tray);
end;


function TMainForm.WMTaskbarCreated(var Msg: TMessage): Boolean;
begin
  Result := False;
  if (Msg.Msg = RegisterWindowMessage('TaskbarCreated')) then AddTrayIcon;
end;


function CallWndRetProc(Code, Flag, PData: Integer): Integer; stdcall;
var
  w0, c, index: Integer;
  hPopup: TPopupMenu;
begin
  with PCWPRetStruct(PData)^ do

    if (message = WM_MENUSELECT) then begin
      hPopup := MainForm.URLMenu;

      if (HMENU(lParam) = hPopup.Handle) then begin
        w0 := GetMenuItemID(hPopup.Handle, 0);
        c := hPopup.Items.Count;
        index := (c + w0 - LOWORD(wParam)) mod c;
        PreviewForm.PreviewImage.Picture.Assign(pngThumbs[index]);
        PreviewForm.Reposition;
      end
      else with PreviewForm do if Visible then Close;
    end;

  Result := CallNextHookEx(menuHook, Code, Flag, PData);
end;


procedure TMainForm.WMNotifyIcon(var Msg: TMessage);
begin
  case Msg.LParam of
    WM_LBUTTONUP: if (linksCount > 0) then begin
      with PreviewForm do if not Visible then Show;

      SetForegroundWindow(SplashForm.Handle);
      with Mouse.CursorPos do URLMenu.Popup(X, Y);
      SendMessage(SplashForm.Handle, WM_NULL, 0, 0);
    end;

    WM_RBUTTONUP: begin
      SetForegroundWindow(SplashForm.Handle);
      with Mouse.CursorPos do PopupMenu.Popup(X, Y);
      SendMessage(SplashForm.Handle, WM_NULL, 0, 0);
    end;
  end;
end;


procedure TMainForm.WMSuicide(var Msg: TMessage);
begin
   Self.Close;
end;


procedure BitCopy(dest, src: TBitmap; destLeft, destTop, w, h: Integer;
  srcLeft: Integer = 0; srcTop: Integer = 0);
begin
  BitBlt(Dest.Canvas.Handle, destLeft, destTop, w, h,
    Src.Canvas.Handle, srcLeft, srcTop, SRCCOPY);
end;


procedure CutPiece;
begin
  with selRect do begin
    scrPiece.Width := Right - Left + 1;
    scrPiece.Height := Bottom - Top + 1;
    BitCopy(scrPiece, scrOrig, 0, 0, scrPiece.Width, scrPiece.Height, Left, Top);
  end;
end;


procedure ShowBalloonTip(iconType: Cardinal; const title, text: string);
begin
  with Tray do begin
    uFlags := defaultNotifyFlags;
    szInfo := #0;
    Shell_NotifyIcon(NIM_MODIFY, @Tray);

    dwInfoFlags := iconType;
    uFlags := defaultNotifyFlags or NIF_INFO;
    StrCopy(szInfo, PChar(text));
    StrCopy(szInfoTitle, PChar(title));
    Shell_NotifyIcon(NIM_MODIFY, @Tray);

    uFlags := defaultNotifyFlags;
    szInfo := #0;
    Shell_NotifyIcon(NIM_MODIFY, @Tray);
  end;
end;


procedure TMainForm.SuccessBalloon(const title, text: string);
begin
  ShowBalloonTip(NIIF_INFO, title, text);
  PlaySound(PChar(SND_ALIAS_SYSTEMASTERISK), 0, SND_ALIAS_ID);
end;


procedure TMainForm.ErrorBalloon;
begin
  ShowBalloonTip(NIIF_ERROR, 'Error', 'Something is really wrong here...');
  PlaySound(PChar(SND_ALIAS_SYSTEMHAND), 0, SND_ALIAS_ID);
end;


procedure NewThumbnail;
var
  i: Integer;
begin
  if (linksCount > 1) then begin
    for i := linksCount - 1 downto 1 do
      pngThumbs[i].Assign(pngThumbs[i - 1]);
    pngThumbs[0].Assign(scrThumb);
  end
  else pngThumbs[0].Assign(scrThumb);
end;


procedure TMainForm.NewRecentItem(const url: string);
var
  newItem: TMenuItem;
begin
  if (linksCount < recentItemsCount) then Inc(linksCount)
  else begin
    newItem := URLMenu.Items[linksCount - 1];
    URLMenu.Items.Remove(newItem);
    newItem.Free;
  end;

  NewThumbnail;
  newItem := TMenuItem.Create(URLMenu);
  URLMenu.Items.Insert(0, newItem);
  newItem.Caption := url;
  newItem.Default := True;
  newItem.OnClick := MenuItemClick;
end;


procedure AlphaTransition(const transMode: Byte);
begin
  with MainForm.DimmingTimer do begin
    Enabled := False;

    case transMode of
      tmInvToLight: begin
        Tag := invisibleValue;
        transLimit := lightDarkValue;
      end;

      tmLightToDark: begin
        Tag := lightDarkValue;
        transLimit := darkValue;
      end;
    end;

    Enabled := True;
  end;
end;


procedure MakeDarkScreenshot(const mode: Byte);
var
  blendFunc: BLENDFUNCTION;
begin
  with blendFunc do begin
    BlendOp := AC_SRC_OVER;
    BlendFlags := 0;
    SourceConstantAlpha := mode;
    AlphaFormat := 0;
  end;

  with scrDark do begin
    BitBlt(Canvas.Handle, 0, 0, Width, Height,
      0, virtualLeft, virtualTop, BLACKNESS);

    AlphaBlend(Canvas.Handle, 0, 0, Width, Height,
      scrOrig.Canvas.Handle, 0, 0, scrOrig.Width, scrOrig.Height, blendFunc);
  end;
end;


procedure ZeroRect(var rect: TRect);
begin
  with rect do begin
    Left := 0;
    Top := 0;
    Right := 0;
    Bottom := 0;
  end;
end;


procedure FreeUndoBuffers;
var
  i: Integer;
begin
  for i := 0 to undoCount do scrUndo[i].Free;
  undoCount := -1;
end;


procedure FreeImages;
begin
  scrOrig.FreeImage;
  scrDark.FreeImage;
  scrBuf.FreeImage;
  scrPiece.FreeImage;

  ZeroRect(selRect);
end;


procedure TMainForm.Appear;
begin
  Self.Left := virtualLeft;
  Self.Top := virtualTop;
  Self.Width := scrOrig.Width;
  Self.Height := scrOrig.Height;

  MakeDarkScreenshot(invisibleValue);
  Show;
  RefreshCanvas;
  AlphaTransition(tmInvToLight);

  // take focus from some cheeky menu
  mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0);
  mouse_event(MOUSEEVENTF_RIGHTUP, 0, 0, 0, 0);
  Sleep(10);
  mouse_event(MOUSEEVENTF_MIDDLEDOWN, 0, 0, 0, 0);
  mouse_event(MOUSEEVENTF_MIDDLEUP, 0, 0, 0, 0);
end;


procedure TMainForm.Disappear;
begin
  bShot := False;
  if bGuideMode then begin
    bGuideMode := False;
    LoadPrefs;
  end;

  Hide;
  SetForegroundWindow(activeWindow);

  FreeImages;
  FreeUndoBuffers;
end;


procedure TMainForm.GoForIt(const forcePNG: Boolean);

  procedure CreateThumbnail;
  const
    wLimit = 300;
    hLimit = 170;
  begin
    with scrPiece do if (Width > wLimit) or (Height > hLimit) then begin
      if (Width / Height >= wLimit / hLimit) then begin
        scrThumb.Width := wLimit;
        scrThumb.Height := wLimit * Height div Width
      end
      else begin
        scrThumb.Width := hLimit * Width div Height;
        scrThumb.Height := hLimit;
      end;
    end
    else begin
      scrThumb.Width := Width;
      scrThumb.Height := Height;
    end;

    with scrThumb do begin
      SetStretchBltMode(Canvas.Handle, HALFTONE);
      StretchBlt(Canvas.Handle, 0, 0, Width, Height, scrPiece.Canvas.Handle,
      0, 0, scrPiece.Width, scrPiece.Height, SRCCOPY);
    end;
  end;

begin
  CreateThumbnail;
  Disappear; 

  CloudTimer.Interval := 67;
  with TUpThread.Create(True, forcePNG) do begin
    FreeOnTerminate := True;
    Resume;
  end;
end;


procedure TMainForm.PauseDesktop;

  procedure TakeScreenshot;
  var
    dc: HDC;
  begin
    dc := CreateDC('DISPLAY', nil, nil, nil);
    virtualLeft := GetSystemMetrics(SM_XVIRTUALSCREEN);
    virtualTop := GetSystemMetrics(SM_YVIRTUALSCREEN);
    with scrOrig do begin
      Width := GetSystemMetrics(SM_CXVIRTUALSCREEN);
      Height := GetSystemMetrics(SM_CYVIRTUALSCREEN);
      BitBlt(Canvas.Handle, 0, 0, Width, Height,
        0, virtualLeft, virtualTop, BLACKNESS);
      BitBlt(Canvas.Handle, 0, 0, Width, Height,
        dc, virtualLeft, virtualTop, SRCCOPY);
    end;
    DeleteDC(dc);

    scrDark.Width := scrOrig.Width;
    scrDark.Height := scrOrig.Height;

    scrBuf.Width := scrOrig.Width;
    scrBuf.Height := scrOrig.Height;
  end;

begin
  if MainForm.Visible then Exit;

  // Tag = 1 means that it's not the 'About' window
  with SplashForm do if Visible and (Tag = 1) then Close;

  // remember windows handles
  activeWindow := GetForegroundWindow;
  windowUnderCursor := GetAncestor(WindowFromPoint(Mouse.CursorPos), GA_ROOT);

  TakeScreenshot;
  Appear;
end;


procedure TMainForm.WMHotKey(var Msg: TMessage);
begin
  PauseDesktop;
  inherited;
end;


procedure TMainForm.LoadGuideMode;
var
  i: Integer;
begin
  for i := 1 to pngIconsCount do
  begin
    pngIcons[i] := TPNGObject.Create;
    LoadPngRes(pngIcons[i], 'p' + IntToStr(i));
  end;

  SplashForm.Tag := 1;
  SplashForm.Show;
end;


{==================================================================================================
 ==================================================================================================}


procedure DrawGuide;

  procedure ShTextOut(const x, y: Integer; const text: string);
  const
    clDarkGray = $202020;
  begin
    with scrBuf.Canvas do begin
      Font.Name := 'Corbel';
      Font.Size := 15;
      Font.Style := [];

      Font.Color := clDarkGray;
      TextOut(x, y, text);

      Font.Color := clwhite;
      TextOut(x - 2, y - 1, text);

      Font.Name := 'Verdana';
      Font.Size := 11;
      Font.Style := [fsBold];
      Font.Color := clBlack;
    end;
  end;

const
  blockLength = 372;
var
  aW, aH: Integer;
  l, t: Integer;
  indent: Integer;
begin
  with scrBuf.Canvas do begin
    if not bShot then begin
      if not bSelecting then begin
        aW := scrBuf.Width div 4;
        aH := scrBuf.Height * 2 div 7;
        l := (scrBuf.Width - aW) div 4;
        t := (scrBuf.Width - aH) div 5;

        ShTextOut(l + 52, t - 40, 'select  a  region');
        Draw(l + 10, t - 44, pngIcons[leftClickIcon]);
        // dotted frame
        Pen.Style := psDot;
        Pen.Color := $f0f0f0;
        Rectangle(l, t, l + aW, t + aH);
      end;
    end
    else begin
      if (undoCount > -1) then begin
        // ctrl+z
        Draw(selRect.Left + 10, selRect.Top - 45, pngIcons[ctrlIcon]);
        ShTextOut(selRect.Left + 72, selRect.Top - 42, '+');

        Draw(selRect.Left + 88, selRect.Top - 45, pngIcons[plainIcon]);
        ShTextOut(selRect.Left + 134, selRect.Top - 42, '-  undo');
        TextOut(selRect.Left + 99, selRect.Top - 39, 'Z');
      end
      else begin
        // pencil icon
        ShTextOut(selRect.Left + 56, selRect.Top - 42, 'draw  something  inside');
        Draw(selRect.Left + 10, selRect.Top - 46, pngIcons[drawIcon]);
      end;

      indent := selRect.Left + (selRect.Right - selRect.Left) div 2 - blockLength div 2;

      // right click
      Draw(indent + 8, selRect.Bottom + 20, pngIcons[rightClickIcon]);
      ShTextOut(indent + 46, selRect.Bottom + 20, '-  upload');

      // escape
      Draw(indent, selRect.Bottom + 66, pngIcons[plainIcon]);
      ShTextOut(indent + 46, selRect.Bottom + 70, '-  cancel');
      Font.Size := 9;
      TextOut(indent + 6, selRect.Bottom + 74, 'Esc');
      Font.Size := 11;

      // ctrl+s
      Draw(indent + 180, selRect.Bottom + 16, pngIcons[ctrlIcon]);
      ShTextOut(indent + 242, selRect.Bottom + 19, '+');

      Draw(indent + 258, selRect.Bottom + 16, pngIcons[plainIcon]);
      ShTextOut(indent + 304, selRect.Bottom + 19, '-  save');
      TextOut(indent + 269, selRect.Bottom + 22, 'S');

      // ctrl+c
      Draw(indent + 180, selRect.Bottom + 66, pngIcons[ctrlIcon]);
      ShTextOut(indent + 242, selRect.Bottom + 69, '+');

      Draw(indent + 258, selRect.Bottom + 66, pngIcons[plainIcon]);
      ShTextOut(indent + 304, selRect.Bottom + 69, '-  copy');
      TextOut(indent + 269, selRect.Bottom + 72, 'C');
    end;
  end;
end;


procedure TMainForm.RefreshCanvas;
begin
  BitCopy(scrBuf, scrDark, 0, 0, scrDark.Width, scrDark.Height);
  if bGuideMode then DrawGuide;

  with selRect do begin
    if bSelecting then
      BitCopy(scrBuf, scrOrig, Left, Top, Right - Left + 1, Bottom - Top + 1, Left, Top);

    if bShot then
      BitCopy(scrBuf, scrPiece, Left, Top, scrPiece.Width, scrPiece.Height);

    if bSelecting or bShot then begin
      scrBuf.Canvas.Pen.Style := psSolid;
      scrBuf.Canvas.Pen.Color := clPlasmaBlue;
      scrBuf.Canvas.Rectangle(Left, Top, Right + 1, Bottom + 1);
    end;

    BitBlt(Self.Canvas.Handle, 0, 0, scrBuf.Width, scrBuf.Height,
      scrBuf.Canvas.Handle, 0, 0, SRCCOPY);
  end;
end;


procedure TMainForm.CloudTimerTimer(Sender: TObject);
begin
  // changing tray icon by looping index
  Inc(trayIconIndex);
  if (trayIconIndex > 16) then trayIconIndex := 0;

  ChangeTrayIcon(trayIconIndex);
  Shell_NotifyIcon(NIM_MODIFY, @tray);
end;


procedure TMainForm.DimmingTimerTimer(Sender: TObject);
begin
  with DimmingTimer do begin
    if (Tag = transLimit) then Enabled := False;
    Tag := Tag - dimmingStep;

    MakeDarkScreenshot(Tag);
    RefreshCanvas;
  end;
end;


procedure TMainForm.FormCreate(Sender: TObject);

  procedure CreateBitmaps;
  var
    i: Integer;
  begin
    scrThumb := TBitmap.Create;
    scrOrig := TBitmap.Create;

    scrDark := TBitmap.Create;
    scrDark.Canvas.Brush.Color := clBlack;

    scrBuf := TBitmap.Create;
    scrBuf.Canvas.Brush.Style := bsClear;
    scrBuf.Canvas.Pen.Color := clPlasmaBlue;

    scrPiece := TBitmap.Create;

    for i := 0 to recentItemsCount - 1 do
      pngThumbs[i] := TPNGObject.Create;
  end;

const
  CSIDL_MYPICTURES = $0027;
begin
  Randomize;
  // hook taskbar creation in case of Explorer crash
  Application.HookMainWindow(WMTaskbarCreated);

  trayIcon := TIcon.Create;
  AddTrayIcon;
  Screen.Cursors[crPencil] := LoadCursor(hInstance, 'pencil');
  Screen.Cursors[crCross] := LoadCursor(hInstance, 'region');

  compatibilityMode := RunningWinXP;
  PicturesFolder := GetFolder(CSIDL_MYPICTURES) + '\snappy';
  LoadPrefs;
  CreateBitmaps;

  // register shortcuts
  wUserAtom := GlobalAddAtom('snappy');
  RegisterHotKey(MainForm.Handle, wUserAtom, MOD_CONTROL, VK_SNAPSHOT);
  if bUserHotkey then begin
    wUserAtom := GlobalAddAtom('snappy_user');
    RegisterShortCut(HotkeyInfo);
  end;

  // load brush from resources
  pngBrush := TPNGObject.Create;
  LoadPngRes(pngBrush, 'brush');

  // splash window
  pngTitle := TPNGObject.Create;
  LoadPngRes(pngTitle, 'title');

  menuHook := SetWindowsHookEx(WH_CALLWNDPROCRET, CallWndRetProc, 0, GetCurrentThreadId);
end;


procedure TMainForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
var
  i: Integer;
begin
  UnhookWindowsHookEx(menuHook);

  UnregisterHotKey(MainForm.Handle, wAtom);
  GlobalDeleteAtom(wAtom);
  if bUserHotkey then begin
    UnregisterHotKey(MainForm.Handle, wUserAtom);
    GlobalDeleteAtom(wUserAtom);
  end;

  Shell_NotifyIcon(NIM_DELETE, @tray);
  trayIcon.Free;

  scrOrig.Free;
  scrDark.Free;
  scrBuf.Free;
  scrPiece.Free;
  pngBrush.Free;

  if Assigned(pngIcons[1]) then
    for i := 1 to pngIconsCount do pngIcons[i].Free;
end;


procedure TMainForm.FormKeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);

  procedure ActiveWindowScreenshot;
  begin
    if (activeWindow = PrefsForm.Handle)
    or (activeWindow = SplashForm.Handle) then
      activeWindow := windowUnderCursor;

    with selRect do begin
      if not GetWindowRect(activeWindow, selRect)
      or (Abs(Right - Left) < 1) or (Abs(Bottom - Top) < 1) then
        GetWindowRect(GetDesktopWindow, selRect);

      Left := Left - virtualLeft;
      Top := Top - virtualTop;
      Right := Right - virtualLeft - 1;
      Bottom := Bottom - virtualTop - 1;
    end;
  end;
  
begin
  if not bShot and (Key = VK_SPACE) then begin
    ActiveWindowScreenshot;
    CutPiece;
    RefreshCanvas;
    bShot := True;
    AlphaTransition(tmLightToDark);
  end;

  if bShot and (Key = VK_RETURN) then GoForIt(False);
end;


procedure TMainForm.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);

  procedure BrushUndo;
  begin
    if undoCount = -1 then Exit;

    BitCopy(scrPiece, scrUndo[undoCount], 0, 0, scrPiece.Width, scrPiece.Height);
    // delete the last undo-buffer
    scrUndo[undoCount].Free;
    Dec(undoCount);
    SetLength(scrUndo, undoCount + 1);

    RefreshCanvas;
  end;

begin
  if bShot and (ssCtrl in Shift) then begin
    case Chr(Key) of
      'Z': if not bDrawing then BrushUndo;
      'C': begin
        Disappear;
        Clipboard.Assign(scrPiece);
        SuccessBalloon('Copied', 'Your image has been copied to the clipboard.')
      end;
      'S': begin
        Disappear;
        SaveImage(scrPiece, SaveFolder);
        SuccessBalloon('Saved', SaveFolder);
      end;
    end;

    Exit;
  end;

  if (Key = VK_ESCAPE) then begin
    if bSelecting then begin
      bSelecting := False;
      RefreshCanvas;
    end
    else begin
      if bShot then begin
        bShot := False;
        DimmingTimer.Enabled := False;
        MakeDarkScreenshot(lightDarkValue);
        RefreshCanvas;
        FreeUndoBuffers;
        Self.Cursor := crCross;
      end
      else Disappear;

      bDrawing := False;
    end;
  end;
end;


function InsideSelection(const X, Y: Integer): Boolean;
begin
  with selRect do
    Result := ((Left < X) and (X < Right))
      and ((Top < Y) and (Y < Bottom));
end;


procedure TMainForm.FormMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);

  procedure BrushBeginDraw;
  begin
    // create new undo-buffer
    Inc(undoCount);
    SetLength(scrUndo, undoCount + 1);

    scrUndo[undoCount] := TBitmap.Create;
    with scrPiece do begin
      scrUndo[undoCount].Width := Width;
      scrUndo[undoCount].Height := Height;
      BitCopy(scrUndo[undoCount], scrPiece, 0, 0, Width, Height);
    end;
  end;

begin
  if (Button = mbLeft) then begin
    if bShot then begin
      if InsideSelection(X, Y) then begin
        BrushBeginDraw;
        iX := X ;
        iY := Y ;
        bDrawing := True;
        Exit;
      end
      else begin
        DimmingTimer.Enabled := False;
        MakeDarkScreenshot(lightDarkValue);
        bShot := False;
        RefreshCanvas;
        bSelecting := True;
        FreeUndoBuffers;
      end;
    end
    else begin
      bSelecting := True;
      ZeroRect(selRect);
      RefreshCanvas;
    end;

    iX := X;
    iY := Y;
  end;
end;


procedure TMainForm.FormMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  forcePNG: Boolean;
begin
  if (Button = mbLeft) then begin
    if bDrawing then begin
      with selRect do scrPiece.Canvas.Draw(X - Left - 1, Y - Top - 1, pngBrush);////////////////
      RefreshCanvas;
      bDrawing := False;
    end;

    if bSelecting then begin
      bSelecting := False;

      if (X <> iX) and (Y <> iY) then begin
        CutPiece;
        bShot := True;
        AlphaTransition(tmLightToDark);
      end
      else RefreshCanvas;
    end;
  end;

  if (Button = mbRight) and bShot then begin
    forcePNG := (X < 5) and (Y < 5);
    GoForIt(forcePNG);
  end;
end;


procedure TMainForm.FormMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);

  function BrushDraw: Boolean;
  var
    dx, dy: Integer;
  begin
    Result := False;
    dx := Abs(X - iX);
    dy := Abs(Y - iY);

    if (dx > 2) or (dy > 2) then
    begin
      with selRect do DrawLine(scrPiece, pngBrush, iX - Left, iY - Top, X - Left, Y - Top);
      RefreshCanvas;
      Result := True;
    end;
  end;

  procedure GetSelectionRect(const X, Y: Integer);
  begin
    with selRect do begin
      Left := Min(iX, X);
      Right := Max(iX, X);
      Top := Min(iY, Y);
      Bottom := Max(iY, Y);
    end;
  end;

var
  newCoordinates: Boolean;
begin
  if bShot and InsideSelection(X, Y) then Cursor := crPencil
  else Cursor := crCross;

  if bDrawing then begin
    if InsideSelection(iX, iY) or InsideSelection(X, Y) then 
      newCoordinates := BrushDraw
    else newCoordinates := True;

    if newCoordinates then begin
      iX := X;
      iY := Y;
    end;
  end;

  if bSelecting then begin
    GetSelectionRect(X, Y);
    //if (Right <> Left) and (Bottom <> Top) then
    RefreshCanvas;
  end;
end;


procedure TMainForm.MenuItemClick(Sender: TObject);
var
  url: string;
begin
  url := (Sender as TMenuItem).Caption;
  SetClipboardText(url);
  SuccessBalloon('Copied', url);
end;


procedure TMainForm.ExitMenuClick(Sender: TObject);
begin
  Self.Close;
end;


procedure TMainForm.TakeSnapMenuClick(Sender: TObject);
begin
  Sleep(300);
  PauseDesktop;
end;


procedure TMainForm.AboutMenuClick(Sender: TObject);
begin
  if not SplashForm.Visible then begin
    bGuideMode := False;
    SplashForm.Tag := 0;
    SplashForm.Show;
  end;
end;


procedure TMainForm.PrefMenuClick(Sender: TObject);
begin
  with PrefsForm do if not Visible then Show;
end;


procedure TMainForm.HelpMenuClick(Sender: TObject);
begin
  if not SplashForm.Visible then begin
    bGuideMode := True;
    LoadGuideMode;
  end;
end;


end.

