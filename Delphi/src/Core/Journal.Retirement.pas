unit Journal.Retirement;

interface

uses
  System.SysUtils, Journal.Types;

type
  TRetirementCalculator = class
  public
    class function Compute(const FromDate, RetirementDate: TDate;
      ProrateLastYear: Boolean): TRetirementPlan; static;
  end;

implementation

uses
  System.DateUtils, System.Math, Journal.Settings, Journal.Calendar, Journal.TimeTotals;

function FullMonthsWorked(AYear: Integer; const LastWorkDate: TDate): Integer;
var
  Month: Integer;
  StartD, EndD: TDate;
begin
  Result := 0;
  if not DateValid(LastWorkDate) or (YearOf(LastWorkDate) <> AYear) then
    Exit;
  for Month := 1 to 12 do
  begin
    StartD := EncodeDate(AYear, Month, 1);
    EndD := EncodeDate(AYear, Month, DaysInAMonth(AYear, Month));
    if EndD <= LastWorkDate then
      Inc(Result);
  end;
end;

function ProratedVacation(AnnualDays: Double; FullMonths: Integer): Double;
var
  Months: Integer;
  Raw: Double;
begin
  Months := ClampInt(FullMonths, 0, 12);
  Raw := AnnualDays * Months / 12.0;
  Result := Round(Raw * 2.0) / 2.0;
end;

class function TRetirementCalculator.Compute(const FromDate, RetirementDate: TDate;
  ProrateLastYear: Boolean): TRetirementPlan;
var
  Year: Integer;
  Row: TRetirementYearBreakdown;
  HoursPool, HoursPerDay, Taken: Double;
  Day: TDate;
  Countable: Integer;
  IsExitYear: Boolean;
begin
  Result := Default(TRetirementPlan);
  Result.StartDate := FromDate;
  Result.RetirementDate := RetirementDate;
  Result.ProratedLastYear := ProrateLastYear;
  Result.StateName := TAppSettings.Instance.StateDisplayName;
  Result.AnnualVacation := TAppSettings.Instance.WorkSettings.AnnualVacationDays;

  if (not DateValid(FromDate)) or (not DateValid(RetirementDate)) then
  begin
    Result.Error := 'Bitte gültige Daten wählen.';
    Exit;
  end;
  if RetirementDate <= FromDate then
  begin
    Result.Error := 'Der Renteneintritt muss nach dem Stichtag liegen.';
    Exit;
  end;
  Result.LastWorkDate := IncDay(RetirementDate, -1);
  if Result.LastWorkDate < FromDate then
  begin
    Result.Error := 'Zwischen Stichtag und Renteneintritt liegt kein Arbeitstag.';
    Exit;
  end;
  Result.FullMonthsInExitYear := FullMonthsWorked(YearOf(Result.LastWorkDate), Result.LastWorkDate);

  for Year := YearOf(FromDate) to YearOf(Result.LastWorkDate) do
  begin
    TCalendarService.Instance.EnsureYearLoaded(Year);
    Row := Default(TRetirementYearBreakdown);
    Row.Year := Year;
    Row.FromDate := EncodeDate(Year, 1, 1);
    if Row.FromDate < FromDate then
      Row.FromDate := FromDate;
    Row.ToDate := EncodeDate(Year, 12, 31);
    if Row.ToDate > Result.LastWorkDate then
      Row.ToDate := Result.LastWorkDate;
    Row.HolidaysAvailable := TCalendarService.Instance.HasPublicHolidays(Year);
    if not Row.HolidaysAvailable then
    begin
      SetLength(Result.MissingHolidayYears, Length(Result.MissingHolidayYears) + 1);
      Result.MissingHolidayYears[High(Result.MissingHolidayYears)] := Year;
    end;

    HoursPool := 0;
    Day := Row.FromDate;
    while Day <= Row.ToDate do
    begin
      if TAppSettings.Instance.TargetHoursForDate(Day) > 0 then
      begin
        Inc(Row.WorkDays);
        if TCalendarService.Instance.IsPublicHoliday(Day) then
          Inc(Row.HolidaysOnWorkDays)
        else
          HoursPool := HoursPool + TAppSettings.Instance.TargetHoursForDate(Day);
      end;
      Day := IncDay(Day);
    end;

    Countable := Row.WorkDays - Row.HolidaysOnWorkDays;
    if Countable > 0 then
      HoursPerDay := HoursPool / Countable
    else
      HoursPerDay := 0;

    IsExitYear := Year = YearOf(Result.LastWorkDate);
    if IsExitYear and ProrateLastYear then
      Row.VacationDays := ProratedVacation(Result.AnnualVacation, Result.FullMonthsInExitYear)
    else
      Row.VacationDays := Result.AnnualVacation;

    if Year = YearOf(Date) then
    begin
      TTimeTotals.Instance.EnsureYear(Year);
      Taken := TTimeTotals.Instance.YearTotals(Year).VacationTaken;
      Row.VacationDays := Max(0, Row.VacationDays - Taken);
    end;

    Row.RemainingDays := Countable - Row.VacationDays;
    if Row.RemainingDays < 0 then
      Row.RemainingDays := 0;
    Row.RemainingHours := Row.RemainingDays * HoursPerDay;

    SetLength(Result.Years, Length(Result.Years) + 1);
    Result.Years[High(Result.Years)] := Row;
    Inc(Result.TotalWorkDays, Row.WorkDays);
    Inc(Result.TotalHolidays, Row.HolidaysOnWorkDays);
    Result.TotalVacation := Result.TotalVacation + Row.VacationDays;
    Result.TotalRemainingDays := Result.TotalRemainingDays + Row.RemainingDays;
    Result.TotalRemainingHours := Result.TotalRemainingHours + Row.RemainingHours;
  end;
end;

end.
