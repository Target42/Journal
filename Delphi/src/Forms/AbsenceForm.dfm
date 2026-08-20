object AbsenceForm: TAbsenceForm
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Abwesenheit'
  ClientHeight = 340
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
    Top = 236
    Width = 428
    Height = 56
    AutoSize = False
    Caption = 
      'Beim Setzen werden nur Arbeitstage ohne Feiertag ber'#252'cksichtigt.' +
      ' Urlaub, Krankheit und bezahlt frei setzen Ist = Soll (keine Meh' +
      'r-/Minderzeit). Zeitausgleich l'#228'sst das Soll bestehen und geht v' +
      'om Stundenkonto ab.'
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
    Width = 428
    Height = 88
    Caption = 'Art'
    TabOrder = 2
    object rbVacation: TRadioButton
      Left = 12
      Top = 22
      Width = 80
      Height = 17
      Caption = 'Urlaub'
      Checked = True
      TabOrder = 0
      TabStop = True
    end
    object rbSick: TRadioButton
      Left = 108
      Top = 22
      Width = 100
      Height = 17
      Caption = 'Krankheit'
      TabOrder = 1
    end
    object rbPaid: TRadioButton
      Left = 224
      Top = 22
      Width = 100
      Height = 17
      Caption = 'Bezahlt frei'
      TabOrder = 2
    end
    object rbCompensatory: TRadioButton
      Left = 12
      Top = 52
      Width = 120
      Height = 17
      Caption = 'Zeitausgleich'
      TabOrder = 3
    end
    object rbClear: TRadioButton
      Left = 148
      Top = 52
      Width = 140
      Height = 17
      Caption = 'Status entfernen'
      TabOrder = 4
    end
  end
  object grpUmfang: TGroupBox
    Left = 16
    Top = 176
    Width = 428
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
    Left = 268
    Top = 304
    Width = 90
    Height = 25
    Caption = #220'bernehmen'
    Default = True
    TabOrder = 4
  end
  object btnCancel: TButton
    Left = 368
    Top = 304
    Width = 75
    Height = 25
    Cancel = True
    Caption = 'Abbrechen'
    TabOrder = 5
  end
end
