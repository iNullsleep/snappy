unit Prefs;

interface

uses Windows, Classes, Registry;

procedure LoadPrefs;
procedure SavePref(const OptionNumber: Byte);
procedure StartWithWindows(const Value: Boolean);
procedure RegisterShortCut(sc: TShortCut);

const
  pHotkey = 1;
  pSaveFolder = 2;

  kHotkey = 'Hotkey';
  kSaveFolder = 'SavingFolder';

  sKeyRun = 'Software\Microsoft\Windows\CurrentVersion\Run';
  sKeyPref = 'Software\snappy';

implementation

uses MainUnit;


procedure MyShortCutToKey(sc: TShortCut; var Shift: Word; var Key: Word);
begin
  Key := sc and not (scShift + scCtrl + scAlt);
  Shift := 0;

  if (sc and scShift <> 0) then Inc(Shift, MOD_SHIFT);
  if (sc and scCtrl <> 0) then Inc(Shift, MOD_CONTROL);
  if (sc and scAlt <> 0) then Inc(Shift, MOD_ALT);
end;


function MyKeyToShortCut(const Shift: Word; const Key: Word): TShortCut;
begin
  Result := 0;
  if (Hi(Key) <> 0) then Exit;
  Result := Key;

  if (MOD_SHIFT and Shift <> 0) then Inc(Result, scShift);
  if (MOD_CONTROL and Shift <> 0) then Inc(Result, scCtrl);
  if (MOD_ALT and Shift <> 0) then Inc(Result, scAlt);
end;


procedure RegisterShortCut(sc: TShortCut);
var
  wMod, wKey: Word;
begin
  MyShortCutToKey(sc, wMod, wKey);
  RegisterHotKey(MainForm.Handle, wUserAtom, wMod, wKey);
end;


procedure LoadPrefs;
var
  rPref: TRegistry;
  W: Longint;
begin
  rPref := TRegistry.Create;
  rPref.RootKey := HKEY_CURRENT_USER;

  rPref.OpenKey(sKeyRun, False);
  with MainForm do begin
    // Auto start
    bAutoStart := rPref.ValueExists('snappy');
    rPref.CloseKey;
    rPref.OpenKey(sKeyPref, True);

    // Hotkey
    if rPref.ValueExists(kHotkey) then begin
      bUserHotkey := True;
      W := rPref.ReadInteger(kHotkey);
      HotkeyInfo := MyKeyToShortCut(LOWORD(W), HIWORD(W));
    end
    else bUserHotkey := False;

    // Save folder
    if rPref.ValueExists(kSaveFolder) then
      SaveFolder := rPref.ReadString(kSaveFolder)
    else
      SaveFolder := PicturesFolder;
  end;

  rPref.Free;
end;


procedure SavePref(const OptionNumber: Byte);
var
  rPref: TRegistry;
  wMod, wKey: Word;
begin
  rPref := TRegistry.Create;
  rPref.RootKey := HKEY_CURRENT_USER;
  rPref.OpenKey(sKeyPref, True);

  with MainForm do case OptionNumber of
    pHotkey: begin
      if not bUserHotkey then rPref.DeleteValue(kHotkey)
      else begin
        MyShortCutToKey(HotkeyInfo, wMod, wKey);
        rPref.WriteInteger(kHotkey, MakeLong(wMod, wKey));
      end;
    end;

    pSaveFolder: rPref.WriteString(kSaveFolder, SaveFolder);
  end;

  rPref.Free;
end;


procedure StartWithWindows(const Value: Boolean);
var
  rPref: TRegistry;
begin
  rPref := TRegistry.Create;
  rPref.OpenKey(sKeyRun, False);
  if Value then rPref.WriteString('snappy', ParamStr(0))
  else rPref.DeleteValue('snappy');
  rPref.Free;
end;


end.