object WorkPackageForm: TWorkPackageForm
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Arbeitspaket'
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
  object lblDetails: TLabel
    Left = 16
    Top = 56
    Width = 39
    Height = 15
    Caption = 'Details:'
  end
  object lblVon: TLabel
    Left = 16
    Top = 148
    Width = 24
    Height = 15
    Caption = 'Von:'
  end
  object lblBis: TLabel
    Left = 16
    Top = 184
    Width = 21
    Height = 15
    Caption = 'Bis:'
  end
  object cbTitle: TComboBox
    Left = 80
    Top = 16
    Width = 300
    Height = 23
    TabOrder = 0
  end
  object btnColor: TButton
    Left = 392
    Top = 16
    Width = 90
    Height = 25
    Caption = 'Farbe'
    TabOrder = 1
  end
  object memDetails: TMemo
    Left = 80
    Top = 52
    Width = 402
    Height = 80
    TabOrder = 2
  end
  object dtpStart: TDateTimePicker
    Left = 80
    Top = 144
    Width = 90
    Height = 23
    Kind = dtkTime
    Format = 'HH:mm'
    TabOrder = 3
  end
  object dtpEnd: TDateTimePicker
    Left = 80
    Top = 180
    Width = 90
    Height = 23
    Kind = dtkTime
    Format = 'HH:mm'
    TabOrder = 4
  end
  object chkActive: TCheckBox
    Left = 184
    Top = 184
    Width = 280
    Height = 17
    Caption = 'Aktiv (Ende = aktuelle Uhrzeit)'
    TabOrder = 5
  end
  object btnDelete: TButton
    Left = 16
    Top = 256
    Width = 90
    Height = 25
    Caption = 'L'#246'schen'
    TabOrder = 6
  end
  object btnOk: TButton
    Left = 308
    Top = 256
    Width = 75
    Height = 25
    Caption = 'OK'
    Default = True
    TabOrder = 7
  end
  object btnCancel: TButton
    Left = 392
    Top = 256
    Width = 90
    Height = 25
    Cancel = True
    Caption = 'Abbrechen'
    TabOrder = 8
  end
  object dlgColor: TColorDialog
    Left = 248
    Top = 248
  end
end
