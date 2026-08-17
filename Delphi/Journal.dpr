program Journal;

uses
  Vcl.Forms,
  System.SysUtils,
  MainForm in 'src\Forms\MainForm.pas' {MainForm},
  YearSelectForm in 'src\Forms\YearSelectForm.pas' {YearSelectForm},
  AbsenceForm in 'src\Forms\AbsenceForm.pas' {AbsenceForm},
  DayBoundsForm in 'src\Forms\DayBoundsForm.pas' {DayBoundsForm},
  WorkPackageForm in 'src\Forms\WorkPackageForm.pas' {WorkPackageForm},
  PauseForm in 'src\Forms\PauseForm.pas' {PauseForm},
  DayPackagesForm in 'src\Forms\DayPackagesForm.pas' {DayPackagesForm},
  TitlesForm in 'src\Forms\TitlesForm.pas' {TitlesForm},
  SettingsForm in 'src\Forms\SettingsForm.pas' {SettingsForm},
  RetirementForm in 'src\Forms\RetirementForm.pas' {RetirementForm},
  ArbzgForm in 'src\Forms\ArbzgForm.pas' {ArbzgForm},
  MonthViewFrame in 'src\Views\MonthViewFrame.pas' {MonthViewFrame: TFrame},
  YearViewFrame in 'src\Views\YearViewFrame.pas' {YearViewFrame: TFrame},
  DayViewFrame in 'src\Views\DayViewFrame.pas' {DayViewFrame: TFrame},
  PackageChartFrame in 'src\Views\PackageChartFrame.pas' {PackageChartFrame: TFrame},
  AccountTrendFrame in 'src\Views\AccountTrendFrame.pas' {AccountTrendFrame: TFrame},
  Journal.Types in 'src\Core\Journal.Types.pas',
  Journal.JsonUtil in 'src\Core\Journal.JsonUtil.pas',
  Journal.Events in 'src\Core\Journal.Events.pas',
  Journal.Settings in 'src\Core\Journal.Settings.pas',
  Journal.BreakRules in 'src\Core\Journal.BreakRules.pas',
  Journal.TitleCatalog in 'src\Core\Journal.TitleCatalog.pas',
  Journal.Store in 'src\Core\Journal.Store.pas',
  Journal.Calendar in 'src\Core\Journal.Calendar.pas',
  Journal.TimeTotals in 'src\Core\Journal.TimeTotals.pas',
  Journal.Retirement in 'src\Core\Journal.Retirement.pas',
  Journal.Arbzg in 'src\Core\Journal.Arbzg.pas',
  Journal.UiUtil in 'src\Core\Journal.UiUtil.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'Journal';
  FormatSettings := TFormatSettings.Create('de-DE');
  Application.CreateForm(TMainForm, frmMain);
  Application.Run;
end.
