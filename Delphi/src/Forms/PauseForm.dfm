object PauseForm: TPauseForm
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Pause'
  ClientHeight = 180
  ClientWidth = 460
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  OnCreate = FormCreate
  TextHeight = 15
  object lblVon: TLabel
    Left = 16
    Top = 24
    Width = 24
    Height = 15
    Caption = 'Von:'
  end
  object lblBis: TLabel
    Left = 176
    Top = 24
    Width = 21
    Height = 15
    Caption = 'Bis:'
  end
  object lblDuration: TLabel
    Left = 320
    Top = 24
    Width = 120
    Height = 15
    Caption = 'Dauer:'
  end
  object lblHint: TLabel
    Left = 16
    Top = 64
    Width = 428
    Height = 48
    AutoSize = False
    Caption = 
      'Die Pause wird als L'#252'cke zwischen Arbeitspaketen gespeichert. Ab' +
      ' 15 Minuten z'#228'hlt sie f'#252'r ArbZG und ersetzt den automatischen Ab' +
      'zug.'
    WordWrap = True
  end
  object dtpStart: TDateTimePicker
    Left = 48
    Top = 20
    Width = 90
    Height = 23
    Kind = dtkTime
    Format = 'HH:mm'
    TabOrder = 0
  end
  object dtpEnd: TDateTimePicker
    Left = 208
    Top = 20
    Width = 90
    Height = 23
    Kind = dtkTime
    Format = 'HH:mm'
    TabOrder = 1
  end
  object btnDelete: TButton
    Left = 16
    Top = 136
    Width = 110
    Height = 25
    Caption = 'Pause l'#246'schen'
    TabOrder = 2
  end
  object btnOk: TButton
    Left = 268
    Top = 136
    Width = 90
    Height = 25
    Caption = #220'bernehmen'
    Default = True
    TabOrder = 3
  end
  object btnCancel: TButton
    Left = 364
    Top = 136
    Width = 80
    Height = 25
    Cancel = True
    Caption = 'Abbrechen'
    TabOrder = 4
  end
end
