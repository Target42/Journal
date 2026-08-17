object RetirementForm: TRetirementForm
  Left = 0
  Top = 0
  Caption = 'Rentenrechner'
  ClientHeight = 560
  ClientWidth = 860
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
  object grpZeitraum: TGroupBox
    Left = 16
    Top = 8
    Width = 828
    Height = 140
    Caption = 'Zeitraum'
    TabOrder = 0
    object lblFrom: TLabel
      Left = 12
      Top = 24
      Width = 55
      Height = 15
      Caption = 'Ab Datum:'
    end
    object dtpFrom: TDateTimePicker
      Left = 140
      Top = 20
      Width = 140
      Height = 23
      Format = 'dd.MM.yyyy'
      TabOrder = 0
    end
    object lblRetirement: TLabel
      Left = 12
      Top = 52
      Width = 80
      Height = 15
      Caption = 'Renteneintritt:'
    end
    object dtpRetirement: TDateTimePicker
      Left = 140
      Top = 48
      Width = 140
      Height = 23
      Format = 'dd.MM.yyyy'
      TabOrder = 1
    end
    object lblLastWork: TLabel
      Left = 300
      Top = 52
      Width = 500
      Height = 15
      Caption = 'Letzter Arbeitstag'
    end
    object chkProrate: TCheckBox
      Left = 12
      Top = 80
      Width = 500
      Height = 17
      Caption = 'Urlaub im Austrittsjahr anteilig (1/12 je vollem Monat)'
      TabOrder = 2
    end
    object lblMeta: TLabel
      Left = 12
      Top = 108
      Width = 800
      Height = 15
      Caption = 'Meta'
    end
  end
  object btnCalculate: TButton
    Left = 16
    Top = 156
    Width = 100
    Height = 25
    Caption = 'Berechnen'
    TabOrder = 1
  end
  object btnDownload: TButton
    Left = 124
    Top = 156
    Width = 180
    Height = 25
    Caption = 'Feiertage herunterladen'
    TabOrder = 2
  end
  object lblSummary: TLabel
    Left = 16
    Top = 192
    Width = 828
    Height = 20
    AutoSize = False
    Caption = 'Zusammenfassung'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -13
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object grdYears: TStringGrid
    Left = 16
    Top = 220
    Width = 828
    Height = 240
    DefaultDrawing = False
    Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goColSizing, goRowSelect]
    TabOrder = 3
  end
  object lblStatus: TLabel
    Left = 16
    Top = 468
    Width = 828
    Height = 20
    AutoSize = False
    Caption = 'Status'
  end
  object lblHint: TLabel
    Left = 16
    Top = 492
    Width = 828
    Height = 28
    AutoSize = False
    Caption = 
      'Gez'#228'hlt werden die konfigurierten Arbeitstage. Feiertage, die au' +
      'f einen Arbeitstag fallen, und der Urlaub gehen ab.'
    WordWrap = True
  end
  object btnClose: TButton
    Left = 769
    Top = 524
    Width = 75
    Height = 25
    Cancel = True
    Caption = 'Schlie'#223'en'
    TabOrder = 4
  end
end
