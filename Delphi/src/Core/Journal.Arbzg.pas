unit Journal.Arbzg;

interface

uses
  System.SysUtils, System.Classes, Journal.Types;

const
  MinutesPerDay = 24 * 60;
  NightStartMinute = 23 * 60;
  NightEndMinute = 6 * 60;
  NightWorkThresholdMinutes = 2 * 60;
  MinRestMinutes = 11 * 60;
  WeekdayMaxMinutes = 8 * 60;
  WeekdayHardMaxMinutes = 10 * 60;
  FreeSundaysRequired = 15;
  SundayErsatzDays = 14;
  HolidayErsatzWeeks = 8;
  NightWorkerDaysPerYear = 48;

type
  TPauseInterval = record
    StartMinute: Integer;
    EndMinute: Integer;
  end;

  TArbzgDay = record
    Date: TDate;
    HasWork: Boolean;
    FirstWorkMinute: Integer;
    LastWorkMinute: Integer;
    RawWorkMinutes: Integer;
    ActualPauseMinutes: Integer;
    MaxConsecutiveWorkMinutes: Integer;
    NightMinutes: Integer;
    RestMinutesBefore: Integer;
    NightWork: Boolean;
    Sunday: Boolean;
    PublicHoliday: Boolean;
    SundayOrHolidayWork: Boolean;
    SixHoursUninterrupted: Boolean;
    RequiredPauseMissing: Boolean;
    UsualPauseMissed: Boolean;
    OverEightHours: Boolean;
    OverTenHours: Boolean;
    RestTooShort: Boolean;
    ErsatzruheMissing: Boolean;
    Pauses: TArray<TPauseInterval>;
    Issues: TArray<string>;
    Notes: TArray<string>;
    function HasIssue: Boolean;
  end;

  TArbzgPeriod = record
    FromDate: TDate;
    ToDate: TDate;
    WeekdayCount: Integer;
    AverageWeekdayHours: Double;
    AverageExceeded: Boolean;
  end;

  TArbzgSummary = record
    Year: Integer;
    SixMonths: TArbzgPeriod;
    TwentyFourWeeks: TArbzgPeriod;
    CompensationFailed: Boolean;
    DaysOverEight: Integer;
    DaysOverTen: Integer;
    RestViolations: Integer;
    PauseViolations: Integer;
    ConsecutiveSixHourViolations: Integer;
    SundayWorkDays: Integer;
    HolidayWorkDays: Integer;
    FreeSundays: Integer;
    SundaysInYear: Integer;
    TooFewFreeSundays: Boolean;
    NightWorkDays: Integer;
    NightWorker: Boolean;
    ErsatzruheMissing: Integer;
    UsualPauseHints: Integer;
    IssueDays: TArray<TArbzgDay>;
    NoteDays: TArray<TArbzgDay>;
  end;

function AssessArbzgDay(const ADate: TDate): TArbzgDay;
function SummarizeArbzgYear(AYear: Integer): TArbzgSummary;
function ArbzgNachweisHtml(AYear, AMonth: Integer): string;
function FormatClock(AMinute: Integer): string;
function FormatDuration(AMinutes: Integer): string;

implementation

uses
  System.DateUtils, System.Math, System.StrUtils, Journal.Store, Journal.Settings,
  Journal.Calendar, Journal.UiUtil;

function TArbzgDay.HasIssue: Boolean;
begin
  Result := Length(Issues) > 0;
end;

function FormatClock(AMinute: Integer): string;
begin
  if AMinute < 0 then
    Exit(EnDash);
  if AMinute >= MinutesPerDay then
    Exit('24:00');
  Result := Format('%.2d:%.2d', [AMinute div 60, AMinute mod 60]);
end;

function FormatDuration(AMinutes: Integer): string;
begin
  if AMinutes < 0 then
    Exit(EnDash);
  Result := FormatHours(AMinutes / 60.0) + ' h';
end;

procedure AddText(var Arr: TArray<string>; const S: string);
begin
  SetLength(Arr, Length(Arr) + 1);
  Arr[High(Arr)] := S;
end;

procedure AddDay(var Arr: TArray<TArbzgDay>; const Day: TArbzgDay);
begin
  SetLength(Arr, Length(Arr) + 1);
  Arr[High(Arr)] := Day;
end;

procedure AddPause(var Arr: TArray<TPauseInterval>; StartM, EndM: Integer);
var
  P: TPauseInterval;
