unit DayViewFrame;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls,
  Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Menus, Journal.Types;

type
  TDateNotify = procedure(const ADate: TDate) of object;

  TPackageLayout = record
    Id: string;
    Rect: TRect;
    StartMinute: Integer;
  end;

  TDayViewFrame = class(TFrame)
    pnlHeader: TPanel;
    lblHeader: TLabel;
    btnBounds: TButton;
    btnPause: TButton;
    btnAdd: TButton;
    pbChart: TPaintBox;
  private
    FDate: TDate;
    FOnDateChanged: TDateNotify;
    FDragging: Boolean;
    FDragStartMinute: Integer;
    FDragCurrentMinute: Integer;
    FPressedPackageId: string;
    FContextMinute: Integer;
    FContextPackageId: string;
    FContextPause: TPauseInterval;
    procedure StoreChanged;
    procedure SettingsChanged;
    procedure DayRecalculated(const ADate: TDate);
    procedure TitlesChanged;
    procedure RefreshHeader;
    function ChartRect: TRect;
    function BarsRect: TRect;
    function MinuteAtX(X: Integer): Integer;
    function XAtMinute(Minute: Integer): Integer;
    function LayoutPackages: TArray<TPackageLayout>;
    function PackageIdAt(const Pos: TPoint): string;
    function PauseRect(const Pause: TPauseInterval): TRect;
    function PauseAt(const Pos: TPoint): TPauseInterval;
    procedure AddPackageAt(StartMinute, EndMinute: Integer; Active: Boolean);
    procedure EditPackage(const Id: string);
    procedure DeletePackage(const Id: string);
    procedure OpenEditor(const Package: TWorkPackage);
    procedure OpenBoundsDialog(Sender: TObject);
    procedure AddClick(Sender: TObject);
    procedure PauseClick(Sender: TObject);
    procedure OpenPauseAt(Minute: Integer);
    function Bounds: TDayBounds;
    function WindowStart: Integer;
    function WindowEnd: Integer;
    procedure PaintChart(Sender: TObject);
    procedure ChartMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer);
    procedure ChartMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure ChartMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer);
    procedure ChartDblClick(Sender: TObject);
    procedure ChartContextPopup(Sender: TObject; MousePos: TPoint; var Handled: Boolean);
    procedure CtxAdd(Sender: TObject);
    procedure CtxPause(Sender: TObject);
    procedure CtxBounds(Sender: TObject);
    procedure CtxEdit(Sender: TObject);
    procedure CtxDelete(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function DateValue: TDate;
    procedure SetDate(const ADate: TDate);
    property OnDateChanged: TDateNotify read FOnDateChanged write FOnDateChanged;
  end;

implementation

{$R *.dfm}

uses
  System.Math, System.DateUtils, System.Types, System.UITypes, Vcl.Dialogs,
  Journal.Store, Journal.Settings, Journal.TimeTotals, Journal.TitleCatalog,
  Journal.Arbzg, Journal.UiUtil, WorkPackageForm, DayBoundsForm, PauseForm;

const
  HeaderBottom = 0;
  HourTickLength = 12;
  HalfHourTickLength = 8;
  QuarterTickLength = 5;
  AxisLabelGap = 1;
  BottomPadding = 2;

function TickLengthBelowBox(Minute: Integer): Integer;
var
  OfHour: Integer;
begin
  OfHour := Minute mod 60;
  if OfHour = 0 then
    Result := HourTickLength
  else if OfHour = 30 then
    Result := HalfHourTickLength
  else
    Result := QuarterTickLength;
end;

constructor TDayViewFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FDate := Date;
  pbChart.OnPaint := PaintChart;
  pbChart.OnMouseDown := ChartMouseDown;
  pbChart.OnMouseMove := ChartMouseMove;
  pbChart.OnMouseUp := ChartMouseUp;
  pbChart.OnDblClick := ChartDblClick;
  pbChart.OnContextPopup := ChartContextPopup;
  btnBounds.OnClick := OpenBoundsDialog;
  btnPause.OnClick := PauseClick;
  btnAdd.OnClick := AddClick;
  TJournalStore.Instance.OnChanged.Add(StoreChanged);
  TAppSettings.Instance.OnChanged.Add(SettingsChanged);
  TTimeTotals.Instance.OnDayRecalculated.Add(DayRecalculated);
  TTitleCatalog.Instance.OnChanged.Add(TitlesChanged);
  RefreshHeader;
end;

destructor TDayViewFrame.Destroy;
begin
  TJournalStore.Instance.OnChanged.Remove(StoreChanged);
  TAppSettings.Instance.OnChanged.Remove(SettingsChanged);
  TTimeTotals.Instance.OnDayRecalculated.Remove(DayRecalculated);
  TTitleCatalog.Instance.OnChanged.Remove(TitlesChanged);
  inherited Destroy;
end;

function TDayViewFrame.DateValue: TDate;
begin
  Result := FDate;
end;

procedure TDayViewFrame.StoreChanged;
begin
  RefreshHeader;
  pbChart.Invalidate;
end;

procedure TDayViewFrame.SettingsChanged;
begin
  RefreshHeader;
  pbChart.Invalidate;
end;

procedure TDayViewFrame.DayRecalculated(const ADate: TDate);
begin
  if (not DateValid(ADate)) or SameDate(ADate, FDate) then
  begin
    RefreshHeader;
    pbChart.Invalidate;
  end;
end;

procedure TDayViewFrame.TitlesChanged;
begin
  pbChart.Invalidate;
end;

procedure TDayViewFrame.SetDate(const ADate: TDate);
begin
  if (not DateValid(ADate)) or SameDate(ADate, FDate) then
    Exit;
  FDate := ADate;
  RefreshHeader;
  pbChart.Invalidate;
  if Assigned(FOnDateChanged) then
    FOnDateChanged(FDate);
end;

procedure TDayViewFrame.RefreshHeader;
var
  HeaderText, HintText, Line, Eve: string;
  DayBounds: TDayBounds;
  Absence: TAbsence;
  Breaks: TBreakAdjustment;
  Pkg: TWorkPackage;
  Outside: Boolean;
  Arbzg: TArbzgDay;
begin
  DayBounds := Bounds;
  HeaderText := GermanDateLong(FDate);
  if SameDate(FDate, Date) then
    HeaderText := HeaderText + '  ' + MiddleDot + '  heute';
  Eve := EveDayName(FDate);
  if Eve <> '' then
  begin
    if TAppSettings.Instance.IsCompanyFreeEveDate(FDate) then
      HeaderText := HeaderText + '  ' + MiddleDot + '  ' + Eve + ' (frei)'
    else
      HeaderText := HeaderText + '  ' + MiddleDot + '  ' + Eve;
  end;
  Absence := TTimeTotals.Instance.EffectiveAbsenceForDate(FDate);
  if Absence.IsSet then
    HeaderText := HeaderText + '  ' + MiddleDot + '  ' + Absence.LabelText;
  HeaderText := HeaderText + '  ' + MiddleDot + '  Ist ' +
    FormatHours(TTimeTotals.Instance.CreditedHoursForDate(FDate));
  Breaks := TJournalStore.Instance.BreakAdjustmentForDate(FDate);
  if Breaks.AutoPauseMinutes > 0 then
    HeaderText := HeaderText + '  ' + MiddleDot + '  Pause ' + FormatHours(Breaks.AutoPauseMinutes / 60.0);
  Arbzg := AssessArbzgDay(FDate);
  if Arbzg.HasWork then
    HeaderText := HeaderText + '  ' + MiddleDot + '  ArbZG ' + FormatDuration(Arbzg.RawWorkMinutes);
  if Arbzg.HasIssue then
  begin
    HeaderText := HeaderText + '  ' + MiddleDot + '  ' + Arbzg.Issues[0];
    lblHeader.Font.Color := RGB(180, 0, 0);
  end
  else if Length(Arbzg.Notes) > 0 then
  begin
    HeaderText := HeaderText + '  ' + MiddleDot + '  ' + Arbzg.Notes[0];
    lblHeader.Font.Color := RGB(179, 92, 0);
  end
  else
    lblHeader.Font.Color := clWindowText;
  HintText := '';
  for Line in Arbzg.Issues do
    if HintText = '' then HintText := Line else HintText := HintText + sLineBreak + Line;
  for Line in Arbzg.Notes do
    if HintText = '' then HintText := Line else HintText := HintText + sLineBreak + Line;
  lblHeader.Hint := HintText;
  lblHeader.ShowHint := HintText <> '';
  Outside := False;
  for Pkg in TJournalStore.Instance.PackagesForDate(FDate) do
    if (Pkg.StartMinute < DayBounds.StartMinute) or (Pkg.EndMinute(FDate) > DayBounds.EndMinute) then
    begin
      Outside := True;
      Break;
    end;
  if Outside then
    HeaderText := HeaderText + '  ' + MiddleDot + '  erfasst au' + #$00DF + 'erhalb';
  lblHeader.Caption := HeaderText;
  if DayBounds.Custom then
    btnBounds.Caption := DayBounds.LabelText + ' *'
  else
    btnBounds.Caption := DayBounds.LabelText;
end;

function TDayViewFrame.Bounds: TDayBounds;
begin
  Result := TJournalStore.Instance.BoundsForDate(FDate);
end;

function TDayViewFrame.WindowStart: Integer;
begin
  Result := Bounds.StartMinute;
end;

function TDayViewFrame.WindowEnd: Integer;
begin
  Result := Bounds.EndMinute;
end;

function TDayViewFrame.ChartRect: TRect;
var
  Fm: Integer;
  Side, BottomReserve: Integer;
begin
  Fm := pbChart.Canvas.TextWidth('00');
  Side := Fm + pbChart.Canvas.TextWidth(':') div 2 + 6;
  BottomReserve := HourTickLength + AxisLabelGap + pbChart.Canvas.TextHeight('0') + BottomPadding;
  Result := Rect(Side, HeaderBottom, Max(Side, pbChart.Width - Side),
    Max(HeaderBottom, pbChart.Height - BottomReserve));
end;

function TDayViewFrame.BarsRect: TRect;
begin
  Result := ChartRect;
  InflateRect(Result, -1, -2);
end;

function TDayViewFrame.MinuteAtX(X: Integer): Integer;
var
  Chart: TRect;
  StartM, Span: Integer;
  T: Double;
begin
  Chart := ChartRect;
  StartM := WindowStart;
  if Chart.Width <= 1 then
    Exit(StartM);
  T := EnsureRange((X - Chart.Left) / (Chart.Width - 1), 0, 1);
  Span := WindowEnd - StartM;
  Result := StartM + Round(T * Max(1, Span));
end;

function TDayViewFrame.XAtMinute(Minute: Integer): Integer;
var
  Chart: TRect;
  StartM, Span: Integer;
  T: Double;
begin
  Chart := ChartRect;
  StartM := WindowStart;
  Span := Max(1, WindowEnd - StartM);
  T := EnsureRange((Minute - StartM) / Span, 0, 1);
  Result := Chart.Left + Round(T * (Chart.Width - 1));
end;

function TDayViewFrame.LayoutPackages: TArray<TPackageLayout>;
var
  Packages, Filtered: TArray<TWorkPackage>;
  StartBound, EndBound, I, Lane, LaneCount, LaneHeight: Integer;
  LaneEnds: TArray<Integer>;
  Lanes: TArray<Integer>;
  Bars: TRect;
  Pkg: TWorkPackage;
  Item: TPackageLayout;
  X1, X2, Top, Available, Height: Integer;
begin
  StartBound := WindowStart;
  EndBound := WindowEnd;
  Packages := TJournalStore.Instance.PackagesForDate(FDate);
  SetLength(Filtered, 0);
  for Pkg in Packages do
    if (Pkg.EndMinute(FDate) > StartBound) and (Pkg.StartMinute < EndBound) then
    begin
      SetLength(Filtered, Length(Filtered) + 1);
      Filtered[High(Filtered)] := Pkg;
    end;
  SetLength(LaneEnds, 0);
  SetLength(Lanes, Length(Filtered));
  for I := 0 to High(Filtered) do
  begin
    Lane := -1;
    for LaneCount := 0 to High(LaneEnds) do
      if LaneEnds[LaneCount] <= Filtered[I].StartMinute then
      begin
        Lane := LaneCount;
        Break;
      end;
    if Lane < 0 then
    begin
      Lane := Length(LaneEnds);
      SetLength(LaneEnds, Lane + 1);
    end;
    LaneEnds[Lane] := Filtered[I].EndMinute(FDate);
    Lanes[I] := Lane;
  end;
  Bars := BarsRect;
  LaneCount := Max(1, Length(LaneEnds));
  LaneHeight := Bars.Height div LaneCount;
  SetLength(Result, Length(Filtered));
  for I := 0 to High(Filtered) do
  begin
    Pkg := Filtered[I];
    X1 := XAtMinute(ClampInt(Pkg.StartMinute, StartBound, EndBound));
    X2 := XAtMinute(ClampInt(Pkg.EndMinute(FDate), StartBound, EndBound));
    if X2 <= X1 then
      X2 := X1 + 2;
    Item.Id := Pkg.Id;
    Item.StartMinute := Pkg.StartMinute;
    Top := Bars.Top + Lanes[I] * LaneHeight + 1;
    Available := Max(1, Bars.Bottom - Top);
    Height := Min(Available, Max(1, LaneHeight - 2));
    Item.Rect := Rect(X1, Top, X2, Top + Height);
    Result[I] := Item;
  end;
end;

function TDayViewFrame.PackageIdAt(const Pos: TPoint): string;
var
  Layouts: TArray<TPackageLayout>;
  I: Integer;
begin
  Result := '';
  Layouts := LayoutPackages;
  for I := High(Layouts) downto 0 do
    if PtInRect(Layouts[I].Rect, Pos) then
      Exit(Layouts[I].Id);
end;

function TDayViewFrame.PauseRect(const Pause: TPauseInterval): TRect;
var
  Bars: TRect;
  StartBound, EndBound, X1, X2: Integer;
begin
  Bars := BarsRect;
  StartBound := WindowStart;
  EndBound := WindowEnd;
  X1 := XAtMinute(ClampInt(Pause.StartMinute, StartBound, EndBound));
  X2 := XAtMinute(ClampInt(Pause.EndMinute, StartBound, EndBound));
  Result := Rect(X1, Bars.Top, Max(X1 + 2, X2), Bars.Bottom);
end;

function TDayViewFrame.PauseAt(const Pos: TPoint): TPauseInterval;
var
  Pause: TPauseInterval;
begin
  Result := Default(TPauseInterval);
  for Pause in TJournalStore.Instance.PausesForDate(FDate) do
    if PtInRect(PauseRect(Pause), Pos) then
      Exit(Pause);
end;

procedure TDayViewFrame.OpenPauseAt(Minute: Integer);
begin
  TPauseForm.RunAt(Self, FDate, Minute);
end;

procedure TDayViewFrame.PauseClick(Sender: TObject);
var
  Pauses: TArray<TPauseInterval>;
  Window: TDayBounds;
  Best: TPauseInterval;
  Dist, BestDist: Integer;
  Pause: TPauseInterval;
begin
  Pauses := TJournalStore.Instance.PausesForDate(FDate);
  if Length(Pauses) > 0 then
  begin
    Window := TAppSettings.Instance.UsualPauseWindow;
    Best := Pauses[0];
    BestDist := Abs(Best.StartMinute - Window.StartMinute);
    for Pause in Pauses do
    begin
      Dist := Abs(Pause.StartMinute - Window.StartMinute);
      if Dist < BestDist then
      begin
        Best := Pause;
        BestDist := Dist;
      end;
    end;
    TPauseForm.RunRange(Self, FDate, Best.StartMinute, Best.EndMinute, True);
    Exit;
  end;
  Window := TAppSettings.Instance.UsualPauseWindow;
  OpenPauseAt((Window.StartMinute + Window.EndMinute) div 2);
end;

procedure TDayViewFrame.AddPackageAt(StartMinute, EndMinute: Integer; Active: Boolean);
var
  Pkg: TWorkPackage;
begin
  StartMinute := ClampInt(StartMinute, 0, 23 * 60 + 58);
  EndMinute := ClampInt(EndMinute, StartMinute + 1, 23 * 60 + 59);
  while TJournalStore.Instance.StartMinuteTaken(FDate, StartMinute) and (StartMinute < 23 * 60 + 58) do
  begin
    Inc(StartMinute);
    if EndMinute <= StartMinute then
      EndMinute := StartMinute + 1;
  end;
  Pkg := Default(TWorkPackage);
  Pkg.Id := NewPackageId;
  Pkg.StartMinute := StartMinute;
  Pkg.EndMinuteStored := EndMinute;
  Pkg.Active := Active and SameDate(FDate, Date);
  OpenEditor(Pkg);
end;

procedure TDayViewFrame.EditPackage(const Id: string);
var
  Pkg: TWorkPackage;
begin
  Pkg := TJournalStore.Instance.PackageById(FDate, Id);
  if Pkg.Id = '' then
    Exit;
  OpenEditor(Pkg);
end;

procedure TDayViewFrame.DeletePackage(const Id: string);
var
  Pkg: TWorkPackage;
  Error: string;
begin
  Pkg := TJournalStore.Instance.PackageById(FDate, Id);
  if Pkg.Id = '' then
    Exit;
  if MessageDlg(Format('Arbeitspaket ' + DQuoteOpen + '%s' + DQuoteClose + ' wirklich l' + #$00F6 + 'schen?', [Pkg.Title]),
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;
  TJournalStore.Instance.RemovePackage(FDate, Id, Error);
end;

procedure TDayViewFrame.OpenEditor(const Package: TWorkPackage);
var
  Dlg: TWorkPackageForm;
  Error: string;
begin
  Dlg := TWorkPackageForm.Create(Self);
  try
    Dlg.Init(FDate, Package);
    if Dlg.ShowModal <> mrOk then
      Exit;
    if Dlg.WasDeleted then
    begin
      TJournalStore.Instance.RemovePackage(FDate, Package.Id, Error);
      Exit;
    end;
    if not TJournalStore.Instance.SavePackage(FDate, Dlg.Package, Error) then
      MessageDlg(Error, mtWarning, [mbOK], 0);
  finally
    Dlg.Free;
  end;
end;

procedure TDayViewFrame.OpenBoundsDialog(Sender: TObject);
var
  Dlg: TDayBoundsForm;
begin
  Dlg := TDayBoundsForm.Create(Self);
  try
    Dlg.InitDate(FDate);
    Dlg.ShowModal;
  finally
    Dlg.Free;
  end;
end;

procedure TDayViewFrame.AddClick(Sender: TObject);
var
  NowM: Integer;
begin
  if SameDate(FDate, Date) then
  begin
    NowM := TimeToMinute(Time);
    AddPackageAt(NowM, NowM + 30, True);
  end
  else
    AddPackageAt(8 * 60, 8 * 60 + 30, False);
end;

procedure TDayViewFrame.PaintChart(Sender: TObject);
var
  C: TCanvas;
  Chart: TRect;
  StartBound, EndBound, Tick, Minute, X, Extra, YTop, TextX, TextY: Integer;
  WorkStart, NowM, I, RunStart, X1, X2: Integer;
  Packages: TArray<TWorkPackage>;
  Layouts: TArray<TPackageLayout>;
  Pkg: TWorkPackage;
  Color: TColor;
  LabelText: string;
  Breaks: TBreakAdjustment;
  Item: TPackageLayout;
  StartM, EndM: Integer;
  Bars: TRect;
  PauseWindow: TDayBounds;
  PauseWindowBand, Hit, Band: TRect;
  ShowPauseWindow: Boolean;
  Pause: TPauseInterval;

  procedure DrawTickAt(AMinute: Integer);
  var
    OfHour: Integer;
  begin
    X := XAtMinute(AMinute);
    OfHour := AMinute mod 60;
    Extra := TickLengthBelowBox(AMinute);
    if OfHour = 0 then
      C.Pen.Color := clGray
    else if OfHour = 30 then
      C.Pen.Color := clSilver
    else
      C.Pen.Color := RGB(210, 210, 210);
    if (AMinute = StartBound) or (AMinute = EndBound) then
      YTop := Chart.Bottom
    else
      YTop := Chart.Top;
    C.MoveTo(X, YTop);
    C.LineTo(X, Chart.Bottom + Extra);
  end;

  procedure DrawLimit(Hours: Integer; AColor: TColor);
  var
    Mark: Integer;
  begin
    Mark := WorkStart + Hours * 60;
    if (Mark < StartBound) or (Mark > EndBound) then
      Exit;
    C.Pen.Color := AColor;
    C.Pen.Style := psDash;
    X := XAtMinute(Mark);
    C.MoveTo(X, Chart.Top);
    C.LineTo(X, Chart.Bottom);
    C.Pen.Style := psSolid;
  end;

begin
  C := pbChart.Canvas;
  Chart := ChartRect;
  if (Chart.Width <= 0) or (Chart.Height <= 0) then
    Exit;
  C.Brush.Color := clWindow;
  C.FillRect(Chart);
  C.Pen.Color := clGray;
  C.Rectangle(Chart);
  StartBound := WindowStart;
  EndBound := WindowEnd;
  DrawTickAt(StartBound);
  Tick := ((StartBound div 15) + IfThen(StartBound mod 15 = 0, 0, 1)) * 15;
  if Tick = StartBound then
    Inc(Tick, 15);
  while Tick < EndBound do
  begin
    DrawTickAt(Tick);
    Inc(Tick, 15);
  end;
  if EndBound <> StartBound then
    DrawTickAt(EndBound);
  C.Font.Color := clWindowText;
  Minute := 0;
  while Minute <= 24 * 60 do
  begin
    if (Minute >= StartBound) and (Minute <= EndBound) then
    begin
      X := XAtMinute(Minute);
      LabelText := Format('%.2d:00', [Minute div 60]);
      TextX := X - C.TextWidth(Copy(LabelText, 1, 2)) - C.TextWidth(':') div 2;
      TextY := Chart.Bottom + HourTickLength + AxisLabelGap;
      C.TextOut(TextX, TextY, LabelText);
    end;
    Inc(Minute, 60);
  end;
  Packages := TJournalStore.Instance.PackagesForDate(FDate);
  if Length(Packages) > 0 then
  begin
    WorkStart := Packages[0].StartMinute;
    for Pkg in Packages do
      if Pkg.StartMinute < WorkStart then
        WorkStart := Pkg.StartMinute;
    DrawLimit(6, RGB(180, 120, 0));
    DrawLimit(8, RGB(180, 90, 0));
    DrawLimit(10, RGB(180, 60, 0));
    DrawLimit(12, RGB(160, 0, 0));
  end;
  ShowPauseWindow := False;
  PauseWindowBand := Rect(0, 0, 0, 0);
  PauseWindow := TAppSettings.Instance.UsualPauseWindow;
  if (PauseWindow.EndMinute > StartBound) and (PauseWindow.StartMinute < EndBound) then
  begin
    ShowPauseWindow := True;
    X1 := XAtMinute(Max(PauseWindow.StartMinute, StartBound));
    X2 := XAtMinute(Min(PauseWindow.EndMinute, EndBound));
    PauseWindowBand := Rect(X1, Chart.Top + 1, Max(X1 + 1, X2), Chart.Bottom - 1);
    C.Brush.Color := RGB(255, 243, 180);
    C.Pen.Style := psClear;
    C.FillRect(PauseWindowBand);
    C.Pen.Style := psSolid;
    C.Brush.Style := bsSolid;
  end;
  if SameDate(FDate, Date) then
  begin
    NowM := TimeToMinute(Time);
    if (NowM >= StartBound) and (NowM <= EndBound) then
    begin
      C.Pen.Color := RGB(30, 90, 180);
      X := XAtMinute(NowM);
      C.MoveTo(X, Chart.Top);
      C.LineTo(X, Chart.Bottom);
    end;
  end;
  Layouts := LayoutPackages;
  for Pause in TJournalStore.Instance.PausesForDate(FDate) do
  begin
    Hit := TRect.Intersect(PauseRect(Pause), Chart);
    if Hit.Width < 2 then
      Continue;
    C.Brush.Color := RGB(210, 210, 200);
    C.Pen.Color := RGB(120, 120, 110);
    C.RoundRect(Hit.Left, Hit.Top, Hit.Right, Hit.Bottom, 6, 6);
    if Hit.Width > 28 then
    begin
      C.Font.Color := RGB(50, 50, 45);
      C.Brush.Style := bsClear;
      C.TextOut(Hit.Left + 4, Hit.Top + Max(0, (Hit.Height - C.TextHeight('Pause')) div 2),
        ElideText(C, 'Pause', Hit.Width - 8));
      C.Brush.Style := bsSolid;
    end;
  end;
  for Item in Layouts do
  begin
    Pkg := TJournalStore.Instance.PackageById(FDate, Item.Id);
    Color := TTitleCatalog.Instance.ColorFor(Pkg.Title);
    C.Brush.Color := Color;
    C.Pen.Color := C.Brush.Color;
    C.RoundRect(Item.Rect.Left, Item.Rect.Top, Item.Rect.Right, Item.Rect.Bottom, 6, 6);
    LabelText := Pkg.Title;
    if Pkg.Active then
      LabelText := '▶ ' + Pkg.Title;
    if Item.Rect.Width > 24 then
    begin
      C.Font.Color := TextColorFor(Color);
      C.Brush.Style := bsClear;
      C.TextOut(Item.Rect.Left + 4, Item.Rect.Top + Max(0, (Item.Rect.Height - C.TextHeight(LabelText)) div 2),
        ElideText(C, LabelText, Item.Rect.Width - 8));
      C.Brush.Style := bsSolid;
    end;
  end;
  Breaks := TJournalStore.Instance.BreakAdjustmentForDate(FDate);
  if Breaks.AutoPauseMinutes > 0 then
  begin
    RunStart := -1;
    for I := 0 to Length(Breaks.AutoPause) do
    begin
      if (I < Length(Breaks.AutoPause)) and Breaks.AutoPause[I] then
      begin
        if RunStart < 0 then
          RunStart := I;
      end
      else if RunStart >= 0 then
      begin
        X1 := XAtMinute(StartBound + RunStart);
        X2 := XAtMinute(StartBound + I);
        Band := Rect(X1, Chart.Top + 1, Max(X1 + 1, X2), Chart.Bottom - 1);
        C.Brush.Color := RGB(110, 70, 0);
        C.Brush.Style := bsBDiagonal;
        C.Pen.Style := psClear;
        for Item in Layouts do
        begin
          Hit := TRect.Intersect(Item.Rect, Band);
          if not Hit.IsEmpty then
            C.FillRect(Hit);
        end;
        C.Pen.Style := psSolid;
        C.Brush.Style := bsSolid;
        RunStart := -1;
      end;
    end;
  end;
  if ShowPauseWindow then
  begin
    C.Pen.Color := RGB(160, 110, 0);
    C.Brush.Style := bsClear;
    for Item in Layouts do
    begin
      Hit := TRect.Intersect(Item.Rect, PauseWindowBand);
      if not Hit.IsEmpty then
        C.Rectangle(Hit);
    end;
    C.Brush.Style := bsSolid;
  end;
  if FDragging then
  begin
    StartM := Min(FDragStartMinute, FDragCurrentMinute);
    EndM := Max(FDragStartMinute, FDragCurrentMinute);
    Bars := BarsRect;
    X1 := XAtMinute(StartM);
    X2 := Max(X1 + 2, XAtMinute(EndM));
    C.Pen.Style := psDash;
    C.Pen.Color := RGB(40, 40, 40);
    C.Brush.Color := RGB(40, 90, 180);
    C.Rectangle(X1, Bars.Top, X2, Bars.Bottom);
    C.Pen.Style := psSolid;
  end;
end;

procedure TDayViewFrame.ChartMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if Button <> mbLeft then
    Exit;
  if not PtInRect(ChartRect, Point(X, Y)) then
    Exit;
  FPressedPackageId := PackageIdAt(Point(X, Y));
  FDragging := False;
  FDragStartMinute := MinuteAtX(X);
  FDragCurrentMinute := FDragStartMinute;
end;

procedure TDayViewFrame.ChartMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  if not (ssLeft in Shift) or (FPressedPackageId <> '') then
    Exit;
  FDragCurrentMinute := MinuteAtX(X);
  if Abs(FDragCurrentMinute - FDragStartMinute) >= 1 then
  begin
    FDragging := True;
    pbChart.Invalidate;
  end;
end;

procedure TDayViewFrame.ChartMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  StartM, EndM: Integer;
begin
  if Button <> mbLeft then
    Exit;
  if FDragging then
  begin
    StartM := Min(FDragStartMinute, FDragCurrentMinute);
    EndM := Max(FDragStartMinute, FDragCurrentMinute);
    FDragging := False;
    pbChart.Invalidate;
    if EndM > StartM then
      AddPackageAt(StartM, EndM, False);
  end;
  FPressedPackageId := '';
end;

procedure TDayViewFrame.ChartDblClick(Sender: TObject);
var
  P: TPoint;
  Id: string;
  StartM: Integer;
  Pause: TPauseInterval;
begin
  GetCursorPos(P);
  P := pbChart.ScreenToClient(P);
  if not PtInRect(ChartRect, P) then
    Exit;
  Id := PackageIdAt(P);
  if Id <> '' then
  begin
    EditPackage(Id);
    Exit;
  end;
  Pause := PauseAt(P);
  if Pause.IsValid then
  begin
    TPauseForm.RunRange(Self, FDate, Pause.StartMinute, Pause.EndMinute, True);
    Exit;
  end;
  StartM := MinuteAtX(P.X);
  AddPackageAt(StartM, StartM + 30, False);
end;

procedure TDayViewFrame.ChartContextPopup(Sender: TObject; MousePos: TPoint;
  var Handled: Boolean);
var
  Menu: TPopupMenu;
  Item: TMenuItem;
begin
  Handled := True;
  if PtInRect(ChartRect, MousePos) then
  begin
    FContextPackageId := PackageIdAt(MousePos);
    FContextMinute := MinuteAtX(MousePos.X);
    if FContextPackageId = '' then
      FContextPause := PauseAt(MousePos)
    else
      FContextPause := Default(TPauseInterval);
  end
  else
  begin
    FContextPackageId := '';
    FContextMinute := 8 * 60;
    FContextPause := Default(TPauseInterval);
  end;
  Menu := TPopupMenu.Create(Self);
  try
    Item := TMenuItem.Create(Menu);
    Item.Caption := 'Arbeitspaket hinzuf' + #$00FC + 'gen' + Ellipsis;
    Item.OnClick := CtxAdd;
    Menu.Items.Add(Item);
    Item := TMenuItem.Create(Menu);
    if FContextPause.IsValid then
      Item.Caption := 'Pause bearbeiten' + Ellipsis
    else
      Item.Caption := 'Pause einfügen' + Ellipsis;
    Item.OnClick := CtxPause;
    Menu.Items.Add(Item);
    Item := TMenuItem.Create(Menu);
    Item.Caption := 'Tagesgrenzen' + Ellipsis;
    Item.OnClick := CtxBounds;
    Menu.Items.Add(Item);
    if FContextPackageId <> '' then
    begin
      Item := TMenuItem.Create(Menu);
      Item.Caption := 'Bearbeiten' + Ellipsis;
      Item.OnClick := CtxEdit;
      Menu.Items.Add(Item);
      Item := TMenuItem.Create(Menu);
      Item.Caption := 'Löschen';
      Item.OnClick := CtxDelete;
      Menu.Items.Add(Item);
    end;
    Menu.Popup(pbChart.ClientToScreen(MousePos).X, pbChart.ClientToScreen(MousePos).Y);
  finally
    Menu.Free;
  end;
end;

procedure TDayViewFrame.CtxAdd(Sender: TObject);
begin
  AddPackageAt(FContextMinute, FContextMinute + 30, False);
end;

procedure TDayViewFrame.CtxPause(Sender: TObject);
begin
  if FContextPause.IsValid then
    TPauseForm.RunRange(Self, FDate, FContextPause.StartMinute, FContextPause.EndMinute, True)
  else
    OpenPauseAt(FContextMinute);
end;

procedure TDayViewFrame.CtxBounds(Sender: TObject);
begin
  OpenBoundsDialog(Sender);
end;

procedure TDayViewFrame.CtxEdit(Sender: TObject);
begin
  EditPackage(FContextPackageId);
end;

procedure TDayViewFrame.CtxDelete(Sender: TObject);
begin
  DeletePackage(FContextPackageId);
end;

end.
