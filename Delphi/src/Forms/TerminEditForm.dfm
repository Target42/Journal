object TerminEditForm: TTerminEditForm
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Termin'
  ClientHeight = 300
  ClientWidth = 500
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  OnCreate = FormCreate
  TextHeight = 15
  object lblTitel: TLabel
    Left = 16
    Top = 20
    Width = 28
    Height = 15
    Caption = 'Titel:'
  end
  object lblVon: TLabel
    Left = 16
    Top = 56
    Width = 24
    Height = 15
    Caption = 'Von:'
  end
  object lblBis: TLabel
    Left = 176
    Top = 56
    Width = 21
    Height = 15
    Caption = 'Bis:'
  end
  object lblHint: TLabel
    Left = 16
    Top = 216
    Width = 468
    Height = 32
    AutoSize = False
    Caption = 
      'Termine dienen nur der Orientierung. Sie z'#228'hlen nicht zur Arbeit' +
      'szeit.'
    WordWrap = True
  end
  object edtTitle: TEdit
    Left = 80
    Top = 16
    Width = 404
    Height = 23
    TabOrder = 0
  end
  object dtpStart: TDateTimePicker
    Left = 48
    Top = 52
    Width = 90
    Height = 23
    Kind = dtkTime
    Format = 'HH:mm'
    TabOrder = 1
  end
  object dtpEnd: TDateTimePicker
    Left = 208
    Top = 52
    Width = 90
    Height = 23
    Kind = dtkTime
    Format = 'HH:mm'
    TabOrder = 2
  end
  object grpKind: TGroupBox
    Left = 16
    Top = 88
    Width = 468
    Height = 116
    Caption = 'Wiederholung'
    TabOrder = 3
    object lblDate: TLabel
      Left = 108
      Top = 24
      Width = 38
      Height = 15
      Caption = 'Datum:'
    end
    object rbOnce: TRadioButton
      Left = 12
      Top = 22
      Width = 90
      Height = 17
      Caption = 'Einmalig'
      Checked = True
      TabOrder = 0
      TabStop = True
    end
    object dtpDate: TDateTimePicker
      Left = 160
      Top = 18
      Width = 130
      Height = 23
      Date = 45658.000000000000000000
      Format = 'dd.MM.yyyy'
      TabOrder = 1
    end
    object rbWeekly: TRadioButton
      Left = 12
      Top = 54
      Width = 90
      Height = 17
      Caption = 'W'#246'chentlich'
      TabOrder = 2
    end
    object chkMo: TCheckBox
      Left = 108
      Top = 54
      Width = 40
      Height = 17
      Caption = 'Mo'
      TabOrder = 3
    end
    object chkDi: TCheckBox
      Left = 152
      Top = 54
      Width = 40
      Height = 17
      Caption = 'Di'
      TabOrder = 4
    end
    object chkMi: TCheckBox
      Left = 196
      Top = 54
      Width = 40
      Height = 17
      Caption = 'Mi'
      TabOrder = 5
    end
    object chkDo: TCheckBox
      Left = 240
      Top = 54
      Width = 40
      Height = 17
      Caption = 'Do'
      TabOrder = 6
    end
    object chkFr: TCheckBox
      Left = 284
      Top = 54
      Width = 40
      Height = 17
      Caption = 'Fr'
      TabOrder = 7
    end
    object chkSa: TCheckBox
      Left = 328
      Top = 54
      Width = 40
      Height = 17
      Caption = 'Sa'
      TabOrder = 8
    end
    object chkSo: TCheckBox
      Left = 372
      Top = 54
      Width = 40
      Height = 17
      Caption = 'So'
      TabOrder = 9
    end
  end
  object btnDelete: TButton
    Left = 16
    Top = 260
    Width = 110
    Height = 25
    Caption = 'Termin l'#246'schen'
    TabOrder = 4
  end
  object btnOk: TButton
    Left = 308
    Top = 260
    Width = 90
    Height = 25
    Caption = #220'bernehmen'
    Default = True
    TabOrder = 5
  end
  object btnCancel: TButton
    Left = 404
    Top = 260
    Width = 80
    Height = 25
    Cancel = True
    Caption = 'Abbrechen'
    TabOrder = 6
  end
end
