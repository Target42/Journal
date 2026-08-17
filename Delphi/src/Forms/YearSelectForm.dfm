object YearSelectForm: TYearSelectForm
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Jahr w'#228'hlen'
  ClientHeight = 160
  ClientWidth = 420
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  OnCreate = FormCreate
  TextHeight = 15
  object lblJahr: TLabel
    Left = 16
    Top = 20
    Width = 28
    Height = 15
    Caption = 'Jahr:'
  end
  object lblHint: TLabel
    Left = 16
    Top = 56
    Width = 388
    Height = 48
    AutoSize = False
    Caption = 
      'W'#228'hle das Jahr, f'#252'r das Feiertage bzw. Ferien geladen werden sol' +
      'len. Damit kannst du z. B. schon im Vorjahr den Kalender f'#252'r die' +
      ' Urlaubsplanung holen.'
    WordWrap = True
  end
  object nbYear: TNumberBox
    Left = 64
    Top = 16
    Width = 120
    Height = 23
    Alignment = taRightJustify
    MinValue = 1970.000000000000000000
    MaxValue = 2100.000000000000000000
    Mode = nbmInteger
    TabOrder = 0
    Value = 2026.000000000000000000
  end
  object btnDownload: TButton
    Left = 216
    Top = 120
    Width = 110
    Height = 25
    Caption = 'Herunterladen'
    Default = True
    TabOrder = 1
  end
  object btnCancel: TButton
    Left = 332
    Top = 120
    Width = 75
    Height = 25
    Cancel = True
    Caption = 'Abbrechen'
    TabOrder = 2
  end
end