begin
  P.StartMinute := StartM;
  P.EndMinute := EndM;
  SetLength(Arr, Length(Arr) + 1);
  Arr[High(Arr)] := P;
end;

function RequiredPauseMinutes(WorkMinutes: Integer): Integer;
begin
  if WorkMinutes > NineHourThresholdMinutes then
    Result := PauseAfterNineHoursMinutes
  else if WorkMinutes > SixHourThresholdMinutes then
    Result := PauseAfterSixHoursMinutes
  else
    Result := 0;
end;

function FirstCovered(const Covered: TArray<Boolean>): Integer;
var
  I: Integer;
begin
  for I := 0 to High(Covered) do
    if Covered[I] then
      Exit(I);
  Result := -1;
end;

function LastCoveredEnd(const Covered: TArray<Boolean>): Integer;
var
  I: Integer;
begin
  for I := High(Covered) downto 0 do
    if Covered[I] then
      Exit(I + 1);
  Result := -1;
end;

function CountCovered(const Covered: TArray<Boolean>): Integer;
var
  Flag: Boolean;
begin
  Result := 0;
  for Flag in Covered do
    if Flag then
      Inc(Result);
end;

function NightMinutesIn(const Covered: TArray<Boolean>): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(Covered) do
    if Covered[I] and ((I >= NightStartMinute) or (I < NightEndMinute)) then
      Inc(Result);
end;

function MaxConsecutive(const Covered: TArray<Boolean>): Integer;
var
  Run: Integer;
  Flag: Boolean;
begin
  Result := 0;
  Run := 0;
  for Flag in Covered do
    if Flag then
    begin
      Inc(Run);
      if Run > Result then
        Result := Run;
    end
    else
      Run := 0;
end;

function QualifyingPauses(const Covered: TArray<Boolean>): TArray<TPauseInterval>;
var
  RawWork, GapStart, GapRun, I: Integer;

  procedure Flush;
  begin
    if (GapRun >= MinQualifyingPauseSegmentMinutes) and
       (RawWork > MinWorkBeforeQualifyingPauseMinutes) then
      AddPause(Result, GapStart, GapStart + GapRun);
    GapStart := -1;
    GapRun := 0;
  end;

begin
  SetLength(Result, 0);
  RawWork := 0;
  GapStart := -1;
  GapRun := 0;
  for I := 0 to High(Covered) do
    if Covered[I] then
    begin
      Flush;
      Inc(RawWork);
    end
    else if RawWork > MinWorkBeforeQualifyingPauseMinutes then
    begin
      if GapRun = 0 then
        GapStart := I;
      Inc(GapRun);
    end;
end;

function IsWeekday(const ADate: TDate): Boolean;
var
  Dow: Integer;
begin
  Dow := IsoWeekDay(ADate);
  Result := (Dow >= 1) and (Dow <= 6);
end;

function DayHasWork(const ADate: TDate): Boolean;
begin
  Result := CountCovered(TJournalStore.Instance.FullDayCoverage(ADate)) > 0;
end;

function RestMinutesBefore(const ADate: TDate; FirstWorkMinute: Integer): Integer;
var
  Cursor: TDate;
  Skipped, I, PrevEnd: Integer;
  Prev: TArray<Boolean>;
begin
  if FirstWorkMinute < 0 then
    Exit(-1);
  Cursor := IncDay(ADate, -1);
  Skipped := 0;
  for I := 0 to 13 do
  begin
    Prev := TJournalStore.Instance.FullDayCoverage(Cursor);
    PrevEnd := LastCoveredEnd(Prev);
    if PrevEnd >= 0 then
      Exit((MinutesPerDay - PrevEnd) + Skipped * MinutesPerDay + FirstWorkMinute);
    Inc(Skipped);
    Cursor := IncDay(Cursor, -1);
  end;
  Result := -1;
end;

function HasErsatzruhe(const WorkDate: TDate; MaxDays: Integer): Boolean;
var
  Deadline, D: TDate;
begin
  Deadline := IncDay(WorkDate, MaxDays);
  D := IncDay(WorkDate, 1);
  while D <= Deadline do
  begin
    if IsWeekday(D) and not DayHasWork(D) then
      Exit(True);
    D := IncDay(D, 1);
  end;
  Result := Deadline > Date;
end;

function AveragePeriod(const FromDate, ToDate: TDate): TArbzgPeriod;
var
  D: TDate;
  WeekdayMinutes: Integer;
