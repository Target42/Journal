unit Journal.Types;

interface

uses
  System.SysUtils, System.UITypes, System.Generics.Collections, Vcl.Graphics;

const
  EnDash = #$2013;
  Ellipsis = #$2026;
  MiddleDot = #$00B7;
  DQuoteOpen = #$201E;
  DQuoteClose = #$201C;
  DefaultDayStartMinute = 6 * 60;
  DefaultDayEndMinute = 20 * 60;
  SixHourThresholdMinutes = 6 * 60;
  NineHourThresholdMinutes = 9 * 60;
  PauseAfterSixHoursMinutes = 30;
  PauseAfterNineHoursMinutes = 45;
  MinWorkBeforeQualifyingPauseMinutes = 15;
  MinQualifyingPauseSegmentMinutes = 15;

type
  TAbsenceType = (atNone, atVacation, atSick, atPaidLeave, atCompensatory);
  TWorkTimeMode = (wtmEven, wtmIndividual);
  TOvertimeLimitPeriod = (olpMonthly, olpQuarterly);
  TEveDayTreatment = (edtNormal, edtFullVacation, edtHalfVacation, edtCompanyFree);

  TGermanState = record
    Code: string;
    Name: string;
  end;

  TPackageTitle = record
    Title: string;
    Color: TColor;
  end;

  TWorkPackage = record
    Id: string;
    Title: string;
    Details: string;
    StartMinute: Integer;
    EndMinuteStored: Integer;
    Active: Boolean;
    function EndMinute(const ADate: TDate): Integer;
  end;

  TDayBounds = record
    StartMinute: Integer;
    EndMinute: Integer;
    Custom: Boolean;
    function Span: Integer;
    function LabelText: string;
  end;

  TAbsence = record
    AbsenceType: TAbsenceType;
    Fraction: Double;
    function IsSet: Boolean;
    function IsHalfDay: Boolean;
    function FillsToTarget: Boolean;
    function LabelText: string;
    function TypeString: string;
    class function FromJson(const AType: string; AFraction: Double): TAbsence; static;
  end;

  TOvertimeAccountSettings = record
    LimitsEnabled: Boolean;
    Period: TOvertimeLimitPeriod;
    MinHours: Double;
    MaxHours: Double;
    OpeningEnabled: Boolean;
    OpeningYear: Integer;
    OpeningMonth: Integer;
    OpeningHours: Double;
  end;

  TWorkSettings = record
    AnnualVacationDays: Double;
    EveDayTreatment: TEveDayTreatment;
    WorkTimeMode: TWorkTimeMode;
    WeeklyHours: Double;
    WorkDays: array[0..6] of Boolean;
    HoursPerDay: array[0..6] of Double;
  end;

  TPauseInterval = record
    StartMinute: Integer;
    EndMinute: Integer;
    function IsValid: Boolean;
  end;

  TBreakAdjustment = record
    RawWorkMinutes: Integer;
    CreditedMinutes: Integer;
    AutoPauseMinutes: Integer;
    Credited: TArray<Boolean>;
    AutoPause: TArray<Boolean>;
  end;

  TMonthTotals = record
    Year: Integer;
    Month: Integer;
    TargetHours: Double;
    ActualHours: Double;
    CarryIn: Double;
    MonthSaldo: Double;
    ClosingSaldo: Double;
    ClippedHours: Double;
    VacationTaken: Double;
    VacationPlanned: Double;
  end;

  TYearTotals = record
    Year: Integer;
    TargetHours: Double;
    ActualHours: Double;
    CarryIn: Double;
    Saldo: Double;
    ClosingSaldo: Double;
    ClippedHours: Double;
    VacationTaken: Double;
    VacationPlanned: Double;
  end;

  TAccountTrendPoint = record
    Date: TDate;
    Saldo: Double;
  end;

  TAccountTrend = record
    Points: TArray<TAccountTrendPoint>;
    FromDate: TDate;
    ToDate: TDate;
    TotalSaldo: Double;
    AveragePerWorkedDay: Double;
    ProjectedPerWeek: Double;
    ProjectedPerMonth: Double;
  end;

  TTitleHours = record
    Title: string;
    Hours: Double;
  end;

  TRetirementYearBreakdown = record
    Year: Integer;
    FromDate: TDate;
    ToDate: TDate;
    WorkDays: Integer;
    HolidaysOnWorkDays: Integer;
    VacationDays: Double;
    RemainingDays: Double;
    RemainingHours: Double;
    HolidaysAvailable: Boolean;
  end;

  TRetirementPlan = record
    StartDate: TDate;
    RetirementDate: TDate;
    LastWorkDate: TDate;
    StateName: string;
    AnnualVacation: Double;
    ProratedLastYear: Boolean;
    FullMonthsInExitYear: Integer;
    Years: TArray<TRetirementYearBreakdown>;
    TotalWorkDays: Integer;
    TotalHolidays: Integer;
    TotalVacation: Double;
    TotalRemainingDays: Double;
    TotalRemainingHours: Double;
    MissingHolidayYears: TArray<Integer>;
    Error: string;
  end;

