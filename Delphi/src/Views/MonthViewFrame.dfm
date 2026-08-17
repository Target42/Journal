object MonthViewFrame: TMonthViewFrame
  Left = 0
  Top = 0
  Width = 720
  Height = 480
  TabOrder = 0
  object lblSummary: TLabel
    Left = 0
    Top = 0
    Width = 720
    Height = 32
    Align = alTop
    AutoSize = False
    Caption = 'Monat'
    WordWrap = True
    ExplicitWidth = 200
  end
  object grdDays: TStringGrid
    Left = 0
    Top = 32
    Width = 720
    Height = 448
    Align = alClient
    DefaultDrawing = False
    Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goColSizing, goRowSelect]
    TabOrder = 0
  end
end
