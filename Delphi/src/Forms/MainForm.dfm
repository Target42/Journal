object MainForm: TMainForm
  Left = 0
  Top = 0
  Caption = 'Journal '#8211' Arbeitszeiterfassung'
  ClientHeight = 800
  ClientWidth = 1280
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Menu = MainMenu
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object StatusBar: TStatusBar
    Left = 0
    Top = 780
    Width = 1280
    Height = 20
    Panels = <>
    SimplePanel = True
  end
  object pnlDay: TPanel
    Left = 0
    Top = 650
    Width = 1280
    Height = 130
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    object grpDay: TGroupBox
      Left = 4
      Top = 0
      Width = 1272
      Height = 130
      Align = alClient
      Caption = 'Tages'#252'bersicht'
      Padding.Left = 6
      Padding.Top = 2
      Padding.Right = 6
      Padding.Bottom = 6
      TabOrder = 0
    end
  end
  object splDay: TSplitter
    Left = 0
    Top = 645
    Width = 1280
    Height = 5
    Cursor = crVSplit
    Align = alBottom
  end
  object pnlTop: TPanel
    Left = 0
    Top = 0
    Width = 1280
    Height = 645
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 2
    object pnlLeft: TPanel
      Left = 0
      Top = 0
      Width = 720
      Height = 645
      Align = alLeft
      BevelOuter = bvNone
      TabOrder = 0
      object grpMonth: TGroupBox
        Left = 4
        Top = 0
        Width = 716
        Height = 645
        Align = alClient
        Caption = 'Monats'#252'bersicht'
        Padding.Left = 6
        Padding.Top = 2
        Padding.Right = 6
        Padding.Bottom = 6
        TabOrder = 0
      end
    end
    object splVert: TSplitter
      Left = 720
      Top = 0
      Width = 5
      Height = 645
    end
    object pnlRight: TPanel
      Left = 725
      Top = 0
      Width = 555
      Height = 645
      Align = alClient
      BevelOuter = bvNone
      TabOrder = 1
      object pnlYear: TPanel
        Left = 0
        Top = 0
        Width = 555
        Height = 260
        Align = alTop
        BevelOuter = bvNone
        TabOrder = 0
        object grpYear: TGroupBox
          Left = 0
          Top = 0
          Width = 555
          Height = 260
          Align = alClient
          Caption = 'Jahres'#252'bersicht'
          Padding.Left = 6
          Padding.Top = 2
          Padding.Right = 6
          Padding.Bottom = 6
          TabOrder = 0
        end
      end
      object splYear: TSplitter
        Left = 0
        Top = 260
        Width = 555
        Height = 5
        Cursor = crVSplit
        Align = alTop
      end
      object pnlChart: TPanel
        Left = 0
        Top = 265
        Width = 555
        Height = 180
        Align = alTop
        BevelOuter = bvNone
        TabOrder = 1
        object grpChart: TGroupBox
          Left = 0
          Top = 0
          Width = 555
          Height = 180
          Align = alClient
          Caption = 'Arbeitspaket'#252'bersicht'
          Padding.Left = 6
          Padding.Top = 2
          Padding.Right = 6
          Padding.Bottom = 6
          TabOrder = 0
        end
      end
      object splChart: TSplitter
        Left = 0
        Top = 445
        Width = 555
        Height = 5
        Cursor = crVSplit
        Align = alTop
      end
      object pnlTrend: TPanel
        Left = 0
        Top = 450
        Width = 555
        Height = 195
        Align = alClient
        BevelOuter = bvNone
        TabOrder = 2
        object grpTrend: TGroupBox
          Left = 0
          Top = 0
          Width = 555
          Height = 195
          Align = alClient
          Caption = 'Trend'#252'bersicht'
          Padding.Left = 6
          Padding.Top = 2
          Padding.Right = 6
          Padding.Bottom = 6
          TabOrder = 0
        end
      end
    end
  end
  object MainMenu: TMainMenu
    Left = 40
    Top = 24
    object miDatei: TMenuItem
      Caption = '&Datei'
      object miDatenordner: TMenuItem
        Caption = 'Datenordner w'#228'hlen'#8230
      end
      object miEinstellungen: TMenuItem
        Caption = 'Einstellungen'#8230
      end
      object miTitel: TMenuItem
        Caption = 'Titel'#8230
      end
      object miTermine: TMenuItem
        Caption = 'Termine'#8230
      end
      object miAbsence: TMenuItem
        Caption = 'Urlaub / Krankheit'#8230
      end
      object N1: TMenuItem
        Caption = '-'
      end
      object miRente: TMenuItem
        Caption = 'Rentenrechner'#8230
      end
      object miArbZG: TMenuItem
        Caption = 'ArbZG'#8230
      end
      object N2: TMenuItem
        Caption = '-'
      end
      object miFeiertage: TMenuItem
        Caption = 'Feiertage herunterladen'#8230
      end
      object miFerien: TMenuItem
        Caption = 'Ferien herunterladen'#8230
      end
      object N3: TMenuItem
        Caption = '-'
      end
      object miBeenden: TMenuItem
        Caption = 'Beenden'
      end
    end
    object miHilfe: TMenuItem
      Caption = '&Hilfe'
      object miUeber: TMenuItem
        Caption = #220'ber Journal'
      end
    end
  end
end