begin
  Result := Default(TArbzgPeriod);
  Result.FromDate := FromDate;
  Result.ToDate := ToDate;
  WeekdayMinutes := 0;
  D := FromDate;
  while D <= ToDate do
  begin
    if IsWeekday(D) then
    begin
      Inc(Result.WeekdayCount);
      Inc(WeekdayMinutes, CountCovered(TJournalStore.Instance.FullDayCoverage(D)));
    end;
    D := IncDay(D, 1);
  end;
  if Result.WeekdayCount > 0 then
    Result.AverageWeekdayHours := WeekdayMinutes / 60.0 / Result.WeekdayCount;
  Result.AverageExceeded := Result.AverageWeekdayHours > 8.0001;
end;

function AssessArbzgDay(const ADate: TDate): TArbzgDay;
var
  Covered: TArray<Boolean>;
  Pause: TPauseInterval;
  Needed: Integer;
  PauseWindow: TDayBounds;
  StartedInWindow: Boolean;
  Kind: string;
begin
  Result := Default(TArbzgDay);
  Result.Date := ADate;
  Result.FirstWorkMinute := -1;
  Result.LastWorkMinute := -1;
  Result.RestMinutesBefore := -1;
  if not DateValid(ADate) or (ADate > Date) then
    Exit;
  Covered := TJournalStore.Instance.FullDayCoverage(ADate);
  Result.RawWorkMinutes := CountCovered(Covered);
  Result.HasWork := Result.RawWorkMinutes > 0;
  Result.FirstWorkMinute := FirstCovered(Covered);
  Result.LastWorkMinute := LastCoveredEnd(Covered);
  Result.Pauses := QualifyingPauses(Covered);
  for Pause in Result.Pauses do
    Inc(Result.ActualPauseMinutes, Pause.EndMinute - Pause.StartMinute);
  Result.MaxConsecutiveWorkMinutes := MaxConsecutive(Covered);
  Result.NightMinutes := NightMinutesIn(Covered);
  Result.NightWork := Result.NightMinutes > NightWorkThresholdMinutes;
  Result.Sunday := IsoWeekDay(ADate) = 7;
  Result.PublicHoliday := TCalendarService.Instance.IsPublicHoliday(ADate);
  Result.SundayOrHolidayWork := Result.HasWork and (Result.Sunday or Result.PublicHoliday);
  Result.SixHoursUninterrupted := Result.MaxConsecutiveWorkMinutes > SixHourThresholdMinutes;
  Result.OverEightHours := Result.RawWorkMinutes > WeekdayMaxMinutes;
  Result.OverTenHours := Result.RawWorkMinutes > WeekdayHardMaxMinutes;
  Needed := RequiredPauseMinutes(Result.RawWorkMinutes);
  Result.RequiredPauseMissing := (Needed > 0) and (Result.ActualPauseMinutes < Needed);
  PauseWindow := TAppSettings.Instance.UsualPauseWindow;
  if Result.HasWork and (Result.FirstWorkMinute >= 0) and
     (Result.FirstWorkMinute < PauseWindow.StartMinute) and
     (PauseWindow.StartMinute >= 0) and (PauseWindow.StartMinute <= High(Covered)) and
     Covered[PauseWindow.StartMinute] then
  begin
    StartedInWindow := False;
    for Pause in Result.Pauses do
      if (Pause.StartMinute >= PauseWindow.StartMinute) and
         (Pause.StartMinute <= PauseWindow.EndMinute) then
        StartedInWindow := True;
    Result.UsualPauseMissed := not StartedInWindow;
  end;
  if Result.HasWork then
  begin
    Result.RestMinutesBefore := RestMinutesBefore(ADate, Result.FirstWorkMinute);
    Result.RestTooShort := (Result.RestMinutesBefore >= 0) and
      (Result.RestMinutesBefore < MinRestMinutes);
  end;
  if Result.RequiredPauseMissing then
    AddText(Result.Issues, Format('Pause zu kurz (§4): %s statt %s',
      [FormatDuration(Result.ActualPauseMinutes), FormatDuration(Needed)]));
  if Result.SixHoursUninterrupted then
    AddText(Result.Issues, 'Mehr als 6 h ohne Unterbrechung (§4)');
  if Result.OverTenHours then
    AddText(Result.Issues, 'Mehr als 10 h Arbeitszeit (§3)')
  else if Result.OverEightHours then
    AddText(Result.Notes, 'Mehr als 8 h (§3, Ausgleich nötig)');
  if Result.RestTooShort then
    AddText(Result.Issues, Format('Ruhezeit unter 11 h (§5): %s',
      [FormatDuration(Result.RestMinutesBefore)]));
  if Result.SundayOrHolidayWork then
  begin
    if Result.Sunday then
      Kind := 'Sonntag'
    else
      Kind := TCalendarService.Instance.PublicHolidayName(ADate);
    AddText(Result.Issues, Format('Arbeit am %s (§9)', [Kind]));
  end;
  if Result.NightWork then
    AddText(Result.Notes, Format('Nachtarbeit %s (§6)', [FormatDuration(Result.NightMinutes)]));
  if Result.UsualPauseMissed then
    AddText(Result.Notes, Format('Keine Pause im üblichen Fenster %s%s%s',
      [FormatClock(PauseWindow.StartMinute), EnDash, FormatClock(PauseWindow.EndMinute)]));
