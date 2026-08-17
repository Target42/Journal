unit Journal.BreakRules;

interface

uses
  Journal.Types;

function ApplyAutomaticBreaks(const Covered: TArray<Boolean>): TBreakAdjustment;

implementation

function RequiredPauseMinutes(CreditedWorkMinutes: Integer): Integer;
begin
  if CreditedWorkMinutes > NineHourThresholdMinutes then
    Result := PauseAfterNineHoursMinutes
  else if CreditedWorkMinutes > SixHourThresholdMinutes then
    Result := PauseAfterSixHoursMinutes
  else
    Result := 0;
end;

function QualifyingPauseMinutes(const Covered: TArray<Boolean>): Integer;
var
  RawWork, GapRun, Pause, I: Integer;

  procedure FlushGap;
  begin
    if (GapRun >= MinQualifyingPauseSegmentMinutes) and
       (RawWork > MinWorkBeforeQualifyingPauseMinutes) then
      Inc(Pause, GapRun);
    GapRun := 0;
  end;

begin
  RawWork := 0;
  GapRun := 0;
  Pause := 0;
  for I := 0 to High(Covered) do
  begin
    if Covered[I] then
    begin
      FlushGap;
      Inc(RawWork);
    end
    else if RawWork > MinWorkBeforeQualifyingPauseMinutes then
      Inc(GapRun);
  end;
  Result := Pause;
end;

function ApplyAutomaticBreaks(const Covered: TArray<Boolean>): TBreakAdjustment;
var
  N, I, Credited, PauseAccrued, Needed: Integer;
begin
  Result := Default(TBreakAdjustment);
  N := Length(Covered);
  SetLength(Result.Credited, N);
  SetLength(Result.AutoPause, N);
  Credited := 0;
  PauseAccrued := QualifyingPauseMinutes(Covered);
  for I := 0 to N - 1 do
  begin
    if not Covered[I] then
      Continue;
    Inc(Result.RawWorkMinutes);
    Needed := RequiredPauseMinutes(Credited + 1);
    if PauseAccrued < Needed then
    begin
      Inc(PauseAccrued);
      Result.AutoPause[I] := True;
    end
    else
    begin
      Inc(Credited);
      Result.Credited[I] := True;
    end;
  end;
  Result.CreditedMinutes := Credited;
  Result.AutoPauseMinutes := Result.RawWorkMinutes - Credited;
end;

end.
