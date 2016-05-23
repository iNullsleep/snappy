object PrefsForm: TPrefsForm
  Left = 410
  Top = 246
  AlphaBlendValue = 220
  BorderStyle = bsNone
  Caption = 'Preferences'
  ClientHeight = 282
  ClientWidth = 405
  Color = clBlack
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWhite
  Font.Height = -11
  Font.Name = 'Segoe UI'
  Font.Style = []
  OldCreateOrder = False
  Position = poDefault
  OnCreate = FormCreate
  OnPaint = FormPaint
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object PrefLabel: TLabel
    Left = 16
    Top = 16
    Width = 81
    Height = 21
    Caption = 'Preferences'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWhite
    Font.Height = -16
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
    Transparent = True
  end
  object HotkeyPanel: TPanel
    Left = 40
    Top = 136
    Width = 145
    Height = 65
    BevelOuter = bvNone
    Color = clBlack
    TabOrder = 1
    object HotkeyLabel: TLabel
      Left = 0
      Top = 4
      Width = 94
      Height = 13
      Caption = 'Additional hotkey'
      Font.Charset = RUSSIAN_CHARSET
      Font.Color = 16752672
      Font.Height = -11
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
      Transparent = True
    end
    object HotKeyBox: THotKey
      Left = 8
      Top = 31
      Width = 129
      Height = 19
      HotKey = 0
      InvalidKeys = [hcNone, hcShift, hcShiftAlt]
      Modifiers = []
      TabOrder = 0
      TabStop = False
    end
  end
  object GeneralPanel: TPanel
    Left = 224
    Top = 64
    Width = 145
    Height = 137
    BevelOuter = bvNone
    Color = clBlack
    TabOrder = 2
    object FStart: TLabel
      Left = 26
      Top = 32
      Width = 102
      Height = 13
      Caption = 'Start with Windows'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWhite
      Font.Height = -11
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      Transparent = True
    end
    object GeneralLabel: TLabel
      Left = 0
      Top = 4
      Width = 40
      Height = 13
      Caption = 'General'
      Font.Charset = RUSSIAN_CHARSET
      Font.Color = 16752672
      Font.Height = -11
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
      Transparent = True
    end
    object FUninstall: TLabel
      Left = 26
      Top = 62
      Width = 46
      Height = 13
      Caption = 'Uninstall'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWhite
      Font.Height = -11
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
      Transparent = True
      OnClick = FUninstallClick
      OnMouseDown = FUninstallMouseDown
      OnMouseUp = FUninstallMouseUp
    end
    object FUninstallIcon: TImage
      Left = 9
      Top = 62
      Width = 12
      Height = 12
      AutoSize = True
      Picture.Data = {
        07544269746D6170E6010000424DE60100000000000036000000280000000C00
        00000C0000000100180000000000B0010000C40E0000C40E0000000000000000
        0000FF00FFFF00FFFF00FF686868686868686868686868686868686868FF00FF
        FF00FFFF00FFFF00FFFF00FF686868B9B9B9B9B9B9B9B9B9B9B9B9B9B9B9B9B9
        B9686868FF00FFFF00FFFF00FFFF00FF686868A7A7A7EBEBEBA7A7A7EBEBEBA7
        A7A7EBEBEB686868FF00FFFF00FFFF00FFFF00FF686868A7A7A7EBEBEBA7A7A7
        EBEBEBA7A7A7EBEBEB686868FF00FFFF00FFFF00FFFF00FF686868A7A7A7EBEB
        EBA7A7A7EBEBEBA7A7A7EBEBEB686868FF00FFFF00FFFF00FFFF00FF686868B9
        B9B9C6C6C6B9B9B9B9B9B9C6C6C6B9B9B9686868FF00FFFF00FFFF00FFFF00FF
        686868EBEBEBEBEBEBEBEBEBEBEBEBEBEBEBEBEBEB686868FF00FFFF00FFFF00
        FF686868686868686868686868686868686868686868686868686868686868FF
        00FFFF00FF686868C6C6C6C6C6C6C6C6C6C6C6C6C6C6C6C6C6C6C6C6C6B9B9B9
        686868FF00FFFF00FF6868686868686868686868686868686868686868686868
        68686868686868FF00FFFF00FFFF00FFFF00FFFF00FF686868FFFFFFFFFFFF68
        6868FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF686868686868
        686868686868FF00FFFF00FFFF00FFFF00FF}
      Transparent = True
      OnClick = FUninstallClick
      OnMouseDown = FUninstallMouseDown
      OnMouseUp = FUninstallMouseUp
    end
    object FStartCheck: TCheckBox
      Left = 8
      Top = 30
      Width = 121
      Height = 17
      TabStop = False
      Checked = True
      State = cbChecked
      TabOrder = 0
    end
  end
  object OKBtn: TPanel
    Left = 220
    Top = 232
    Width = 68
    Height = 25
    Caption = 'OK'
    Color = clBlack
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWhite
    Font.Height = -11
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
    TabOrder = 3
    OnClick = OKBtnClick
    OnMouseDown = CustomPanelMouseDown
    OnMouseUp = CustomPanelMouseUp
  end
  object CancelBtn: TPanel
    Left = 304
    Top = 232
    Width = 68
    Height = 25
    Caption = 'Cancel'
    Color = clBlack
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWhite
    Font.Height = -11
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
    TabOrder = 4
    OnClick = CancelBtnClick
    OnMouseDown = CustomPanelMouseDown
    OnMouseUp = CustomPanelMouseUp
  end
  object ActionPanel: TPanel
    Left = 40
    Top = 64
    Width = 145
    Height = 67
    BevelOuter = bvNone
    Color = clBlack
    TabOrder = 0
    object ActionLabel: TLabel
      Left = 0
      Top = 4
      Width = 58
      Height = 13
      Caption = 'Save folder'
      Font.Charset = RUSSIAN_CHARSET
      Font.Color = 16752672
      Font.Height = -11
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
      Transparent = True
    end
    object FSaveFolder: TEdit
      Left = 8
      Top = 32
      Width = 129
      Height = 21
      Hint = 'Click to browse for a folder'
      Color = clWhite
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clBlack
      Font.Height = -11
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      ParentShowHint = False
      ReadOnly = True
      ShowHint = True
      TabOrder = 0
      OnClick = FSaveFolderClick
    end
  end
  object WipingTimer: TTimer
    Enabled = False
    Interval = 15
    OnTimer = WipingTimerTimer
    Left = 160
    Top = 16
  end
end
