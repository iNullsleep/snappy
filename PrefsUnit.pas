unit PrefsUnit;

interface

uses
  Windows, Forms, ExtCtrls, StdCtrls, Graphics, Classes, ComCtrls, Controls, SysUtils,
  Menus, ShlObj, Prefs, SnappyCore;

type
  TPrefsForm = class(TForm)
    WipingTimer: TTimer;
    PrefLabel: TLabel;

    ActionPanel: TPanel;
    ActionLabel: TLabel;

    HotkeyPanel: TPanel;
    HotkeyLabel: TLabel;

    GeneralPanel: TPanel;
    GeneralLabel: TLabel;
    FStart: TLabel;
    FUninstall: TLabel;
    FStartCheck: TCheckBox;
    FUninstallIcon: TImage;

    OKBtn: TPanel;
    CancelBtn: TPanel;
    HotKeyBox: THotKey;
    FSaveFolder: TEdit;

    procedure FormPaint(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure CustomPanelMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure CustomPanelMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure OKBtnClick(Sender: TObject);
    procedure CancelBtnClick(Sender: TObject);
    procedure WipingTimerTimer(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FUninstallClick(Sender: TObject);
    procedure FUninstallMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FUninstallMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FSaveFolderClick(Sender: TObject);
  private
    procedure Appear;
    procedure Disappear;
    procedure WipingProcess;
  end;

type
  TWipe = record
    UseLeft: Boolean;
    Left, Top: Integer;
    Limit: Integer;
    Step: Integer;
  end;

var
  PrefsForm: TPrefsForm;

  // transition
  step, alphaStep: Integer;
  wipe: TWipe;
  closeAfter: Boolean;

  // browse dialog
  currentFolder: string;
  bDlgInit: Integer;


implementation

uses MainUnit;

{$R *.dfm}

function BrowseDialog(const Title: string): string;

  function BrowseCallbackProc(Wnd: HWND; uMsg: UINT;
    lParam, lpData: LPARAM): Integer stdcall;
  begin
    if (uMsg = BFFM_SELCHANGED) then
      if (bDlgInit < 3) then begin
        SendMessage(Wnd, BFFM_SETSELECTION, 1, Integer(currentFolder));
        PostMessage(Wnd, BFFM_SETSELECTION, 1, Integer(currentFolder));
        Inc(bDlgInit);
      end;

      if bDlgInit = 3 then
        SetWindowPos(Wnd, HWND_TOP, 0, 0, 350, 500, SWP_NOMOVE);

    Result := 0;
  end;

var
  lpItemID: PItemIDList;
  BrowseInfo: TBrowseInfo;
  DisplayName: array[0..MAX_PATH] of Char;
  TempPath: array[0..MAX_PATH] of Char;
begin
  Result := '';

  FillChar(BrowseInfo, SizeOf(TBrowseInfo), #0);
  with BrowseInfo do begin
    hwndOwner := PrefsForm.Handle;
    pszDisplayName := @DisplayName;
    lpszTitle := PChar(Title);
    ulFlags := BIF_RETURNONLYFSDIRS or BIF_USENEWUI;
    lpfn := @BrowseCallbackProc;
  end;

  bDlgInit := 0;
  lpItemID := SHBrowseForFolder(BrowseInfo);
  if (lpItemId <> nil) then begin
    SHGetPathFromIDList(lpItemID, TempPath);
    Result := TempPath;
    GlobalFreePtr(lpItemID);
  end
  else Result := '#error';
end;


function GetWipeDirection(const CW, CH: Integer): TWipe;

  procedure SetWipe(var w: TWipe; UseLeft: Boolean;
    Left, Top, Limit: Integer);
  begin
    w.UseLeft := UseLeft;
    w.Left := Left;
    w.Top := Top;
    w.Limit := Limit;
  end;

const
  absStep = 19;
  dAlpha = 200 * absStep;
var
  taskBar: TRect;
  SW, SH: Integer;
begin
  SW := GetSystemMetrics(SM_CXSCREEN);
  SH := GetSystemMetrics(SM_CYSCREEN);
  GetWindowRect(FindWindow('Shell_TrayWnd', nil), taskBar);

  if (taskBar.Left <= 0) and (taskBar.Top <= 0) then begin
    Result.Step := absStep;

    // taskbar on the top
    if (taskBar.Right > taskBar.Bottom) then begin
      alphaStep := dAlpha div (CH + taskBar.Bottom);
      SetWipe(Result, False, SW - CW, -CH, taskBar.Bottom)
    end
    // taskbar on the left  
    else begin
      alphaStep := dAlpha div (CW + taskBar.Right);
      SetWipe(Result, True, -CW, SH - CH, taskBar.Right);
    end;
  end
  else begin
    Result.Step := -absStep;

    // taskbar on the bottom
    if (taskBar.Left = 0) then begin
      alphaStep := dAlpha div (SH - taskBar.Top + CH);
      SetWipe(Result, False, SW - CW, SH, taskBar.Top - CH)
    end
    // taskbar on the right
    else begin
      alphaStep := dAlpha div (SW - taskBar.Left + CW);
      SetWipe(Result, True, SW, SH - CH, taskBar.Left - CW);
    end;
  end;
end;


procedure TPrefsForm.Appear;
begin
  // showing off
  wipe := GetWipeDirection(ClientWidth, ClientHeight);

  Left := wipe.Left;
  Top := wipe.Top;
  step := wipe.Step;
  AlphaBlendValue := 20;
  closeAfter := False;
  
  WipingTimer.Enabled := True;
end;


procedure TPrefsForm.Disappear;
begin
  // going back
  step := -wipe.Step;
  alphaStep := -alphaStep;

  if wipe.UseLeft then wipe.Limit := wipe.Left
  else wipe.Limit := wipe.Top;

  closeAfter := True;
  WipingTimer.Enabled := True;
end;


procedure TPrefsForm.WipingProcess;
var
  leftOrTop: Integer;
begin
  if wipe.UseLeft then begin
    Left := Left + step;
    leftOrTop := Left;
  end
  else begin
    Top := Top + step;
    leftOrTop := Top;
  end;

  if AlphaBlend then AlphaBlendValue := AlphaBlendValue + alphaStep;

  // (A and B) or (!A and !B)
  if not (step > 0) xor (leftOrTop >= wipe.Limit) then begin
    WipingTimer.Enabled := False;
    if closeAfter then Close;
   // else SetForegroundWindow(Handle);
  end;
end;


procedure TPrefsForm.FormCreate(Sender: TObject);
const
  clPlasmaBlue = $FFA020;
begin
  if compatibilityMode then begin
    Self.Color := $202020;
    Self.AlphaBlend := False;
  end
  else begin
    Self.Color := clBlack;
    Self.AlphaBlend := True;
  end;

  Canvas.Pen.Color := clPlasmaBlue;
  Canvas.Pen.Width := 3;
  Application.HintHidePause := 7000;
  Application.HintPause := 150;
end;


procedure TPrefsForm.FormPaint(Sender: TObject);
begin
  Canvas.Rectangle(1, 1, ClientWidth - 1, ClientHeight - 1);
end;


procedure TPrefsForm.WipingTimerTimer(Sender: TObject);
begin
  WipingProcess;
end;


procedure TPrefsForm.CustomPanelMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then begin
    (Sender as TPanel).Top := (Sender as TPanel).Top - 1;
    (Sender as TPanel).BevelOuter := bvLowered;
  end;
end;


procedure TPrefsForm.CustomPanelMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then begin
    (Sender as TPanel).Top := (Sender as TPanel).Top + 1;
    (Sender as TPanel).BevelOuter := bvRaised;
  end;
end;


procedure TPrefsForm.FUninstallMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then begin
    FUninstall.Top := FUninstall.Top - 1;
    FUninstallIcon.Top := FUninstall.Top;
  end;
end;


procedure TPrefsForm.FUninstallMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then begin
    FUninstall.Top := FUninstall.Top + 1;
    FUninstallIcon.Top := FUninstall.Top;
  end;
end;


{==================================================================================================
 ==================================================================================================}


procedure TPrefsForm.FormShow(Sender: TObject);
begin
  LoadPrefs;

  with MainForm do begin
    FStartCheck.Checked := bAutoStart;
    FSaveFolder.Text := SaveFolder;

    if bUserHotkey then HotKeyBox.HotKey := HotkeyInfo
    else HotKeyBox.HotKey := 0;

    currentFolder := SaveFolder;
    FSaveFolder.Text := SaveFolder;
  end;

  Appear;
end;


procedure TPrefsForm.OKBtnClick(Sender: TObject);
begin
  with MainForm do begin
    bAutoStart := FStartCheck.Checked;
    bUserHotkey := (HotKeyBox.HotKey <> 0);

    UnregisterHotKey(Handle, wUserAtom);
    if bUserHotkey then begin
      HotkeyInfo := HotKeyBox.HotKey;
      RegisterShortCut(HotkeyInfo);
    end;

    StartWithWindows(bAutoStart);
    SavePref(pHotkey);

    SaveFolder := currentFolder;
    SavePref(pSaveFolder);
  end;

  Disappear;
end;


procedure TPrefsForm.CancelBtnClick(Sender: TObject);
begin
  Disappear;
end;


procedure TPrefsForm.FUninstallClick(Sender: TObject);
const
  Msg = 'Are you sure you want to uninstall snappy ' + ver + '?';
begin
  if (MessageBox(Handle, Msg, 'Uninstall snappy',
    MB_ICONWARNING or MB_YESNO) = IDYES) then Uninstall;
end;


procedure TPrefsForm.FSaveFolderClick(Sender: TObject);
var
  s: string;
begin
  ForceDirectories(currentFolder);
  s := BrowseDialog('Choose a folder for saving snapshots:');
  if (s <> '#error') then begin
    currentFolder := s;
    FSaveFolder.Text := s;
  end;
end;

end.

