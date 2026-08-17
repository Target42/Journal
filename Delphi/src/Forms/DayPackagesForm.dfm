object DayPackagesForm: TDayPackagesForm
  Left = 0
  Top = 0
  Caption = 'Arbeitspakete'
  ClientHeight = 440
  ClientWidth = 720
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnKeyDown = FormKeyDown
  TextHeight = 15
  object lblSummary: TLabel
    Left = 16
    Top = 12
    Width = 688
    Height = 15
    AutoSize = False
    Caption = 'Arbeitspakete'
  end
  object grdPackages: TStringGrid
    Left = 16
    Top = 36
    Width = 688
    Height = 340
    DefaultDrawing = False
    Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goColSizing, goRowSelect]
    TabOrder = 0
  end
  object btnAdd: TButton
    Left = 16
    Top = 388
    Width = 110
    Height = 25
    Caption = 'Hinzuf'#252'gen'#8230
    TabOrder = 1
  end
  object btnPause: TButton
    Left = 132
    Top = 388
    Width = 90
    Height = 25
    Caption = 'Pause'#8230
    TabOrder = 2
  end
  object btnEdit: TButton
    Left = 228
    Top = 388
    Width = 110
    Height = 25
    Caption = 'Bearbeiten'#8230
    TabOrder = 3
  end
  object btnDelete: TButton
    Left = 344
    Top = 388
    Width = 90
    Height = 25
    Caption = 'L'#246'schen'
    TabOrder = 4
  end
  object btnClose: TButton
    Left = 629
    Top = 388
    Width = 75
    Height = 25
    Cancel = True
    Caption = 'Schlie'#223'en'
    TabOrder = 5
  end
end
