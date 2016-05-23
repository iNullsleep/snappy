{
  Made because of boredom.
  02/08/2012 - 11/08/2012
  04/09/2012 - 17/09/2012
  10/10/2012 - 17/10/2012
  11/11/2012 - 20/11/2012
}

unit SnappyCore;

interface

uses
  Windows, Classes, SysUtils, Graphics, ShlObj, ShellAPI, WinSock2, WinInet, Clipbrd, jpeg,
  pngimage, Prefs;

function Min(const a, b: Integer): Integer;
function Max(const a, b: Integer): Integer;
procedure LoadPngRes(png: TPNGObject; const resName: string);
procedure LoadJpgRes(jpg: TJPEGImage; const resName: string);
function TempDir: string;
function GetFolder(const nFolder: Integer): string;
function RunningWinXP: Boolean;

function OpenConnection(var sock: TSocket): Boolean;
procedure CloseConnection(var sock: TSocket);
function UploadStream(stream: TStream): string;
function GetImageURL(bitmap: TBitmap; forcePNG: Boolean): string;
procedure SaveImage(bitmap: TBitmap; const Folder: string);
procedure SetClipboardText(const str: string);
procedure EmptyClipboard;

procedure DrawLine(bitmap: TBitmap; g: TGraphic; x, y, x2, y2: Integer);

procedure SelfInstall;
procedure Uninstall;
function IsUpdateAvailable: Boolean;
procedure AutoUpdate;
procedure GlassWindow(Handle: HWND);

const 
  clBlur = clFuchsia - 7;
  speed = 40000; // bytes per second
type
  THosting = record
    HostName, UploadURL: string;
    Content, Token: string;
  end;

var
  hID: Byte = 1;
  hostings: array[1..2] of THosting = (

    (
      HostName: 'www.imgland.net';
      UploadURL: '/process.php?subAPI=imgsnapper&private=true';
      Content: 'imagefile[]';
      Token: 'http://';
    ),
    (
      HostName: 'cubeupload.com';
      UploadURL: '/upload_json.php';
      Content: 'fileinput[0]';
      Token: '"file_name":"';
    )

  );

implementation

uses MainUnit;


function BackslashFilter(const s: string): string;
var
  i: Integer;
