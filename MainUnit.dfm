object MainForm: TMainForm
  Left = 245
  Top = 148
  Cursor = crCross
  BorderStyle = bsNone
  Caption = 'snappy'
  ClientHeight = 100
  ClientWidth = 195
  Color = clBlack
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  OnCloseQuery = FormCloseQuery
  OnCreate = FormCreate
  OnKeyDown = FormKeyDown
  OnKeyUp = FormKeyUp
  OnMouseDown = FormMouseDown
  OnMouseMove = FormMouseMove
  OnMouseUp = FormMouseUp
  PixelsPerInch = 96
  TextHeight = 13
  object DimmingTimer: TTimer
    Enabled = False
    Interval = 20
    OnTimer = DimmingTimerTimer
    Left = 56
    Top = 16
  end
  object CloudTimer: TTimer
    Interval = 30000
    OnTimer = CloudTimerTimer
    Left = 96
    Top = 16
  end
  object URLMenu: TPopupMenu
    AutoHotkeys = maManual
    AutoLineReduction = maManual
    AutoPopup = False
    Left = 16
    Top = 56
  end
  object PopupMenu: TPopupMenu
    AutoHotkeys = maManual
    Left = 16
    Top = 16
    object TakeSnapMenu: TMenuItem
      Caption = 'Take snapshot'
      OnClick = TakeSnapMenuClick
    end
    object PrefMenu: TMenuItem
      Caption = 'Preferences'
      OnClick = PrefMenuClick
    end
    object N5: TMenuItem
      Caption = '-'
    end
    object HelpMenu: TMenuItem
      Caption = 'Help'
      OnClick = HelpMenuClick
    end
    object AboutMenu: TMenuItem
      Caption = 'About'
      OnClick = AboutMenuClick
    end
    object N2: TMenuItem
      Caption = '-'
    end
    object ExitMenu: TMenuItem
      Caption = 'Exit'
      OnClick = ExitMenuClick
    end
  end
end
