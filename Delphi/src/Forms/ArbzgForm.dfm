object ArbzgForm: TArbzgForm
  Left = 0
  Top = 0
  Caption = 'ArbZG'
  ClientHeight = 640
  ClientWidth = 920
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  OnCreate = FormCreate
  TextHeight = 15
  object lblYear: TLabel
    Left = 16
    Top = 16
    Width = 26
    Height = 15
    Caption = 'Jahr:'
  end
  object nbYear: TNumberBox
    Left = 52
    Top = 12
    Width = 80
    Height = 23
    Alignment = taRightJustify
    Decimal = 0
    MinValue = 1970.000000000000000000
    MaxValue = 2100.000000000000000000
    Mode = nbmInteger
    TabOrder = 0
    Value = 2026.000000000000000000
  end
  object lblMonth: TLabel
    Left = 152
    Top = 16
    Width = 92
    Height = 15
    Caption = 'Nachweis-Monat:'
  end
  object cbMonth: TComboBox
    Left = 256
    Top = 12
    Width = 140
    Height = 23
    Style = csDropDownList
    TabOrder = 1
  end
  object btnSave: TButton
    Left = 412
    Top = 11
    Width = 220
    Height = 25
    Caption = 'Nachweis als HTML speichern'#8230
    TabOrder = 2
  end
  object grpAverage: TGroupBox
    Left = 16
    Top = 48
    Width = 888
    Height = 88
    Caption = 'H'#246'chstarbeitszeit '#167'3 (rollierend bis heute)'
    TabOrder = 3
    object lblAverage: TLabel
      Left = 12
      Top = 24
      Width = 860
      Height = 52
      AutoSize = False
      Caption = 'Durchschnitt'
      WordWrap = True
    end
  end
  object grpYear: TGroupBox
    Left = 16
    Top = 144
    Width = 888
    Height = 100
    Caption = 'Jahr'
    TabOrder = 4
    object lblYearInfo: TLabel
      Left = 12
      Top = 22
      Width = 860
      Height = 68
      AutoSize = False
      Caption = 'Jahr'
      WordWrap = True
    end
  end
  object grdDays: TStringGrid
    Left = 16
    Top = 256
    Width = 888
    Height = 300
    DefaultDrawing = False
    Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goColSizing, goRowSelect]
    TabOrder = 5
  end
  object lblHint: TLabel
    Left = 16
    Top = 564
    Width = 888
    Height = 32
    AutoSize = False
    Caption = 
      'Hinweise, keine Sperre. Das Stundenkonto bleibt unver'#228'ndert (Net' +
      'to inkl. automatischem Pausenabzug). ArbZG rechnet mit der erfas' +
      'sten Rohzeit ohne Tagesgrenzen.'
    WordWrap = True
  end
  object btnClose: TButton
    Left = 829
    Top = 604
    Width = 75
    Height = 25
    Cancel = True
    Caption = 'Schlie'#223'en'
    TabOrder = 6
  end
end