begin
  Result := '';
  for i := 1 to Length(s) do
    if (s[i] <> '\') then Result := Result + s[i];
end;


function Min(const a, b: Integer): Integer;
begin
  if (a < b) then Result := a
  else Result := b;
end;


function Max(const a, b: Integer): Integer;
begin
  if (a > b) then Result := a
  else Result := b;
end;


procedure LoadPngRes(png: TPNGObject; const resName: string);
var
  res: TResourceStream;
begin
  res := TResourceStream.Create(HInstance, resName, 'PNG');
  png.LoadFromStream(res);
  res.Free;
end;


procedure LoadJpgRes(jpg: TJPEGImage; const resName: string);
var
  res: TResourceStream;
begin
  res := TResourceStream.Create(HInstance, resName, 'JPG');
  jpg.LoadFromStream(res);
  res.Free;
end;


function TempDir: string;
var
  tempPath: array [0..MAX_PATH - 1] of Char;
begin
  GetTempPath(MAX_PATH, tempPath);
  Result := tempPath;
end;


function RunningWinXP: Boolean;
var
  osInfo: TOSVERSIONINFO;
begin
  ZeroMemory(@osInfo, SizeOf(osInfo));
  osInfo.dwOSVersionInfoSize := SizeOf(TOSVERSIONINFO);
  GetVersionEx(osInfo);

  Result := (osInfo.dwMajorVersion < 6);
end;


function try_connect(const sock: TSocket; const sock_addr: TSockAddrIn): Boolean;
const
  connectTimeOut = 1;
var
  wset: TFDSet;
  tv: TTimeVal;
  block: Cardinal;
begin
  Result := False;

  block := 1;
  ioctlsocket(sock, FIONBIO, block);

  if (connect(sock, @sock_addr, SizeOf(sock_addr)) = SOCKET_ERROR) then
    if (WSAGetLastError = WSAEWOULDBLOCK) then begin
      FD_ZERO(wset);
      FD_SET(sock, wset);
      tv.tv_sec := connectTimeOut;
      tv.tv_usec := 300000;
      Result := (select(0, nil, @wset, nil, @tv) > 0);
    end;

  block := 0;
  ioctlsocket(sock, FIONBIO, block);
end;


function try_recv(sock: TSocket; const bSize: Integer): Boolean;
var
  rset: TFDSet;
  tv: TTimeVal;
  timeOut: Double;
begin
  FD_ZERO(rset);
  FD_SET(sock, rset);

  timeOut := bSize / (speed * 0.67);    ////////// ??? coefficient
  tv.tv_sec := 3 + Trunc(timeOut);
  tv.tv_usec := Round(Frac(timeOut) * 1000000);

  Result := (select(0, @rset, nil, nil, @tv) > 0);
end;


function OpenConnection(var sock: TSocket): Boolean;
var
  wsa: TWSAData;
  sockAddress: TSockAddrIn;
  hostAddress: PHostEnt;
begin
  Result := False;

  WSAStartup(WINSOCK_VERSION, wsa);
  sock := WSASocket(AF_INET, SOCK_STREAM, IPPROTO_IP, nil, 0, 0);
  if (sock = INVALID_SOCKET) then Exit;

  hostAddress := gethostbyname(PChar(Hostings[hID].HostName));
  if (hostAddress = nil) then Exit;

  sockAddress.sin_family := AF_INET;
  sockAddress.sin_addr.S_addr := PInAddr(hostAddress.h_addr_list^)^.S_addr;
  sockAddress.sin_port := htons(80);

  Result := try_connect(sock, sockAddress);
  if not Result then CloseConnection(sock);
end;


procedure CloseConnection(var sock: TSocket);
begin
  if (sock <> 0) then begin
    closesocket(sock);
    WSACleanup;
    sock := 0;
  end;
end;


function UploadTo(dataBuffer: PChar; bufferSize: Integer): string;
const
  sz = 2048;
  stopSign = '"';
var
  sock: TSocket;
  imgType: string;
  header, payload: string;
  boundary, content: string;
  contentLength: Integer;

  buf: array[1..sz] of Char;
  len: Integer;
  pFrom, pTo: Integer;
  token, response: string;
begin
  Randomize;
  Result := '#error';
 
  if (Ord(dataBuffer[0]) = $ff) then imgType := 'jpeg'
  else imgType := 'png';

  boundary := '----WhateverMan' + IntToHex(Random($ffffffff), 8);
  content := 'Content-Disposition: form-data; name="%s"; filename="%s"'#13#10 +
             'Content-Type: image/%s'#13#10;

  header := '--' + boundary + #13#10 +
    Format(content, [Hostings[hID].Content, 'snappy.' + imgType, imgType]) + #13#10;

  // here goes binary data...

  payload := #13#10'--' + boundary;

  if (hID = 2) then payload := payload + #13#10 +
    'Content-Disposition: form-data; name="name"' + #13#10 +
    'snappy.' + imgType + #13#10#13#10'--' + boundary;

  payload := payload + '--'#13#10;

  contentLength := Length(header) + bufferSize  + Length(payload);
  header := 'POST ' + Hostings[hID].UploadURL + ' HTTP/1.1' + #10 +
    'Host: ' + Hostings[hID].HostName + #10 +
    'Connection: Keep-Alive' + #10 +
    'Content-Length: ' + IntToStr(contentLength) + #10 +
    'Content-Type: multipart/form-data; boundary=' + boundary + #10#10 +
    header;

  if not OpenConnection(sock) and not OpenConnection(sock) then begin
    // TODO: something with changin the priority
    CloseConnection(sock);
    Exit;
  end;
  
  send(sock, PChar(header)^, Length(header), 0);
  send(sock, dataBuffer^, bufferSize, 0);
  send(sock, PChar(payload)^, Length(payload), 0);

  if try_recv(sock, bufferSize) then begin
    FillChar(buf, sz, #0);
    recv(sock, buf, sz, 0);
    pFrom := Pos(#13#10#13#10, buf) + 4;
    pTo := pFrom + 1;
    while (buf[pTo] <> #0) and (pTo <= sz)  do Inc(pTo);
    response := Copy(buf, pFrom, pTo-pFrom);
  end
  else begin
    CloseConnection(sock);
    Exit;
  end;

  token := Hostings[hID].Token;
  pFrom := Pos(token, response);
  if (pFrom > 0) then begin
    if (hID = 2) then Inc(pFrom, Length(token));
    pTo := pFrom + 1;
    len := Length(response);
    while (pTo <= len) and (response[pTo] > stopSign) do Inc(pTo);
    Result := Copy(response, pFrom, pTo - pFrom);
    if (hID = 2) then Result := 'http://i.cubeupload.com/' + Result;
  end;

  CloseConnection(sock);
end;


function UploadStream(stream: TStream): string;
var
  dataBuffer: array of Char;
  bufferSize: Integer;
begin
  bufferSize := stream.Size;
  SetLength(dataBuffer, bufferSize);
  stream.Seek(soFromBeginning, 0);
  stream.ReadBuffer(PChar(dataBuffer)^, bufferSize);
  stream.Free;

  hID := 1;
  Result := UploadTo(PChar(dataBuffer), bufferSize);
  if (Result = '#error') then begin
    hID := 3 - hID;
    Result := UploadTo(PChar(dataBuffer), bufferSize);
  end;

  dataBuffer := nil;
end;


function GetImageURL(bitmap: TBitmap; forcePNG: Boolean): string;
const
  limitSize = 50000;
var
  pixelsCount: Cardinal;
  usingJPEG: Boolean;

  pngStream, jpgStream: TMemoryStream;
  pngSize, jpgSize: Int64;
begin
  exit;
  pngStream := TMemoryStream.Create;
  with TPNGObject.Create do begin
    CompressionLevel := 1;
    Assign(bitmap);
    SaveToStream(pngStream);
    Free;
  end;
  pngSize := pngStream.Size;

  if (pngSize < limitSize) or forcePNG then Result := UploadStream(pngStream)
  else begin
    jpgStream := TMemoryStream.Create;
    with TJPEGImage.Create do begin
      CompressionQuality := 93;
      Assign(bitmap);
      SaveToStream(jpgStream);
      Free;
    end;
    jpgSize := jpgStream.Size;

    {
      use Jay Peg in cases:
      1) if jpgSize is more than 4.5 times smaller than pngSize
      2) if jpgSize is 3..4.5 times smaller than pngSize
        and (pixelsCount / pngSize) less than 1.25 (compression efficiency)
    }
    pixelsCount := bitmap.Width * bitmap.Height;
    usingJPEG := (jpgSize * 9 div 2 < pngSize)
      or ((jpgSize * 3 < pngSize) and (pixelsCount * 4 div 5 < pngSize));

    if usingJPEG then begin
      pngStream.Free;
      Result := UploadStream(jpgStream);
    end
    else begin
      jpgStream.Free;
      Result := UploadStream(pngStream);
    end;
  end;
end;


procedure SaveImage(bitmap: TBitmap; const Folder: string);
var
  png: TPNGObject;
begin
  ForceDirectories(Folder);
  with png do begin
    png := TPNGObject.Create;
    CompressionLevel := 7;
    Assign(bitmap);
    SaveToFile(Folder + '\' + FormatDateTime('dd.mm.yy @ hh-nn-ss', Now) + '.png');
    Free;
  end;
end;


procedure DrawLine(bitmap: TBitmap; g: TGraphic; x, y, x2, y2: Integer);

  function Sign(const value: Integer): Integer;
  begin
    Result := 0;
    if value < 0 then Result := -1
    else if value > 0 then Result := 1;
  end;

var
  dx, dy, sx, sy: Integer;
  check: Boolean;
  i, e: Integer;
begin
  dx := Abs(x - x2);
  dy := Abs(y - y2);
  sx := Sign(x2 - x);
  sy := Sign(y2 - y);

  check := False;
  if dy > dx then begin
    i := dx;
    dx := dy;
    dy := i;
    check := True;
  end;

  e := dy shl 1 - dx;

  for i := 0 to dx do begin
    bitmap.Canvas.Draw(x - 1, y - 1, g);

    if e >= 0 then begin
      if check then Inc(x, sx)
      else Inc(y, sy);
      Dec(e, dx shl 1);
    end;

    if check then Inc(y, sy)
    else Inc(x, sx);
    Inc(e, dy shl 1);
  end;
end;


procedure SetClipboardText(const str: string);
begin
  Clipboard.SetTextBuf(PChar(str));
end;


procedure EmptyClipboard;
begin
  Clipboard.Clear;
end;


function GetFolder(const nFolder: Integer): string;
var
  buf: array [0..MAX_PATH-1] of Char;
begin
  SHGetSpecialFolderPath(0, @buf, nFolder, False);
  Result := buf;
end;


procedure WaitForExec(const fName: string);
var
  si: TStartupInfo;
  pi: TProcessInformation;
begin
  FillChar(si, SizeOf(si), 0);
  si.cb := SizeOf(si);
  si.dwFlags := STARTF_USESHOWWINDOW;
  si.wShowWindow := SW_HIDE;
  if CreateProcess(nil, PChar(fName), nil, nil, False, 0, nil, nil, si, pi) then begin
    WaitForSingleObject(pi.hProcess, INFINITE);
    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);
  end;
end;


procedure CreateShortcuts;
const
  vbs = 'sTargetPath = "%s"'#13 +
        'Set oWS = CreateObject("WScript.Shell")'#13 +

        'Set oDesktop = oWS.CreateShortcut("%s\snappy.lnk")'#13 +
        'Set oStartMenu = oWS.CreateShortcut("%s\snappy.lnk")'#13 +
        'Set oSendTo = oWS.CreateShortcut("%s\snappy.lnk")'#13 +

        'oDesktop.TargetPath = sTargetPath'#13 +
        'oStartMenu.TargetPath = sTargetPath'#13 +
        'oSendTo.TargetPath = sTargetPath'#13 +

        'oDesktop.Save'#13 +
        'oStartMenu.Save'#13 +
        'oSendTo.Save';
var
  f: TextFile;
  scriptName, scriptBody: string;
begin
  scriptName := TempDir + 'links.vbs';
  scriptBody := Format(vbs, [ParamStr(0),
    GetFolder(CSIDL_DESKTOP),
    GetFolder(CSIDL_STARTMENU) + '\Programs',
    GetFolder(CSIDL_SENDTO)]);

  Assign(f, scriptName);
  Rewrite(f);
  Writeln(f, scriptBody);
  CloseFile(f);

  WaitForExec('wscript.exe "' + scriptName + '"');
  DeleteFile(scriptName);
end;


function DownloadFile(const URL, fileName: string): Boolean;
const
  sz = 10240;
var
  hSession, hURL: HINTERNET;
  dataBuffer: array[0..sz - 1] of Char;
  readBytes: Cardinal;
  f: file;
begin
  Result := False;
  hSession := InternetOpen('snappy', INTERNET_OPEN_TYPE_PRECONFIG, nil, nil, 0);
  hURL := InternetOpenURL(hSession, PChar(URL), nil, 0, 0, 0);
  if (hURL = nil) then begin
    InternetCloseHandle(hSession);
    Exit;
  end;

  Result := True;
  try
    AssignFile(f, fileName);
    Rewrite(f, 1);
    repeat
      FillChar(dataBuffer, sz, #0);
      if InternetReadFile(hURL, @dataBuffer, sz, readBytes) then
        BlockWrite(f, dataBuffer, readBytes)
      else begin
        Result := False;
        Break;
      end;
    until (readBytes = 0);

    CloseFile(f);
  except
    Result := False;
  end;

  InternetCloseHandle(hURL);
  InternetCloseHandle(hSession);
end;


function IsOnline: Boolean;
var
  wsa: TWSAData;
  sock: TSocket;
  sock_addr: TSockAddrIn;
  google: PHostEnt;
begin
  Result := False;

  WSAStartup(WINSOCK_VERSION, wsa);
  sock := WSASocket(AF_INET, SOCK_STREAM, IPPROTO_IP, nil, 0, 0);
  if (sock = INVALID_SOCKET) then begin
    WSACleanUp;
    Exit;
  end;

  google := gethostbyname(PChar('google.com'));
  if (google <> nil) then begin
    sock_addr.sin_family := AF_INET;
    sock_addr.sin_addr.S_addr := PInAddr(google.h_addr_list^)^.S_addr;
    sock_addr.sin_port := htons(80);
    if try_connect(sock, sock_addr) then Result := True;
  end;

  closesocket(sock);
  WSACleanUp;
end;


function IsUpdateAvailable: Boolean;
const
  sz = 16;
  currentVerURL = 'https://sites.google.com/site/inullsleep/home/snappy_ver?attredirects=0&d=1';
var
  hSession, hURL: HINTERNET;
  latestVersion: array[0..sz - 1] of Char;
  readBytes: Cardinal;
begin
  Result := False;
  if not IsOnline then Exit;

  hSession := InternetOpen('snappy_update', INTERNET_OPEN_TYPE_PRECONFIG, nil, nil, 0);
  hURL := InternetOpenURL(hSession, currentVerURL, nil, 0, 0, 0);
  if (hURL = nil) then begin
    InternetCloseHandle(hSession);
    Exit;
  end;

  repeat
    FillChar(latestVersion, sz, #0);
    if InternetReadFile(hURL, @latestVersion, sz, readBytes) then begin
      Result := (Trim(latestVersion) <> ver);
      Break;
    end;
  until (readBytes = 0);

  InternetCloseHandle(hURL);
  InternetCloseHandle(hSession);
end;


procedure AutoUpdate;
const
  buildURL = 'https://sites.google.com/site/inullsleep/home/snappy_build?attredirects=0&d=1';
  instFileName = 'snappy_install.exe';
var
  fName: string;
begin
  fName := TempDir + instFileName;
  SetFileAttributes(PChar(fName), FILE_ATTRIBUTE_NORMAL);
  if FileExists(fName) then
    if not DeleteFile(fName) then Exit;
  DownloadFile(buildURL, fName);
  WinExec(PChar(fName), SW_NORMAL);
  Halt;
end;


// meditate here
procedure SelfInstall;
const
  fName = 'snappy.exe';
  oldName = 'old_snappy';
  agreeMsg = 'Would you like to install snappy ' + ver + '?';
  installMsg = 'snappy ' + ver + ' has been successfully installed to:'#13#13;
  updateMsg = 'snappy has been updated to version ' + ver;
var
  sAppData: string;
  sysTime: TSystemTime;
begin
  sAppData := GetFolder(CSIDL_APPDATA) + '\snappy\';

  if (ExtractFilePath(ParamStr(0)) <> sAppData) then begin
    if (MessageBox(0, agreeMsg, 'snappy', MB_ICONQUESTION or MB_YESNO) = IDYES) then begin
      //if IsUpdateAvailable then AutoUpdate;
      if FileExists(sAppData + fName) then begin
        SendMessage(FindWindow('TMainForm', 'snappy'), WM_SUICIDE, 0, 0);
        DeleteFile(sAppData + oldName); // just in case
        RenameFile(sAppData + fName, sAppData + oldName);
        CopyFile(PChar(ParamStr(0)), PChar(sAppData + fName), False);
        Sleep(50);
        WinExec(PChar(sAppData + fName + ' --updated'), SW_NORMAL);
      end
      else begin
        CreateDirectory(PChar(sAppData), nil);
        CopyFile(PChar(ParamStr(0)), PChar(sAppData + fName), False);
        Sleep(50);
        WinExec(PChar(sAppData + fName + ' --installed'), SW_NORMAL);
      end;
    end;
    Halt;
  end
  else begin
    if (ParamStr(1) = '--updated') then begin
      DeleteFile(sAppData + oldName);
      MessageBox(0, PChar(updateMsg), 'snappy', MB_ICONASTERISK or MB_OK);
    end
    else if (ParamStr(1) = '--installed') then begin
      StartWithWindows(True);
      CreateShortcuts;
      MessageBox(0, PChar(installMsg + sAppData), 'snappy', MB_ICONASTERISK or MB_OK);
    end
    else begin
      GetLocalTime(sysTime);     
      if (sysTime.wDayOfWeek > 5) and IsUpdateAvailable then AutoUpdate;
    end;
  end;
end;


procedure Uninstall;
var
  cmdLine: string;
begin
  StartWithWindows(False);
  DeleteFile(GetFolder(CSIDL_DESKTOP) + '\snappy.lnk');
  DeleteFile(GetFolder(CSIDL_STARTMENU) + '\Programs\snappy.lnk');
  DeleteFile(GetFolder(CSIDL_SENDTO) + '\snappy.lnk');

  // quirky way to sleep for 2 seconds
  cmdLine := 'cmd.exe /c ping 127.0.0.1 -n 2 && del "' + ParamStr(0) + '"';
  WinExec(PChar(cmdLine), SW_HIDE);
  MainForm.Close;
end;

  
procedure GlassWindow(Handle: HWND);
type
  _MARGINS = packed record
    cxLeftWidth: Integer;
    cxRightWidth: Integer;
    cyTopHeight: Integer;
    cyBottomHeight: Integer;
  end;

  PMargins = ^_MARGINS;
  TMargins = _MARGINS;
var
  DwmIsCompositionEnabled:
    function(pfEnabled: PBoolean): HRESULT; stdcall;
  DwmExtendFrameIntoClientArea:
    function(destWnd: HWND; const pMarInset: PMargins): HRESULT; stdcall;

  dwmapi: THandle;
  pfEnabled: Boolean;
  margins: TMargins;
begin
  dwmapi := LoadLibrary('dwmapi.dll');

  if (dwmapi <> 0) then
  begin
    @DwmIsCompositionEnabled := GetProcAddress(dwmapi, 'DwmIsCompositionEnabled');
    @DwmExtendFrameIntoClientArea := GetProcAddress(dwmapi, 'DwmExtendFrameIntoClientArea');

    if (@DwmIsCompositionEnabled <> nil)
    and (@DwmExtendFrameIntoClientArea <> nil) then begin
      DwmIsCompositionEnabled(@pfEnabled);

      if pfEnabled then begin
        SetWindowLong(Handle, GWL_EXSTYLE, GetWindowLong(Handle, GWL_EXSTYLE) or WS_EX_LAYERED);
        SetLayeredWindowAttributes(Handle, clBlur, 0, LWA_COLORKEY);

        ZeroMemory(@margins, SizeOf(margins));
        with margins do begin
          cxLeftWidth := -1;
          cxRightWidth := -1;
          cyTopHeight := -1;
          cyBottomHeight := -1;
        end;
        DwmExtendFrameIntoClientArea(Handle, @margins);
      end;
    end;

    FreeLibrary(dwmapi);
  end;
end;


end.
