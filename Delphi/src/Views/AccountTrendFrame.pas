unit AccountTrendFrame;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls,
  Vcl.Forms, Vcl.ExtCtrls, Journal.Types;

type
  TAccountTrendFrame = class(TFrame)
    pbChart: TPaintBox;
  private
    FTrend: TAccountTrend;
    procedure StoreChanged;
    procedure SettingsChanged;
    procedure YearDataChanged(AYear: Integer);
    procedure PaintChart(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure RefreshView;
    function CaptionText: string;
  end;

implementation

{$R *.dfm}

uses
  System.Math, System.Types, Journal.Store, Journal.Settings, Journal.Calendar,
  Journal.TimeTotals, Journal.UiUtil;

constructor TAccountTrendFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  pbChart.Hint := 'Mittelwert der Mehr-/Minderstunden der letzten 30 Tage mit erfasster Arbeitszeit ' +
    '(ohne volle Urlaubs- oder Krankheitstage). Die Hochrechnung nimmt an, dass an allen ' +
    'konfigurierten Arbeitstagen so weitergearbeitet wird. Periodenkappung ist nicht eingerechnet.';
  pbChart.ShowHint := True;
  pbChart.OnPaint := PaintChart;
  TJournalStore.Instance.OnChanged.Add(StoreChanged);
  TAppSettings.Instance.OnChanged.Add(SettingsChanged);
  TCalendarService.Instance.OnYearDataChanged.Add(YearDataChanged);
  RefreshView;
end;

destructor TAccountTrendFrame.Destroy;
begin
  TJournalStore.Instance.OnChanged.Remove(StoreChanged);
  TAppSettings.Instance.OnChanged.Remove(SettingsChanged);
  TCalendarService.Instance.OnYearDataChanged.Remove(YearDataChanged);
  inherited Destroy;
end;

procedure TAccountTrendFrame.StoreChanged;
begin
  RefreshView;
end;

procedure TAccountTrendFrame.SettingsChanged;
begin
  RefreshView;
end;

procedure TAccountTrendFrame.YearDataChanged(AYear: Integer);
begin
  RefreshView;
end;

procedure TAccountTrendFrame.RefreshView;
begin
  FTrend := TTimeTotals.Instance.AccountTrend(30);
  pbChart.Invalidate;
end;

function TAccountTrendFrame.CaptionText: string;
var
  N: Integer;
begin
  N := Length(FTrend.Points);
  if N <= 0 then
    Result := 'Trendübersicht'
  else
    Result := Format('Trendübersicht ' + EnDash + ' letzte %d Arbeitstage (%s' + EnDash + '%s)',
      [N, FormatDateTime('dd.mm.', FTrend.FromDate), FormatDateTime('dd.mm.yyyy', FTrend.ToDate)]);
end;

procedure TAccountTrendFrame.PaintChart(Sender: TObject);
var
  C: TCanvas;
  Inner, ChartRect, Footer, Line1, Line2: TRect;
  N, I, FooterHeight: Integer;
  AvgLabel, WeekLabel, MonthLabel: string;
  Cumulative: TArray<Double>;
  Running, YMin, YMax, Pad, T, X, Y, ZeroY: Double;
  LineColor, FillColor: TColor;
  Pts: TArray<TPoint>;
  Poly: TArray<TPoint>;

  function YToPx(Hours: Double): Integer;
  var
    TT: Double;
  begin
    TT := (Hours - YMin) / (YMax - YMin);
    Result := ChartRect.Bottom - Round(TT * ChartRect.Height);
  end;

begin
  C := pbChart.Canvas;
  Inner := pbChart.ClientRect;
  InflateRect(Inner, -4, -4);
  N := Length(FTrend.Points);
  if N <= 0 then
  begin
    C.Font.Color := clGrayText;
    C.TextOut(Inner.Left, Inner.Top + 8, 'Noch keine Arbeitstage für einen Trend.');
    C.TextOut(Inner.Left, Inner.Top + 26, 'Es zählen Tage mit erfasster Arbeitszeit.');
    Exit;
  end;
  FooterHeight := C.TextHeight('0') * 2 + 8;
  ChartRect := Inner;
  Inc(ChartRect.Top, 4);
  Dec(ChartRect.Bottom, FooterHeight);
  Footer := Rect(Inner.Left, ChartRect.Bottom + 4, Inner.Right, Inner.Bottom);
  SetLength(Cumulative, N);
  Running := 0;
  YMin := 0;
  YMax := 0;
  for I := 0 to N - 1 do
  begin
    Running := Running + FTrend.Points[I].Saldo;
    Cumulative[I] := Running;
    if Running < YMin then
      YMin := Running;
    if Running > YMax then
      YMax := Running;
  end;
  if Abs(YMax - YMin) < 0.05 then
  begin
    YMax := YMax + 0.5;
    YMin := YMin - 0.5;
  end
  else
  begin
    Pad := (YMax - YMin) * 0.12;
    YMax := YMax + Pad;
    YMin := YMin - Pad;
  end;
  ZeroY := YToPx(0);
  C.Pen.Style := psDash;
  C.Pen.Color := clGray;
  C.MoveTo(ChartRect.Left, Round(ZeroY));
  C.LineTo(ChartRect.Right, Round(ZeroY));
  C.Pen.Style := psSolid;
  SetLength(Pts, N);
  for I := 0 to N - 1 do
  begin
    if N = 1 then
      X := ChartRect.CenterPoint.X
    else
      X := ChartRect.Left + (ChartRect.Width * I / (N - 1));
    Y := YToPx(Cumulative[I]);
    Pts[I] := Point(Round(X), Round(Y));
  end;
  FillColor := HoursColor(FTrend.TotalSaldo);
  if FillColor = clWindowText then
    FillColor := clGray;
  C.Brush.Color := FillColor;
  C.Pen.Style := psClear;
  { simple fill under line to zero }
  SetLength(Poly, N + 2);
  for I := 0 to N - 1 do
    Poly[I] := Pts[I];
  Poly[N] := Point(Pts[High(Pts)].X, Round(ZeroY));
  Poly[N + 1] := Point(Pts[0].X, Round(ZeroY));
  C.Polygon(Poly);
  LineColor := HoursColor(FTrend.TotalSaldo);
  C.Pen.Style := psSolid;
  C.Pen.Color := LineColor;
  C.Pen.Width := 2;
  C.Brush.Style := bsClear;
  C.Polyline(Pts);
  C.Brush.Style := bsSolid;
  C.Brush.Color := LineColor;
  C.Pen.Color := LineColor;
  for I := 0 to High(Pts) do
    C.Ellipse(Pts[I].X - 2, Pts[I].Y - 2, Pts[I].X + 3, Pts[I].Y + 3);
  C.Pen.Width := 1;
  AvgLabel := 'Ø je Arbeitstag: ';
  WeekLabel := 'ca. je Woche: ';
  MonthLabel := 'ca. je Monat: ';
  Line1 := Rect(Footer.Left, Footer.Top, Footer.Right, Footer.Top + C.TextHeight('0') + 2);
  Line2 := Rect(Footer.Left, Line1.Bottom, Footer.Right, Footer.Bottom);
  C.Brush.Style := bsClear;
  C.Font.Color := clWindowText;
  C.TextOut(Line1.Left, Line1.Top, AvgLabel);
  C.Font.Color := HoursColor(FTrend.AveragePerWorkedDay);
  C.TextOut(Line1.Left + C.TextWidth(AvgLabel), Line1.Top, FormatHoursAbs(FTrend.AveragePerWorkedDay));
  C.Font.Color := clWindowText;
  C.TextOut(Line2.Left, Line2.Top, WeekLabel);
  C.Font.Color := HoursColor(FTrend.ProjectedPerWeek);
  C.TextOut(Line2.Left + C.TextWidth(WeekLabel), Line2.Top, FormatHoursAbs(FTrend.ProjectedPerWeek));
  C.Font.Color := clWindowText;
  C.TextOut(Line2.Left + C.TextWidth(WeekLabel + FormatHoursAbs(FTrend.ProjectedPerWeek)) + 16,
    Line2.Top, MiddleDot + '   ' + MonthLabel + FormatHoursAbs(FTrend.ProjectedPerMonth));
end;

end.
