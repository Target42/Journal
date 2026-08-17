object TitlesForm: TTitlesForm
  Left = 0
  Top = 0
  Caption = 'Titel'
  ClientHeight = 400
  ClientWidth = 480
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object lstTitles: TListBox
    Left = 16
    Top = 16
    Width = 448
    Height = 260
    ItemHeight = 15
    TabOrder = 0
  end
  object btnAdd: TButton
    Left = 16
    Top = 288
    Width = 110
    Height = 25
    Caption = 'Hinzuf'#252'gen'#8230
    TabOrder = 1
  end
  object btnReplace: TButton
    Left = 132
    Top = 288
    Width = 110
    Height = 25
    Caption = 'Ersetzen'#8230
    TabOrder = 2
  end
  object lblHint: TLabel
    Left = 16
    Top = 324
    Width = 448
    Height = 36
    AutoSize = False
    Caption = 
      'Titel entstehen automatisch beim Anlegen eines Arbeitspakets. '#220'b' +
      'er Hinzuf'#252'gen kannst du Titel ohne Paket erg'#228'nzen. Ersetzen benennt' +
      ' alle Arbeitspakete um; der bisherige Titel entf'#228'llt aus der Liste.'
    WordWrap = True
  end
  object btnClose: TButton
    Left = 389
    Top = 364
    Width = 75
    Height = 25
    Cancel = True
    Caption = 'Schlie'#223'en'
    Default = True
    TabOrder = 3
  end
end
