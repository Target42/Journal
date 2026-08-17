object DayBoundsForm: TDayBoundsForm
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Tagesgrenzen'
  ClientHeight = 220
  ClientWidth = 440
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  OnCreate = FormCreate
  TextHeight = 15
  object rbGlobal: TRadioButton
    Left = 16
    Top = 16
    Width = 400
    Height = 17
    Caption = 'Globale Grenzen verwenden'
    TabOrder = 0
  end
  object lblGlobal: TLabel
    Left = 40
    Top = 40
    Width = 50
    Height = 15
    Caption = 'Aktuell'
  end
  object rbCustom: TRadioButton
    Left = 16
    Top = 68
    Width = 400
    Height = 17
    Caption = 'Abweichend f'#252'r diesen Tag'
    TabOrder = 1
  end
  object lblVon: TLabel
    Left = 40
    Top = 100
    Width = 24
    Height = 15
    Caption = 'Von:'
  end
  object dtpStart: TDateTimePicker
    Left = 80
    Top = 96
    Width = 90
    Height = 23
    Kind = dtkTime
    Format = 'HH:mm'
    TabOrder = 2
  end
  object lblBis: TLabel
    Left = 188
    Top = 100
    Width = 21
    Height = 15
    Caption = 'Bis:'
  end
  object dtpEnd: TDateTimePicker
    Left = 224
    Top = 96
    Width = 90
    Height = 23
    Kind = dtkTime
    Format = 'HH:mm'
    TabOrder = 3
  end
  object lblHint: TLabel
    Left = 16
    Top = 132
    Width = 408
    Height = 36
    AutoSize = False
    Caption = 
      'Nur Zeiten innerhalb der Grenzen z'#228'hlen f'#252'r Ist und Saldo. Erfas' +
      'ste Arbeitspakete au'#223'erhalb bleiben erhalten.'
    WordWrap = True
  end
  object btnOk: TButton
    Left = 248
    Top = 180
    Width = 90
    Height = 25
    Caption = #220'bernehmen'
    Default = True
    TabOrder = 4
  end
  object btnCancel: TButton
    Left = 348
    Top = 180
    Width = 75
    Height = 25
    Cancel = True
    Caption = 'Abbrechen'
    TabOrder = 5
  end
end
