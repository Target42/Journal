object SettingsForm: TSettingsForm
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Einstellungen'
  ClientHeight = 468
  ClientWidth = 660
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  OnCreate = FormCreate
  TextHeight = 15
  object pages: TPageControl
    Left = 16
    Top = 8
    Width = 628
    Height = 400
    ActivePage = tabWork
    TabOrder = 0
    object tabWork: TTabSheet
      Caption = 'Arbeitszeit'
      object grpBundesland: TGroupBox
        Left = 8
        Top = 8
        Width = 604
        Height = 72
        Caption = 'Bundesland'
        TabOrder = 0
        object lblArbeitsort: TLabel
          Left = 12
          Top = 24
          Width = 60
          Height = 15
          Caption = 'Arbeitsort:'
        end
        object lblStateHint: TLabel
          Left = 12
          Top = 48
          Width = 580
          Height = 15
          Caption = 'Feiertage und Schulferien richten sich nach diesem Bundesland.'
        end
        object cbState: TComboBox
          Left = 88
          Top = 20
          Width = 280
          Height = 23
          Style = csDropDownList
          TabOrder = 0
        end
      end
      object grpArbeitstage: TGroupBox
        Left = 8
        Top = 88
        Width = 604
        Height = 52
        Caption = 'Arbeitstage'
        TabOrder = 1
        object chkMo: TCheckBox
          Left = 12
          Top = 22
          Width = 50
          Height = 17
          Caption = 'Mo'
          TabOrder = 0
        end
        object chkDi: TCheckBox
          Left = 72
          Top = 22
          Width = 50
          Height = 17
          Caption = 'Di'
          TabOrder = 1
        end
        object chkMi: TCheckBox
          Left = 132
          Top = 22
          Width = 50
          Height = 17
          Caption = 'Mi'
          TabOrder = 2
        end
        object chkDo: TCheckBox
          Left = 192
          Top = 22
          Width = 50
          Height = 17
          Caption = 'Do'
          TabOrder = 3
        end
        object chkFr: TCheckBox
          Left = 252
          Top = 22
          Width = 50
          Height = 17
          Caption = 'Fr'
          TabOrder = 4
        end
        object chkSa: TCheckBox
          Left = 312
          Top = 22
          Width = 50
          Height = 17
          Caption = 'Sa'
          TabOrder = 5
        end
        object chkSo: TCheckBox
          Left = 372
          Top = 22
          Width = 50
          Height = 17
          Caption = 'So'
          TabOrder = 6
        end
      end
      object grpSoll: TGroupBox
        Left = 8
        Top = 148
        Width = 604
        Height = 168
        Caption = 'Soll-Arbeitszeit'
        TabOrder = 2
        object rbEven: TRadioButton
          Left = 12
          Top = 20
          Width = 220
          Height = 17
          Caption = 'Gleichm'#228#223'ige Verteilung'
          TabOrder = 0
        end
        object lblWeekly: TLabel
          Left = 32
          Top = 48
          Width = 90
          Height = 15
          Caption = 'Wochenstunden:'
        end
        object nbWeekly: TNumberBox
          Left = 140
          Top = 44
          Width = 90
          Height = 23
          Alignment = taRightJustify
          Decimal = 2
          MinValue = 0.000000000000000000
          MaxValue = 80.000000000000000000
          Mode = nbmFloat
          TabOrder = 1
          Value = 40.000000000000000000
        end
        object lblEvenPreview: TLabel
          Left = 32
          Top = 72
          Width = 560
          Height = 15
          Caption = 'Vorschau'
        end
        object rbIndividual: TRadioButton
          Left = 12
          Top = 96
          Width = 280
          Height = 17
          Caption = 'Individuelle Arbeitszeit pro Arbeitstag'
          TabOrder = 2
        end
        object lblMo: TLabel
          Left = 24
          Top = 116
          Width = 16
          Height = 15
          Caption = 'Mo'
        end
        object lblDi: TLabel
          Left = 106
          Top = 116
          Width = 13
          Height = 15
          Caption = 'Di'
        end
        object lblMi: TLabel
          Left = 188
          Top = 116
          Width = 15
          Height = 15
          Caption = 'Mi'
        end
        object lblDo: TLabel
          Left = 270
          Top = 116
          Width = 16
          Height = 15
          Caption = 'Do'
        end
        object lblFr: TLabel
          Left = 352
          Top = 116
          Width = 13
          Height = 15
          Caption = 'Fr'
        end
        object lblSa: TLabel
          Left = 434
          Top = 116
          Width = 15
          Height = 15
          Caption = 'Sa'
        end
        object lblSo: TLabel
          Left = 516
          Top = 116
          Width = 15
          Height = 15
          Caption = 'So'
        end
        object nbMo: TNumberBox
          Left = 24
          Top = 132
          Width = 70
          Height = 23
          Alignment = taRightJustify
          Decimal = 2
          MinValue = 0.000000000000000000
          MaxValue = 24.000000000000000000
          Mode = nbmFloat
          TabOrder = 3
        end
        object nbDi: TNumberBox
          Left = 106
          Top = 132
          Width = 70
          Height = 23
          Alignment = taRightJustify
          Decimal = 2
          MinValue = 0.000000000000000000
          MaxValue = 24.000000000000000000
          Mode = nbmFloat
          TabOrder = 4
        end
        object nbMi: TNumberBox
          Left = 188
          Top = 132
          Width = 70
          Height = 23
          Alignment = taRightJustify
          Decimal = 2
          MinValue = 0.000000000000000000
          MaxValue = 24.000000000000000000
          Mode = nbmFloat
          TabOrder = 5
        end
        object nbDo: TNumberBox
          Left = 270
          Top = 132
          Width = 70
          Height = 23
          Alignment = taRightJustify
          Decimal = 2
          MinValue = 0.000000000000000000
          MaxValue = 24.000000000000000000
          Mode = nbmFloat
          TabOrder = 6
        end
        object nbFr: TNumberBox
          Left = 352
          Top = 132
          Width = 70
          Height = 23
          Alignment = taRightJustify
          Decimal = 2
          MinValue = 0.000000000000000000
          MaxValue = 24.000000000000000000
          Mode = nbmFloat
          TabOrder = 7
        end
        object nbSa: TNumberBox
          Left = 434
          Top = 132
          Width = 70
          Height = 23
          Alignment = taRightJustify
          Decimal = 2
          MinValue = 0.000000000000000000
          MaxValue = 24.000000000000000000
          Mode = nbmFloat
          TabOrder = 8
        end
        object nbSo: TNumberBox
          Left = 516
          Top = 132
          Width = 70
          Height = 23
          Alignment = taRightJustify
          Decimal = 2
          MinValue = 0.000000000000000000
          MaxValue = 24.000000000000000000
          Mode = nbmFloat
          TabOrder = 9
        end
      end
    end
    object tabVacation: TTabSheet
      Caption = 'Urlaub'
      ImageIndex = 1
      object grpUrlaub: TGroupBox
        Left = 8
        Top = 8
        Width = 604
        Height = 56
        Caption = 'Jahresurlaub'
        TabOrder = 0
        object lblUrlaub: TLabel
          Left = 12
          Top = 24
          Width = 100
          Height = 15
          Caption = 'Jahresurlaubstage:'
        end
        object nbVacation: TNumberBox
          Left = 140
          Top = 20
          Width = 90
          Height = 23
          Alignment = taRightJustify
          Decimal = 1
          Increment = 0.500000000000000000
          MinValue = 0.000000000000000000
          MaxValue = 365.000000000000000000
          Mode = nbmFloat
          TabOrder = 0
          Value = 30.000000000000000000
        end
      end
      object grpEve: TGroupBox
        Left = 8
        Top = 72
        Width = 604
        Height = 148
        Caption = 'Heiligabend und Silvester'
        TabOrder = 1
        object lblEve: TLabel
          Left = 12
          Top = 28
          Width = 100
          Height = 15
          Caption = '24.12. und 31.12.:'
        end
        object lblEveHint: TLabel
          Left = 12
          Top = 60
          Width = 576
          Height = 72
          AutoSize = False
          Caption = 
            'Gilt nur, wenn der Tag ein Arbeitstag und kein gesetzlicher Feie' +
            'rtag ist. Weihnachten (25./26.12.) bleibt Feiertag. Eine manuell' +
            ' gesetzte Abwesenheit an diesem Tag hat Vorrang.'
          WordWrap = True
        end
        object cbEve: TComboBox
          Left = 140
          Top = 24
          Width = 440
          Height = 23
          Style = csDropDownList
          TabOrder = 0
        end
      end
    end
    object tabOvertime: TTabSheet
      Caption = 'Konto'
      ImageIndex = 2
      object grpOvertime: TGroupBox
        Left = 8
        Top = 8
        Width = 604
        Height = 200
        Caption = #220'berstundenkonto'
        TabOrder = 0
        object chkOvertimeLimits: TCheckBox
          Left = 12
          Top = 22
          Width = 360
          Height = 17
          Caption = 'Saldo zum Periodenende auf Grenzen kappen'
          TabOrder = 0
        end
        object lblGeltung: TLabel
          Left = 32
          Top = 52
          Width = 45
          Height = 15
          Caption = 'Geltung:'
        end
        object cbPeriod: TComboBox
          Left = 140
          Top = 48
          Width = 180
          Height = 23
          Style = csDropDownList
          TabOrder = 1
        end
        object lblMin: TLabel
          Left = 32
          Top = 84
          Width = 68
          Height = 15
          Caption = 'Untergrenze:'
        end
        object nbMin: TNumberBox
          Left = 140
          Top = 80
          Width = 90
          Height = 23
          Alignment = taRightJustify
          Decimal = 2
          MinValue = -500.000000000000000000
          MaxValue = 500.000000000000000000
          Mode = nbmFloat
          NegativeValueColor = clRed
          TabOrder = 2
          Value = -20.000000000000000000
        end
        object lblMax: TLabel
          Left = 32
          Top = 116
          Width = 67
          Height = 15
          Caption = 'Obergrenze:'
        end
        object nbMax: TNumberBox
          Left = 140
          Top = 112
          Width = 90
          Height = 23
          Alignment = taRightJustify
          Decimal = 2
          MinValue = -500.000000000000000000
          MaxValue = 500.000000000000000000
          Mode = nbmFloat
          TabOrder = 3
          Value = 60.000000000000000000
        end
        object lblOvertimeHint: TLabel
          Left = 12
          Top = 148
          Width = 576
          Height = 40
          AutoSize = False
          Caption = 
            'Zum Periodenende wird der Kontostand auf diese Grenzen gek'#252'rzt. ' +
            'Vorgabe: -20 / +60 Stunden, quartalsweise.'
          WordWrap = True
        end
      end
    end
    object tabDay: TTabSheet
      Caption = 'Tag'
      ImageIndex = 3
      object grpBounds: TGroupBox
        Left = 8
        Top = 8
        Width = 604
        Height = 120
        Caption = 'Tagesgrenzen'
        TabOrder = 0
        object lblVon: TLabel
          Left = 12
          Top = 28
          Width = 24
          Height = 15
          Caption = 'Von:'
        end
        object dtpStart: TDateTimePicker
          Left = 52
          Top = 24
          Width = 90
          Height = 23
          Kind = dtkTime
          Format = 'HH:mm'
          TabOrder = 0
        end
        object lblBis: TLabel
          Left = 160
          Top = 28
          Width = 21
          Height = 15
          Caption = 'Bis:'
        end
        object dtpEnd: TDateTimePicker
          Left = 196
          Top = 24
          Width = 90
          Height = 23
          Kind = dtkTime
          Format = 'HH:mm'
          TabOrder = 1
        end
        object lblBoundsHint: TLabel
          Left = 12
          Top = 56
          Width = 576
          Height = 52
          AutoSize = False
          Caption = 
            'Nur Zeiten innerhalb dieser Grenzen z'#228'hlen f'#252'r Ist und Saldo. Di' +
            'e Erfassung bleibt vollst'#228'ndig. Einzelne Tage k'#246'nnen abweichend ' +
            'gesetzt werden.'
          WordWrap = True
        end
      end
      object grpPause: TGroupBox
        Left = 8
        Top = 136
        Width = 604
        Height = 108
        Caption = #220'bliche Pause'
        TabOrder = 1
        object lblPauseVon: TLabel
          Left = 12
          Top = 28
          Width = 72
          Height = 15
          Caption = 'Beginn von:'
        end
        object dtpPauseStart: TDateTimePicker
          Left = 96
          Top = 24
          Width = 90
          Height = 23
          Kind = dtkTime
          Format = 'HH:mm'
          TabOrder = 0
        end
        object lblPauseBis: TLabel
          Left = 204
          Top = 28
          Width = 21
          Height = 15
          Caption = 'bis:'
        end
        object dtpPauseEnd: TDateTimePicker
          Left = 236
          Top = 24
          Width = 90
          Height = 23
          Kind = dtkTime
          Format = 'HH:mm'
          TabOrder = 1
        end
        object lblPauseHint: TLabel
          Left = 12
          Top = 56
          Width = 576
          Height = 44
          AutoSize = False
          Caption = 
            'Im Team beginnt die Pause in der Regel in diesem Fenster (Vorgab' +
            'e 11:30-12:00). Journal warnt, wenn um diese Zeit noch durchgear' +
            'beitet wird.'
          WordWrap = True
        end
      end
    end
  end
  object btnOk: TButton
    Left = 488
    Top = 420
    Width = 75
    Height = 25
    Caption = 'OK'
    Default = True
    TabOrder = 1
  end
  object btnCancel: TButton
    Left = 569
    Top = 420
    Width = 75
    Height = 25
    Cancel = True
    Caption = 'Abbrechen'
    TabOrder = 2
  end
end
