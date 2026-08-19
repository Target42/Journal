object TermineForm: TTermineForm
  Left = 0
  Top = 0
  Caption = 'Termine'
  ClientHeight = 400
  ClientWidth = 560
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
  object lstTermine: TListBox
    Left = 16
    Top = 16
    Width = 528
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
  object btnEdit: TButton
    Left = 132
    Top = 288
    Width = 110
    Height = 25
    Caption = 'Bearbeiten'#8230
    TabOrder = 2
  end
  object btnDelete: TButton
    Left = 248
    Top = 288
    Width = 90
    Height = 25
    Caption = 'L'#246'schen'
    TabOrder = 3
  end
  object lblHint: TLabel
    Left = 16
    Top = 324
    Width = 528
    Height = 32
    AutoSize = False
    Caption = 
      'Termine erscheinen in der Tages- und Monats'#252'bersicht. Sie z'#228'hlen' +
      ' nicht zur Arbeitszeit.'
    WordWrap = True
  end
  object btnClose: TButton
    Left = 469
    Top = 364
    Width = 75
    Height = 25
    Cancel = True
    Caption = 'Schlie'#223'en'
    Default = True
    TabOrder = 4
  end
end
