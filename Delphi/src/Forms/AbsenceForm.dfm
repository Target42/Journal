object AbsenceForm: TAbsenceForm
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Urlaub / Krankheit'
  ClientHeight = 280
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
  object lblVon: TLabel
    Left = 16
    Top = 20
    Width = 24
    Height = 15
    Caption = 'Von:'
  end
  object lblBis: TLabel
    Left = 16
    Top = 52
    Width = 21
    Height = 15
    Caption = 'Bis:'
  end
  object lblHint: TLabel
    Left = 16
    Top = 188
    Width = 408
    Height = 40
    AutoSize = False
    Caption = 
      'Beim Setzen werden nur Arbeitstage ohne Feiertag ber'#252'cksichtigt.' +
      ' An diesen Tagen gilt die Soll-Arbeitszeit (keine Mehr- oder Min' +
      'derzeit).'
    WordWrap = True
  end
  object dtpFrom: TDateTimePicker
    Left = 64
    Top = 16
    Width = 160
    Height = 23
    Date = 45658.000000000000000000
    Format = 'dd.MM.yyyy'
    TabOrder = 0
  end
  object dtpTo: TDateTimePicker
    Left = 64
    Top = 48
    Width = 160
    Height = 23
    Date = 45658.000000000000000000
    Format = 'dd.MM.yyyy'
    TabOrder = 1
  end
  object grpArt: TGroupBox
    Left = 16
    Top = 80
    Width = 408
    Height = 48
    Caption = 'Art'
    TabOrder = 2
    object rbVacation: TRadioButton
      Left = 12
      Top = 20
      Width = 80
      Height = 17
      Caption = 'Urlaub'
      Checked = True
      TabOrder = 0
      TabStop = True
    end
    object rbSick: TRadioButton
      Left = 108
      Top = 20
      Width = 100
      Height = 17
      Caption = 'Krankheit'
      TabOrder = 1
    end
    object rbClear: TRadioButton
      Left = 224
      Top = 20
      Width = 140
      Height = 17
      Caption = 'Status entfernen'
      TabOrder = 2
    end
  end
  object grpUmfang: TGroupBox
    Left = 16
    Top = 132
    Width = 408
    Height = 48
    Caption = 'Umfang'
    TabOrder = 3
    object rbFull: TRadioButton
      Left = 12
      Top = 20
      Width = 100
      Height = 17
      Caption = 'Ganzer Tag'
      Checked = True
      TabOrder = 0
      TabStop = True
    end
    object rbHalf: TRadioButton
      Left = 128
      Top = 20
      Width = 100
      Height = 17
      Caption = 'Halber Tag'
      TabOrder = 1
    end
  end
  object btnOk: TButton
    Left = 248
    Top = 240
    Width = 90
    Height = 25
    Caption = #220'bernehmen'
    Default = True
    TabOrder = 4
  end
  object btnCancel: TButton
    Left = 348
    Top = 240
    Width = 75
    Height = 25
    Cancel = True
    Caption = 'Abbrechen'
    TabOrder = 5
  end
end