function TimeToMinute(Hour, Minute: Word): Integer; overload;
function TimeToMinute(const ATime: TTime): Integer; overload;
function MinuteToTime(AMinute: Integer): TTime;
function MinuteToText(AMinute: Integer): string;
function TextToMinute(const S: string): Integer;
function SanitizeDayBounds(AStart, AEnd: Integer; ACustom: Boolean = False): TDayBounds;
function IsoDate(const ADate: TDate): string;
function ParseIsoDate(const S: string): TDate;
function DateValid(const ADate: TDate): Boolean;
function IsoWeekDay(const ADate: TDate): Integer;
function IsEveDate(const ADate: TDate): Boolean;
function EveDayName(const ADate: TDate): string;
function FormatHours(AHours: Double; ADecimals: Integer = 2): string;
function FormatHoursAbs(AHours: Double; ADecimals: Integer = 2): string;
function HoursColor(AHours: Double): TColor;
function NewPackageId: string;
function ColorToHex(AColor: TColor): string;
function HexToColor(const S: string): TColor;
function ClampInt(AValue, AMin, AMax: Integer): Integer;
function ClampDouble(AValue, AMin, AMax: Double): Double;

implementation

uses
  System.DateUtils, System.Math, System.StrUtils, Winapi.Windows;

function TimeToMinute(Hour, Minute: Word): Integer;
begin
  Result := Hour * 60 + Minute;
end;

function TimeToMinute(const ATime: TTime): Integer;
var
  H, M, S, MS: Word;
begin
  DecodeTime(ATime, H, M, S, MS);
  Result := H * 60 + M;
end;

function MinuteToTime(AMinute: Integer): TTime;
begin
  AMinute := ClampInt(AMinute, 0, 23 * 60 + 59);
  Result := EncodeTime(AMinute div 60, AMinute mod 60, 0, 0);
end;

function MinuteToText(AMinute: Integer): string;
begin
  AMinute := ClampInt(AMinute, 0, 24 * 60);
  if AMinute >= 24 * 60 then
    Result := '24:00'
  else
    Result := Format('%.2d:%.2d', [AMinute div 60, AMinute mod 60]);
end;

function TextToMinute(const S: string): Integer;
var
  Parts: TArray<string>;
  H, M: Integer;
begin
  Result := 0;
  Parts := S.Trim.Split([':']);
  if Length(Parts) < 2 then
    Exit;
  if not TryStrToInt(Parts[0], H) or not TryStrToInt(Parts[1], M) then
    Exit;
  if (H < 0) or (H > 24) or (M < 0) or (M > 59) then
    Exit;
  Result := H * 60 + M;
end;

function SanitizeDayBounds(AStart, AEnd: Integer; ACustom: Boolean): TDayBounds;
begin
  AStart := ClampInt(AStart, 0, 23 * 60 + 58);
  AEnd := ClampInt(AEnd, AStart + 1, 24 * 60);
  Result.StartMinute := AStart;
  Result.EndMinute := AEnd;
  Result.Custom := ACustom;
end;

function IsoDate(const ADate: TDate): string;
begin
  Result := FormatDateTime('yyyy-mm-dd', ADate);
end;

function ParseIsoDate(const S: string): TDate;
var
  Y, M, D: Integer;
  Parts: TArray<string>;
  DT: TDateTime;
begin
  Result := 0;
  Parts := S.Trim.Split(['-']);
  if Length(Parts) <> 3 then
    Exit;
  if not TryStrToInt(Parts[0], Y) or not TryStrToInt(Parts[1], M) or not TryStrToInt(Parts[2], D) then
    Exit;
  if not TryEncodeDate(Y, M, D, DT) then
    Result := 0
  else
    Result := DT;
end;

function DateValid(const ADate: TDate): Boolean;
begin
  Result := ADate >= EncodeDate(1970, 1, 1);
end;

function IsoWeekDay(const ADate: TDate): Integer;
begin
  Result := DayOfTheWeek(ADate);
end;

function IsEveDate(const ADate: TDate): Boolean;
var
  Y, M, D: Word;
begin
  if not DateValid(ADate) then
    Exit(False);
  DecodeDate(ADate, Y, M, D);
  Result := (M = 12) and ((D = 24) or (D = 31));
end;

function EveDayName(const ADate: TDate): string;
var
  Y, M, D: Word;
begin
  Result := '';
  if not IsEveDate(ADate) then
    Exit;
  DecodeDate(ADate, Y, M, D);
  if D = 24 then
    Result := 'Heiligabend'
  else
    Result := 'Silvester';
end;

function FormatHours(AHours: Double; ADecimals: Integer): string;
var
  Fmt: TFormatSettings;
begin
  Fmt := TFormatSettings.Create('de-DE');
  Result := Format('%.*f', [ADecimals, AHours], Fmt);
end;

