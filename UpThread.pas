unit UpThread;

interface

uses
  Windows, ShellAPI, Classes, SnappyCore;

type
  TUpThread = class(TThread)
  private
    FURL: string;
    FForcePNG: Boolean;
    procedure CallNewUpload;
  public
    constructor Create(CreateSuspended: Boolean; forcePng: Boolean); overload;
  protected
    procedure Execute; override;
  end;

implementation

uses MainUnit;


constructor TUpThread.Create(CreateSuspended: Boolean; forcePng: Boolean);
begin
  inherited Create(CreateSuspended);
  FForcePNG := forcePng;
end;


procedure TUpThread.CallNewUpload;
begin
  MainForm.CloudTimer.Interval := 30000;
  if (FURL <> '#error') then MainForm.NewRecentItem(FURL);
end;


procedure TUpThread.Execute;
begin
  EmptyClipboard;
  FURL := GetImageURL(scrPiece, FForcePNG);
  Synchronize(CallNewUpload);

  if (FURL <> '#error') then begin
    SetClipboardText(FURL);
    MainForm.SuccessBalloon('Upload complete', FURL);
  end
  else MainForm.ErrorBalloon;

  scrThumb.FreeImage;
end;

end.