end;

function SummarizeArbzgYear(AYear: Integer): TArbzgSummary;
var
  Today, YearStart, YearEnd, D, SixFrom: TDate;
  Day: TArbzgDay;
begin
  Result := Default(TArbzgSummary);
  Result.Year := AYear;
  Today := Date;
  SixFrom := IncMonth(EncodeDate(YearOf(Today), MonthOf(Today), 1), -5);
  Result.SixMonths := AveragePeriod(SixFrom, Today);
  Result.TwentyFourWeeks := AveragePeriod(IncDay(Today, -24 * 7 + 1), Today);
  Result.CompensationFailed := Result.SixMonths.AverageExceeded and
    Result.TwentyFourWeeks.AverageExceeded;
  YearStart := EncodeDate(AYear, 1, 1);
  YearEnd := EncodeDate(AYear, 12, 31);
  TCalendarService.Instance.EnsureYearLoaded(AYear);
  D := YearStart;
  while D <= YearEnd do
  begin
    if IsoWeekDay(D) = 7 then
    begin
      Inc(Result.SundaysInYear);
      if (D > Today) or not DayHasWork(D) then
        Inc(Result.FreeSundays);
    end;
    if D <= Today then
    begin
      Day := AssessArbzgDay(D);
      if Day.OverEightHours then
        Inc(Result.DaysOverEight);
      if Day.OverTenHours then
        Inc(Result.DaysOverTen);
      if Day.RestTooShort then
        Inc(Result.RestViolations);
      if Day.RequiredPauseMissing or Day.SixHoursUninterrupted then
        Inc(Result.PauseViolations);
      if Day.SixHoursUninterrupted then
        Inc(Result.ConsecutiveSixHourViolations);
      if Day.Sunday and Day.HasWork then
      begin
        Inc(Result.SundayWorkDays);
        Day.ErsatzruheMissing := not HasErsatzruhe(D, SundayErsatzDays);
      end;
      if Day.PublicHoliday and Day.HasWork then
      begin
        Inc(Result.HolidayWorkDays);
        Day.ErsatzruheMissing := Day.ErsatzruheMissing or
          not HasErsatzruhe(D, HolidayErsatzWeeks * 7);
      end;
      if Day.ErsatzruheMissing then
      begin
        Inc(Result.ErsatzruheMissing);
        AddText(Day.Issues, 'Ersatzruhetag fehlt (§11)');
      end;
      if Day.NightWork then
        Inc(Result.NightWorkDays);
      if Day.UsualPauseMissed then
        Inc(Result.UsualPauseHints);
      if Day.HasIssue then
        AddDay(Result.IssueDays, Day)
      else if Length(Day.Notes) > 0 then
        AddDay(Result.NoteDays, Day);
    end;
    D := IncDay(D, 1);
  end;
  Result.TooFewFreeSundays := Result.FreeSundays < FreeSundaysRequired;
  Result.NightWorker := Result.NightWorkDays >= NightWorkerDaysPerYear;
end;

