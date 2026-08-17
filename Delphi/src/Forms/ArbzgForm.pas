unit ArbzgForm;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls,
  Vcl.Forms, Vcl.StdCtrls, Vcl.NumberBox, Vcl.Grids, Vcl.ExtCtrls, Vcl.Dialogs;

type
  TArbzgForm = class(TForm)
    lblYear: TLabel;
    nbYear: TNumberBox;
    lblMonth: TLabel;
    cbMonth: TComboBox;
    btnSave: TButton;
    grpAverage: TGroupBox;
    lblAverage: TLabel;
    grpYear: TGroupBox;
    lblYearInfo: TLabel;
    grdDays: TStringGrid;
    lblHint: TLabel;
    btnClose: TButton;
    procedure FormCreate(Sender: TObject);
  private
    FYear: Integer;
    FMonth: Integer;
    procedure RefreshView(Sender: TObject);
    procedure SaveNachweis(Sender: TObject);
    procedure CloseClick(Sender: TObject);
    procedure GridDrawCell(Sender: TObject; ACol, ARow: Integer; Rect: TRect;
      State: TGridDrawState);
  public
    procedure Init(AYear, AMonth: Integer);
  end;

implementation

{$R *.dfm}

uses
  System.DateUtils, System.IOUtils, Journal.Types, Journal.Arbzg, Journal.UiUtil;

procedure TArbzgForm.Init(AYear, AMonth: Integer);
begin
  FYear := AYear;
  FMonth := AMonth;
  if FYear < 1970 then
    FYear := YearOf(Date);
  if (FMonth < 1) or (FMonth > 12) then
    FMonth := MonthOf(Date);
  nbYear.Value := FYear;
  if (FMonth >= 1) and (FMonth <= 12) then
    cbMonth.ItemIndex := FMonth - 1;
  RefreshView(nil);
end;

procedure TArbzgForm.FormCreate(Sender: TObject);
var
  I: Integer;
begin
  FYear := YearOf(Date);
  FMonth := MonthOf(Date);
  nbYear.Value := FYear;
  cbMonth.Items.Clear;
  for I := 1 to 12 do
    cbMonth.Items.Add(GermanMonthName(I));
  cbMonth.ItemIndex := FMonth - 1;
  grdDays.ColCount := 4;
  grdDays.FixedRows := 1;
  grdDays.FixedCols := 0;
  grdDays.DefaultRowHeight := 22;
  grdDays.Cells[0, 0] := 'Tag';
  grdDays.Cells[1, 0] := 'Arbeitszeit';
  grdDays.Cells[2, 0] := 'Pause';
  grdDays.Cells[3, 0] := 'Hinweise';
  ApplyMonoFont(grdDays);
  EnableGridColumnResize(grdDays);
  grdDays.OnDrawCell := GridDrawCell;
  nbYear.OnChangeValue := RefreshView;
  btnSave.OnClick := SaveNachweis;
  btnClose.OnClick := CloseClick;
end;

procedure TArbzgForm.RefreshView(Sender: TObject);
var
  Summary: TArbzgSummary;
  Rows: TArray<TArbzgDay>;
  I, J: Integer;
  Day: TArbzgDay;
  Hints: string;
  Line: string;
  Avg: string;

  procedure AddRow(const ADay: TArbzgDay);
  begin
    SetLength(Rows, Length(Rows) + 1);
    Rows[High(Rows)] := ADay;
  end;

  function PeriodLine(const Title: string; const Period: TArbzgPeriod): string;
  begin
    Result := Format('%s (%s–%s): %s h je Werktag',
      [Title, FormatDateTime('dd.mm.yyyy', Period.FromDate),
       FormatDateTime('dd.mm.yyyy', Period.ToDate),
       FormatHours(Period.AverageWeekdayHours)]);
    if Period.AverageExceeded then
      Result := Result + '  (über 8 h)';
  end;

