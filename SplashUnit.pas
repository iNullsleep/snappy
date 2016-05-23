unit SplashUnit;

interface

uses
  Forms, Windows, Messages, Graphics, Classes, Controls, StdCtrls, ShellAPI, SnappyCore,
  jpeg, pngimage;

type
  TSplashForm = class(TForm)
    MailLabel: TLabel;
    JumpLabel: TLabel;
    VersionLabel: TLabel;
    CloseButton: TLabel;
    procedure FormPaint(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormShow(Sender: TObject);
    procedure FormMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FormKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure MailLabelClick(Sender: TObject);
    procedure JumpLabelClick(Sender: TObject);
    procedure CloseButtonClick(Sender: TObject);
    procedure LabelMouseEnter(Sender: TObject);
    procedure LabelMouseLeave(Sender: TObject);
    procedure CloseButtonMouseEnter(Sender: TObject);
    procedure CloseButtonMouseLeave(Sender: TObject);
    procedure VersionLabelClick(Sender: TObject);
  end;

const
  clAlmostWhite = $f0f0f0;
var
  SplashForm: TSplashForm;
  jpgSplash: TJPEGImage;
  pngTitle: TPNGObject;

implementation

uses MainUnit;

{$R *.dfm}


procedure TSplashForm.FormPaint(Sender: TObject);
begin
  with Canvas do
  begin
    Draw(0, 0, jpgSplash);
    Draw(150, 40, pngTitle);
    Rectangle(1, 1, ClientWidth - 1, ClientHeight - 1);

    Font.Name := Self.Font.Name;
    Font.Size := Self.Font.Size - 2;
    Font.Style := [];
    Font.Color := $3e3e3e; // dark gray (text)
    TextOut(148, 90, 'sharing snapshots has never been easier');
    Font.Color := clAlmostWhite;

    if (Tag = 1) then begin
      Font.Size := Self.Font.Size + 2;
      TextOut(188, 256, 'to take a tour');
      TextOut(234, 224, '+');

      Draw(177, 218, pngIcons[ctrlIcon]);
      Draw(250, 218, pngIcons[plainIcon]);

      Font.Name := 'Verdana';
      Font.Size := 8;
      Font.Style := [fsBold];
      Font.Color := clBlack;
      TextOut(257, 220, 'Prt');
      TextOut(256, 231, 'Scr');
    end
    else if (Tag = 0) then begin
      Font.Size := Self.Font.Size + 1;
      TextOut(14, 210, 'Feel free to send me some feedback:');
      TextOut(14, 254, 'Latest version can be downloaded at:');
    end;
  end;
end;  


procedure TSplashForm.FormCreate(Sender: TObject);
begin
  if compatibilityMode then begin
    Font.Name := 'Tahoma';
    Font.Size := 9;
    MailLabel.Top := 217;
    JumpLabel.Top := 275;
    VersionLabel.Top := 275;

    VersionLabel.Left := 432;
    CloseButton.Left := 446;

    Self.ClientWidth := 480;
    Self.ClientHeight := 300;
  end
  else begin
    Font.Name := 'Corbel';
    Font.Size := 10;
  end;

  jpgSplash := TJPEGImage.Create;
  LoadJpgRes(jpgSplash, 'SPLASH');

  Screen.Cursors[crHandPoint]:= LoadCursor(0, IDC_HAND);
  with Canvas do begin
    Brush.Style := bsClear;
    Font.Name := Self.Font.Name;
    Pen.Color := $525252; // gray (frame)
    Pen.Width := 3;
  end;
end;


procedure TSplashForm.FormShow(Sender: TObject);
var
  bSplashMode: Boolean;
begin
  Left := (Screen.Width - ClientWidth) div 2;
  Top := (Screen.Height - ClientHeight) div 2;

  bSplashMode := (Tag = 0);
  CloseButton.Visible := bSplashMode;
  MailLabel.Visible := bSplashMode;
  JumpLabel.Visible := bSplashMode;
  VersionLabel.Visible := bSplashMode;

  if bSplashMode then with VersionLabel do begin
    Caption := ver + ' ' + buildDate;
    Font.Name := 'Trebuchet MS';
    Font.Size := 8;
    Font.Color := clAlmostWhite;
    Cursor := crDefault;
    OnMouseEnter := nil;
    OnMouseLeave := nil;
  end;

  AnimateWindow(Handle, 500, AW_ACTIVATE or AW_BLEND);

  if bSplashMode and IsUpdateAvailable then with SplashForm.VersionLabel do begin
    Caption := '>> new version is available';
    Font.Name := Self.Font.Name;
    Font.Size := Self.Font.Size;
    Font.Color := $fff0c5; // bluish
    Cursor := crHandPoint;
    OnMouseEnter := SplashForm.LabelMouseEnter;
    OnMouseLeave := SplashForm.LabelMouseLeave;
  end;
end;


procedure TSplashForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  AnimateWindow(Handle, 350, AW_HIDE or AW_BLEND);
end;


procedure TSplashForm.FormMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  ReleaseCapture;
  Perform(WM_SYSCOMMAND, SC_MOVE or HTCAPTION, 0);
end;


procedure TSplashForm.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if (Key = VK_ESCAPE) then Close;
end;


procedure TSplashForm.MailLabelClick(Sender: TObject);
begin
  ShellExecute(0, 'open', 'mailto:inullsleep@gmail.com', nil, nil, SW_SHOW);
end;


procedure TSplashForm.JumpLabelClick(Sender: TObject);
begin
  ShellExecute(0, 'open', 'http://j.mp/getsnappy', nil, nil, SW_SHOW);
end;


procedure TSplashForm.VersionLabelClick(Sender: TObject);
begin
  if (VersionLabel.Cursor = crHandPoint) then begin
    VersionLabel.Caption := 'downloading...';
    Application.ProcessMessages;
    AutoUpdate;
  end;
end;


procedure TSplashForm.LabelMouseEnter(Sender: TObject);
begin
  (Sender as TLabel).Font.Style := [fsUnderline];
end;


procedure TSplashForm.LabelMouseLeave(Sender: TObject);
begin
  (Sender as TLabel).Font.Style := [];
end;


procedure TSplashForm.CloseButtonMouseEnter(Sender: TObject);
begin
  CloseButton.Font.Color := $f0f0f0;
end;


procedure TSplashForm.CloseButtonMouseLeave(Sender: TObject);
begin
  CloseButton.Font.Color := $3e3e3e;
end;


procedure TSplashForm.CloseButtonClick(Sender: TObject);
begin
  Self.Close;
end;


end.
