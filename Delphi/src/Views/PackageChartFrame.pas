unit PackageChartFrame;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls,
  Vcl.Forms, Vcl.ExtCtrls;

type
  TPackageChartFrame = class(TFrame)
    pbChart: TPaintBox;
  private
    FYear: Integer;
    FMonth: Integer;
    procedure StoreChanged;
    procedure SettingsChanged;
    procedure TitlesChanged;
    procedure PaintChart(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure SetMonth(AYear, AMonth: Integer);
    procedure RefreshView;
    function CaptionText: string;
  end;

implementation

{$R *.dfm}

uses
  System.DateUtils, System.Math, Journal.Store, Journal.Settings, Journal.TitleCatalog,
  Journal.Types, Journal.UiUtil;

constructor TPackageChartFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FYear := YearOf(Date);
  FMonth := MonthOf(Date);
  pbChart.OnPaint := PaintChart;
  TJournalStore.Instance.OnChanged.Add(StoreChanged);
  TAppSettings.Instance.OnChanged.Add(SettingsChanged);
  TTitleCatalog.Instance.OnChanged.Add(TitlesChanged);
end;

destructor TPackageChartFrame.Destroy;
begin
  TJournalStore.Instance.OnChanged.Remove(StoreChanged);
  TAppSettings.Instance.OnChanged.Remove(SettingsChanged);
  TTitleCatalog.Instance.OnChanged.Remove(TitlesChanged);
  inherited Destroy;
end;

procedure TPackageChartFrame.StoreChanged;
begin
  RefreshView;
end;

procedure TPackageChartFrame.SettingsChanged;
begin
  RefreshView;
end;

procedure TPackageChartFrame.TitlesChanged;
begin
  RefreshView;
end;

procedure TPackageChartFrame.SetMonth(AYear, AMonth: Integer);
begin
  if (AMonth < 1) or (AMonth > 12) then
    Exit;
  if (FYear = AYear) and (FMonth = AMonth) then
    Exit;
  FYear := AYear;
  FMonth := AMonth;
  pbChart.Invalidate;
end;

procedure TPackageChartFrame.RefreshView;
begin
  pbChart.Invalidate;
end;

function TPackageChartFrame.CaptionText: string;
begin
  Result := 'Arbeitspaketübersicht ' + EnDash + ' ' + GermanMonthName(FMonth) + ' ' + IntToStr(FYear);
end;

procedure TPackageChartFrame.PaintChart(Sender: TObject);
var
  C: TCanvas;
  Inner: TRect;
  Rows: TArray<TTitleHours>;
  MaxHours: Double;
  I, Top, RowHeight, LabelWidth, HoursWidth, BarLeft, BarMaxWidth, Y, BarWidth: Integer;
  Color: TColor;
  Bar: TRect;
begin
  C := pbChart.Canvas;
  Inner := pbChart.ClientRect;
  InflateRect(Inner, -4, -4);
  Rows := TJournalStore.Instance.TitleHoursForMonth(FYear, FMonth);
  if Length(Rows) = 0 then
  begin
    C.Font.Color := clGrayText;
    C.TextOut(Inner.Left, Inner.Top + 8, 'Noch keine Arbeitspakete in diesem Monat.');
    C.TextOut(Inner.Left, Inner.Top + 26, 'In der Tagesübersicht per Ziehen oder Doppelklick anlegen.');
    Exit;
  end;
  MaxHours := 0;
  for I := 0 to High(Rows) do
    if Rows[I].Hours > MaxHours then
      MaxHours := Rows[I].Hours;
  if MaxHours <= 0 then
    MaxHours := 1;
  Top := Inner.Top;
  RowHeight := Max(22, Min(32, Inner.Height div Max(1, Length(Rows))));
  LabelWidth := 130;
  HoursWidth := 56;
  BarLeft := Inner.Left + LabelWidth;
  BarMaxWidth := Max(20, Inner.Width - LabelWidth - HoursWidth - 8);
  for I := 0 to High(Rows) do
  begin
    Y := Top + I * RowHeight;
    if Y + 16 > Inner.Bottom then
      Break;
    Color := TTitleCatalog.Instance.ColorFor(Rows[I].Title);
    C.Font.Color := clWindowText;
    C.Brush.Style := bsClear;
    C.TextOut(Inner.Left, Y + 2, ElideText(C, Rows[I].Title, LabelWidth - 8));
    BarWidth := Max(2, Round(BarMaxWidth * (Rows[I].Hours / MaxHours)));
    Bar := Rect(BarLeft, Y + 4, BarLeft + BarWidth, Y + RowHeight - 6);
    C.Brush.Style := bsSolid;
    C.Brush.Color := Color;
    C.Pen.Color := Color;
    C.RoundRect(Bar.Left, Bar.Top, Bar.Right, Bar.Bottom, 6, 6);
    C.Brush.Style := bsClear;
    C.Font.Color := clWindowText;
    C.TextOut(BarLeft + BarMaxWidth + 8, Y + 2, FormatHours(Rows[I].Hours));
  end;
end;

end.