begin
  FYear := Round(nbYear.Value);
  Summary := SummarizeArbzgYear(FYear);
  Avg := PeriodLine('6 Kalendermonate', Summary.SixMonths) + sLineBreak +
    PeriodLine('24 Wochen', Summary.TwentyFourWeeks) + sLineBreak;
  if Summary.CompensationFailed then
    Avg := Avg + 'Ausgleich verfehlt: in beiden Zeiträumen liegen mehr als 8 Stunden je Werktag (Mo–Sa).'
  else
    Avg := Avg + 'Ausgleich erfüllt, wenn mindestens ein Zeitraum ≤ 8,00 h bleibt. ' +
      'Tage über 10 Stunden sind unabhängig davon unzulässig.';
  lblAverage.Caption := Avg;

  lblYearInfo.Caption :=
    Format('Tage > 8 h: %d  ·  Tage > 10 h: %d  ·  Pausenverstöße: %d  ·  Ruhezeit < 11 h: %d',
      [Summary.DaysOverEight, Summary.DaysOverTen, Summary.PauseViolations, Summary.RestViolations]) +
    sLineBreak +
    Format('Sonntagsarbeit: %d  ·  Feiertagsarbeit: %d  ·  freie Sonntage: %d von %d (mindestens 15)',
      [Summary.SundayWorkDays, Summary.HolidayWorkDays, Summary.FreeSundays, Summary.SundaysInYear]);
  if Summary.TooFewFreeSundays then
    lblYearInfo.Caption := lblYearInfo.Caption + '  – zu wenige freie Sonntage (§11)';
  if Summary.ErsatzruheMissing > 0 then
    lblYearInfo.Caption := lblYearInfo.Caption + Format('  ·  Ersatzruhe fehlt: %d', [Summary.ErsatzruheMissing]);
  lblYearInfo.Caption := lblYearInfo.Caption + sLineBreak +
    Format('Nachtarbeitstage: %d (Nachtarbeitnehmer ab 48)', [Summary.NightWorkDays]);
  if Summary.NightWorker then
    lblYearInfo.Caption := lblYearInfo.Caption +
      '  – Nachtarbeitnehmer: engerer 8-Stunden-Ausgleich in 4 Wochen / 1 Monat (§6)';
  if Summary.UsualPauseHints > 0 then
    lblYearInfo.Caption := lblYearInfo.Caption + sLineBreak +
      Format('Übliche Pause verpasst: %d Tag(e)', [Summary.UsualPauseHints]);

  SetLength(Rows, 0);
  for Day in Summary.IssueDays do
    AddRow(Day);
  for Day in Summary.NoteDays do
    AddRow(Day);
  for I := 0 to High(Rows) - 1 do
    for J := I + 1 to High(Rows) do
      if Rows[J].Date < Rows[I].Date then
      begin
        Day := Rows[I];
        Rows[I] := Rows[J];
        Rows[J] := Day;
      end;

  if Length(Rows) = 0 then
    grdDays.RowCount := 2
  else
    grdDays.RowCount := Length(Rows) + 1;
  grdDays.Cells[0, 1] := '';
  grdDays.Cells[1, 1] := '';
  grdDays.Cells[2, 1] := '';
  grdDays.Cells[3, 1] := '';
  for I := 0 to High(Rows) do
  begin
    Day := Rows[I];
    grdDays.Cells[0, I + 1] := FormatDateTime('ddd, dd.mm.yyyy', Day.Date);
    grdDays.Cells[1, I + 1] := FormatDuration(Day.RawWorkMinutes);
    grdDays.Cells[2, I + 1] := FormatDuration(Day.ActualPauseMinutes);
    Hints := '';
    for Line in Day.Issues do
      if Hints = '' then Hints := Line else Hints := Hints + ' · ' + Line;
    for Line in Day.Notes do
      if Hints = '' then Hints := Line else Hints := Hints + ' · ' + Line;
    grdDays.Cells[3, I + 1] := Hints;
    if Day.HasIssue then
      grdDays.Objects[3, I + 1] := TObject(1)
    else
      grdDays.Objects[3, I + 1] := TObject(2);
  end;
  FitLastGridColumn(grdDays);
end;

procedure TArbzgForm.SaveNachweis(Sender: TObject);
var
  Dlg: TSaveDialog;
  Month: Integer;
  Path: string;
begin
  Month := cbMonth.ItemIndex + 1;
  if Month < 1 then
    Month := MonthOf(Date);
  Dlg := TSaveDialog.Create(Self);
  try
    Dlg.Title := 'Arbeitszeitnachweis speichern';
    Dlg.Filter := 'HTML (*.html)|*.html';
    Dlg.DefaultExt := 'html';
    Dlg.FileName := Format('Arbeitszeitnachweis-%.4d-%.2d.html', [FYear, Month]);
    if not Dlg.Execute then
      Exit;
    Path := Dlg.FileName;
  finally
    Dlg.Free;
  end;
  TFile.WriteAllText(Path, ArbzgNachweisHtml(FYear, Month), TEncoding.UTF8);
  MessageDlg('Nachweis gespeichert.', mtInformation, [mbOK], 0);
end;

procedure TArbzgForm.CloseClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

procedure TArbzgForm.GridDrawCell(Sender: TObject; ACol, ARow: Integer; Rect: TRect;
  State: TGridDrawState);
begin
  UseGridFont(grdDays);
  if ARow = 0 then
  begin
    grdDays.Canvas.Brush.Color := clBtnFace;
    grdDays.Canvas.Font.Color := clWindowText;
  end
  else if gdSelected in State then
  begin
    grdDays.Canvas.Brush.Color := clHighlight;
    grdDays.Canvas.Font.Color := clHighlightText;
  end
  else
  begin
    grdDays.Canvas.Brush.Color := clWindow;
    if NativeInt(grdDays.Objects[3, ARow]) = 1 then
      grdDays.Canvas.Font.Color := RGB(180, 0, 0)
    else if NativeInt(grdDays.Objects[3, ARow]) = 2 then
      grdDays.Canvas.Font.Color := RGB(179, 92, 0)
    else
      grdDays.Canvas.Font.Color := clWindowText;
  end;
  grdDays.Canvas.FillRect(Rect);
  DrawPlainText(grdDays.Canvas, Rect, grdDays.Cells[ACol, ARow], ACol in [1, 2]);
end;

end.
