object DayViewFrame: TDayViewFrame
  Left = 0
  Top = 0
  Width = 1280
  Height = 100
  TabOrder = 0
  object pnlHeader: TPanel
    Left = 0
    Top = 0
    Width = 1280
    Height = 22
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object lblHeader: TLabel
      Left = 0
      Top = 0
      Width = 1020
      Height = 22
      Align = alClient
      Caption = 'Tag'
      Layout = tlCenter
    end
    object btnBounds: TButton
      Left = 1020
      Top = 0
      Width = 160
      Height = 22
      Align = alRight
      Caption = '06:00'#8211'20:00'
      TabOrder = 0
    end
    object btnPause: TButton
      Left = 1180
      Top = 0
      Width = 60
      Height = 22
      Align = alRight
      Caption = 'Pause'
      TabOrder = 1
    end
    object btnAdd: TButton
      Left = 1240
      Top = 0
      Width = 40
      Height = 22
      Align = alRight
      Caption = '+'
      TabOrder = 2
    end
  end
  object pbChart: TPaintBox
    Left = 0
    Top = 22
    Width = 1280
    Height = 78
    Align = alClient
  end
end
