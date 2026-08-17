object YearViewFrame: TYearViewFrame
  Left = 0
  Top = 0
  Width = 480
  Height = 280
  TabOrder = 0
  object pnlNav: TPanel
    Left = 0
    Top = 0
    Width = 480
    Height = 28
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object btnPrev: TButton
      Left = 0
      Top = 0
      Width = 36
      Height = 28
      Align = alLeft
      Caption = '<'
      TabOrder = 0
    end
    object btnNext: TButton
      Left = 444
      Top = 0
      Width = 36
      Height = 28
      Align = alRight
      Caption = '>'
      TabOrder = 1
    end
    object lblHeader: TLabel
      Left = 36
      Top = 0
      Width = 408
      Height = 28
      Align = alClient
      Alignment = taCenter
      AutoSize = False
      Caption = 'Jahr'
      Layout = tlCenter
      WordWrap = True
    end
  end
  object lblVacation: TLabel
    Left = 0
    Top = 28
    Width = 480
    Height = 20
    Align = alTop
    Alignment = taCenter
    AutoSize = False
    Caption = 'Urlaub'
  end
  object grdMonths: TStringGrid
    Left = 0
    Top = 48
    Width = 480
    Height = 232
    Align = alClient
    DefaultDrawing = False
    Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goColSizing, goRowSelect]
    TabOrder = 1
  end
end
