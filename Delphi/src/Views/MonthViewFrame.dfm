object MonthViewFrame: TMonthViewFrame
  Left = 0
  Top = 0
  Width = 720
  Height = 480
  TabOrder = 0
  object pnlHeader: TPanel
    Left = 0
    Top = 0
    Width = 720
    Height = 36
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object btnAbsence: TButton
      Left = 552
      Top = 0
      Width = 168
      Height = 36
      Align = alRight
      Caption = 'Urlaub / Krankheit'#8230
      TabOrder = 0
    end
    object lblSummary: TLabel
      Left = 0
      Top = 0
      Width = 552
      Height = 36
      Align = alClient
      AutoSize = False
      Caption = 'Monat'
      Layout = tlCenter
      WordWrap = True
      ExplicitWidth = 200
    end
  end
  object grdDays: TStringGrid
    Left = 0
    Top = 36
    Width = 720
    Height = 444
    Align = alClient
    DefaultDrawing = False
    Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goColSizing, goRowSelect]
    TabOrder = 1
  end
end