function JoinTexts(const Arr: TArray<string>; const Sep: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(Arr) do
  begin
    if I > 0 then
      Result := Result + Sep;
    Result := Result + Arr[I];
  end;
end;

function ArbzgNachweisHtml(AYear, AMonth: Integer): string;
var
  ADate: TDate;
  Days, Day, TotalWork, TotalNight: Integer;
  Assessed: TArbzgDay;
  Pause: TPauseInterval;
  PauseTexts, Hints: TArray<string>;
  Cls, PauseStr, HintStr: string;
begin
  TCalendarService.Instance.EnsureYearLoaded(AYear);
  Days := DaysInAMonth(AYear, AMonth);
  TotalWork := 0;
  TotalNight := 0;
  Result :=
    '<!DOCTYPE html><html lang="de"><head><meta charset="utf-8">' +
    '<title>Arbeitszeitnachweis ' + GermanMonthName(AMonth) + ' ' + IntToStr(AYear) + '</title>' +
    '<style>body{font-family:Segoe UI,sans-serif;font-size:13px;}' +
    'table{border-collapse:collapse;width:100%;}' +
    'th,td{border:1px solid #ccc;padding:4px 6px;text-align:left;}' +
    'th{background:#eee;} td.num{text-align:right;}' +
    '.issue{color:#b40000;} .note{color:#b35c00;}</style></head><body>' +
    '<h1>Arbeitszeitnachweis</h1>' +
    '<p>' + GermanMonthName(AMonth) + ' ' + IntToStr(AYear) + ' ' + MiddleDot +
    ' Bundesland: ' + TAppSettings.Instance.StateDisplayName + '</p>' +
    '<p>Beginn, Ende und Pausen nach ArbZG / BAG. Arbeitszeit ist die Zeit ohne Ruhepausen ' +
    '(volle Erfassung, ohne Tagesgrenzen, ohne automatischen Pausenabzug des Stundenkontos).</p>' +
    '<table><thead><tr><th>Tag</th><th>Beginn</th><th>Ende</th><th>Pausen</th>' +
    '<th class="num">Dauer</th><th class="num">Nacht</th><th>Hinweise</th></tr></thead><tbody>';
  for Day := 1 to Days do
  begin
    ADate := EncodeDate(AYear, AMonth, Day);
    if ADate <= Date then
      Assessed := AssessArbzgDay(ADate)
    else
    begin
      Assessed := Default(TArbzgDay);
      Assessed.Date := ADate;
      Assessed.FirstWorkMinute := -1;
      Assessed.LastWorkMinute := -1;
    end;
    Inc(TotalWork, Assessed.RawWorkMinutes);
    Inc(TotalNight, Assessed.NightMinutes);
    SetLength(PauseTexts, 0);
    for Pause in Assessed.Pauses do
      AddText(PauseTexts, FormatClock(Pause.StartMinute) + EnDash + FormatClock(Pause.EndMinute));
    SetLength(Hints, 0);
    if TCalendarService.Instance.IsPublicHoliday(ADate) then
      AddText(Hints, TCalendarService.Instance.PublicHolidayName(ADate));
    for HintStr in Assessed.Issues do
      AddText(Hints, HintStr);
    for HintStr in Assessed.Notes do
      AddText(Hints, HintStr);
    if Assessed.HasIssue then
      Cls := ' class="issue"'
    else if Length(Assessed.Notes) > 0 then
      Cls := ' class="note"'
    else
      Cls := '';
    if Length(PauseTexts) = 0 then
      PauseStr := EnDash
    else
      PauseStr := JoinTexts(PauseTexts, ', ');
    Result := Result + '<tr' + Cls + '>' +
      '<td>' + GermanDayShort(ADate) + ', ' + FormatDateTime('dd.mm.', ADate) + '</td>' +
      '<td>' + FormatClock(Assessed.FirstWorkMinute) + '</td>' +
      '<td>' + FormatClock(Assessed.LastWorkMinute) + '</td>' +
      '<td>' + PauseStr + '</td>' +
      '<td class="num">' + IfThen(Assessed.HasWork, FormatDuration(Assessed.RawWorkMinutes), EnDash) + '</td>' +
      '<td class="num">' + IfThen(Assessed.NightMinutes > 0, FormatDuration(Assessed.NightMinutes), EnDash) + '</td>' +
      '<td>' + JoinTexts(Hints, '; ') + '</td></tr>';
  end;
  Result := Result + '</tbody></table><p>Summe Arbeitszeit: ' + FormatDuration(TotalWork) +
    ' ' + MiddleDot + ' davon Nachtzeit: ' + FormatDuration(TotalNight) +
    ' ' + MiddleDot + ' erstellt ' + FormatDateTime('dd.mm.yyyy hh:nn', Now) +
    '</p></body></html>';
end;

end.