function FormatHoursAbs(AHours: Double; ADecimals: Integer): string;
begin
  Result := FormatHours(Abs(AHours), ADecimals);
end;

function HoursColor(AHours: Double): TColor;
begin
  if AHours > 0.005 then
    Result := RGB(0, 128, 0)
  else if AHours < -0.005 then
    Result := RGB(180, 0, 0)
  else
    Result := clWindowText;
end;

function NewPackageId: string;
begin
  Result := TGUID.NewGuid.ToString;
  Result := Result.Trim(['{', '}']);
end;

function ColorToHex(AColor: TColor): string;
var
  C: Longint;
begin
  C := ColorToRGB(AColor);
  Result := Format('#%.2x%.2x%.2x', [GetRValue(C), GetGValue(C), GetBValue(C)]);
end;

function HexToColor(const S: string): TColor;
var
  T: string;
  R, G, B: Integer;
begin
  T := S.Trim;
  if T.StartsWith('#') then
    Delete(T, 1, 1);
  if Length(T) <> 6 then
    Exit(clGray);
  if not TryStrToInt('$' + Copy(T, 1, 2), R)
     or not TryStrToInt('$' + Copy(T, 3, 2), G)
     or not TryStrToInt('$' + Copy(T, 5, 2), B) then
    Exit(clGray);
  Result := RGB(R, G, B);
end;

function ClampInt(AValue, AMin, AMax: Integer): Integer;
begin
  if AValue < AMin then
    Result := AMin
  else if AValue > AMax then
    Result := AMax
  else
    Result := AValue;
end;

function ClampDouble(AValue, AMin, AMax: Double): Double;
begin
  if AValue < AMin then
    Result := AMin
  else if AValue > AMax then
    Result := AMax
  else
    Result := AValue;
end;

function TPauseInterval.IsValid: Boolean;
begin
  Result := EndMinute > StartMinute;
end;

function TWorkPackage.EndMinute(const ADate: TDate): Integer;
var
  NowMin: Integer;
begin
  if Active and SameDate(ADate, Date) then
  begin
    NowMin := TimeToMinute(Time);
    if NowMin > StartMinute then
      Result := NowMin
    else
      Result := StartMinute;
    Exit;
  end;
  if EndMinuteStored < StartMinute then
    Result := StartMinute
  else
    Result := EndMinuteStored;
end;

function TDayBounds.Span: Integer;
begin
  Result := EndMinute - StartMinute;
  if Result < 1 then
    Result := 1;
end;

function TDayBounds.LabelText: string;
begin
  Result := MinuteToText(StartMinute) + EnDash + MinuteToText(EndMinute);
end;

function TAbsence.IsSet: Boolean;
begin
  Result := (AbsenceType <> atNone) and (Fraction > 0.005);
end;

function TAbsence.IsHalfDay: Boolean;
begin
  Result := IsSet and (Fraction < 0.999);
end;

function TAbsence.FillsToTarget: Boolean;
begin
  Result := IsSet and (AbsenceType in [atVacation, atSick, atPaidLeave]);
end;

function TAbsence.LabelText: string;
begin
  Result := '';
  if not IsSet then
    Exit;
  if AbsenceType = atVacation then
  begin
    if IsHalfDay then
      Result := 'Urlaub (' + #$00BD + ')'
    else
      Result := 'Urlaub';
  end
  else if AbsenceType = atSick then
  begin
    if IsHalfDay then
      Result := 'Krankheit (' + #$00BD + ')'
    else
      Result := 'Krankheit';
  end
  else if AbsenceType = atPaidLeave then
  begin
    if IsHalfDay then
      Result := 'Bezahlt frei (' + #$00BD + ')'
    else
      Result := 'Bezahlt frei';
  end
  else if AbsenceType = atCompensatory then
  begin
    if IsHalfDay then
      Result := 'Zeitausgleich (' + #$00BD + ')'
    else
      Result := 'Zeitausgleich';
  end;
end;

function TAbsence.TypeString: string;
begin
  case AbsenceType of
    atVacation: Result := 'vacation';
    atSick: Result := 'sick';
    atPaidLeave: Result := 'paid';
    atCompensatory: Result := 'compensatory';
  else
    Result := '';
  end;
end;

class function TAbsence.FromJson(const AType: string; AFraction: Double): TAbsence;
begin
  Result.AbsenceType := atNone;
  Result.Fraction := 1.0;
  if SameText(AType, 'vacation') then
    Result.AbsenceType := atVacation
  else if SameText(AType, 'sick') then
    Result.AbsenceType := atSick
  else if SameText(AType, 'paid') then
    Result.AbsenceType := atPaidLeave
  else if SameText(AType, 'compensatory') then
    Result.AbsenceType := atCompensatory
  else
    Exit;
  if AFraction >= 0.999 then
    Result.Fraction := 1.0
  else if AFraction > 0.005 then
    Result.Fraction := 0.5
  else
  begin
    Result.AbsenceType := atNone;
    Result.Fraction := 1.0;
  end;
end;

end.
