program snappy;

uses
  Forms, Windows, Classes, SysUtils, SnappyCore,
  MainUnit in 'MainUnit.pas' {MainForm},
  PrefsUnit in 'PrefsUnit.pas' {PrefsForm},
  SplashUnit in 'SplashUnit.pas' {TSplashForm},
  PreviewUnit in 'PreviewUnit.pas' {PreviewForm};

{$R *.res}
{$R ver.res}
{$R res\icons.res}

procedure TopMostForm(h: THandle);
begin
  SetWindowLong(h, GWL_HWNDPARENT, GetDesktopWindow);
  SetWindowPos(h, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOSIZE or SWP_NOMOVE);
end;

var
  hMap: HWND;

  fStream: TFileStream;
  URL: string;
begin
  SetFileAttributes(PChar(ParamStr(0)), FILE_ATTRIBUTE_NORMAL);
  DeleteFile(ParamStr(0) + ':Zone.Identifier');

  if FileExists(ParamStr(1)) then
  begin
    fStream := TFileStream.Create(ParamStr(1), fmOpenRead);
    URL := UploadStream(fStream);

    if (URL <> '#error') then
    begin
      SetClipboardText(URL);
      MessageBox(0, PChar(URL), 'Upload Complete!', MB_ICONINFORMATION);
    end;
    Halt;
  end;
  
  if (ParamStr(1) <> '--portable') then SelfInstall;

  hMap := CreateFileMapping(INVALID_HANDLE_VALUE, nil, PAGE_READWRITE, 0, 1024, 'snappy');
  if (GetLastError <> ERROR_ALREADY_EXISTS) then
  begin
    Application.Initialize;
    Application.ShowMainForm := False;
    SetWindowLong(Application.Handle, GWL_EXSTYLE, not WS_EX_APPWINDOW or WS_EX_TOOLWINDOW);

    Application.CreateForm(TMainForm, MainForm);
    TopMostForm(MainForm.Handle);

    Application.CreateForm(TSplashForm, SplashForm);
    TopMostForm(SplashForm.Handle);

    Application.CreateForm(TPrefsForm, PrefsForm);
    TopMostForm(PrefsForm.Handle);

    Application.CreateForm(TPreviewForm, PreviewForm);
    if not compatibilityMode then begin
      PreviewForm.Color := clBlur;
      GlassWindow(PreviewForm.Handle);
    end;
    TopMostForm(PreviewForm.Handle);

    // show guidelines if it's the first start
    bGuideMode := (ParamStr(1) = '--installed');// or (ParamStr(1) = '--updated');
    if bGuideMode then MainForm.LoadGuideMode;

    Application.Run;
  end;
  CloseHandle(hMap);

end.
