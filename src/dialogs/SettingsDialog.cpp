#include "SettingsDialog.h"

#include "core/AppSettings.h"
#include "core/ArbzgRules.h"

#include <QCheckBox>
#include <QComboBox>
#include <QDate>
#include <QDialogButtonBox>
#include <QDoubleSpinBox>
#include <QFormLayout>
#include <QGridLayout>
#include <QGroupBox>
#include <QHBoxLayout>
#include <QLabel>
#include <QLineEdit>
#include <QLocale>
#include <QMessageBox>
#include <QPushButton>
#include <QRadioButton>
#include <QSpinBox>
#include <QTabWidget>
#include <QTimeEdit>
#include <QVBoxLayout>
#include <array>

namespace {
void configureHourSpin(QDoubleSpinBox *spin)
{
    spin->setRange(0.0, 24.0);
    spin->setDecimals(2);
    spin->setSingleStep(0.25);
    spin->setSuffix(QStringLiteral(" h"));
    spin->setAlignment(Qt::AlignRight);
}
} // namespace

SettingsDialog::SettingsDialog(QWidget *parent)
    : QDialog(parent)
{
    setWindowTitle(QStringLiteral("Einstellungen"));
    setModal(true);
    setMinimumWidth(640);
    resize(680, 560);
    setupUi();
    loadFromSettings();
}

void SettingsDialog::setupUi()
{
    auto *root = new QVBoxLayout(this);
    root->setSpacing(12);

    const QLocale locale;
    auto *tabs = new QTabWidget(this);
    root->addWidget(tabs, 1);

    auto *workPage = new QWidget(tabs);
    auto *workLayout = new QVBoxLayout(workPage);
    workLayout->setContentsMargins(8, 12, 8, 8);

    auto *stateGroup = new QGroupBox(QStringLiteral("Bundesland"), workPage);
    auto *stateLayout = new QVBoxLayout(stateGroup);
    auto *stateForm = new QFormLayout();
    m_stateCombo = new QComboBox(stateGroup);
    m_stateCombo->setMinimumWidth(280);
    for (const auto &state : AppSettings::germanStates()) {
        m_stateCombo->addItem(QStringLiteral("%1 (%2)").arg(state.name, state.code), state.code);
    }
    stateForm->addRow(QStringLiteral("Arbeitsort:"), m_stateCombo);
    stateLayout->addLayout(stateForm);
    auto *stateHint = new QLabel(
        QStringLiteral("Feiertage und Schulferien richten sich nach diesem Bundesland. "
                       "Nach einem Wechsel bitte unter Datei ggf. neu herunterladen."),
        stateGroup);
    stateHint->setWordWrap(true);
    stateLayout->addWidget(stateHint);
    workLayout->addWidget(stateGroup);

    auto *daysGroup = new QGroupBox(QStringLiteral("Arbeitstage"), workPage);
    auto *daysLayout = new QHBoxLayout(daysGroup);
    daysLayout->setSpacing(12);
    for (int i = 0; i < 7; ++i) {
        m_workDayChecks[i] = new QCheckBox(locale.dayName(i + 1, QLocale::ShortFormat), daysGroup);
        daysLayout->addWidget(m_workDayChecks[i]);
        connect(m_workDayChecks[i], &QCheckBox::toggled, this, [this, i](bool checked) {
            if (m_evenRadio->isChecked()) {
                applyEvenHoursToWorkDays();
            } else if (checked && m_dayHoursSpins[i]->value() <= 0.0) {
                const double fallback = evenHoursPerDay();
                m_dayHoursSpins[i]->setValue(fallback > 0.0 ? fallback : 8.0);
            }
            updateModeUi();
            updateEvenPreview();
        });
    }
    daysLayout->addStretch();
    workLayout->addWidget(daysGroup);

    auto *timeGroup = new QGroupBox(QStringLiteral("Soll-Arbeitszeit"), workPage);
    auto *timeLayout = new QVBoxLayout(timeGroup);

    m_evenRadio = new QRadioButton(QStringLiteral("Gleichmäßige Verteilung"), timeGroup);
    timeLayout->addWidget(m_evenRadio);

    m_evenPane = new QWidget(timeGroup);
    auto *evenLayout = new QVBoxLayout(m_evenPane);
    evenLayout->setContentsMargins(24, 0, 0, 0);
    evenLayout->setSpacing(6);

    auto *weeklyRow = new QHBoxLayout();
    weeklyRow->addWidget(new QLabel(QStringLiteral("Wochenstunden:"), m_evenPane));
    m_weeklyHoursSpin = new QDoubleSpinBox(m_evenPane);
    m_weeklyHoursSpin->setRange(0.0, 80.0);
    m_weeklyHoursSpin->setDecimals(2);
    m_weeklyHoursSpin->setSingleStep(0.5);
    m_weeklyHoursSpin->setSuffix(QStringLiteral(" h"));
    m_weeklyHoursSpin->setAlignment(Qt::AlignRight);
    m_weeklyHoursSpin->setMinimumWidth(120);
    weeklyRow->addWidget(m_weeklyHoursSpin);
    weeklyRow->addStretch();
    evenLayout->addLayout(weeklyRow);

    m_evenPreviewLabel = new QLabel(m_evenPane);
    m_evenPreviewLabel->setWordWrap(true);
    evenLayout->addWidget(m_evenPreviewLabel);
    timeLayout->addWidget(m_evenPane);

    m_individualRadio =
        new QRadioButton(QStringLiteral("Individuelle Arbeitszeit pro Arbeitstag"), timeGroup);
    timeLayout->addWidget(m_individualRadio);

    m_individualPane = new QWidget(timeGroup);
    auto *hoursGrid = new QGridLayout(m_individualPane);
    hoursGrid->setContentsMargins(24, 0, 0, 0);
    hoursGrid->setHorizontalSpacing(8);
    hoursGrid->setVerticalSpacing(4);

    for (int i = 0; i < 7; ++i) {
        auto *dayLabel = new QLabel(locale.dayName(i + 1, QLocale::ShortFormat), m_individualPane);
        dayLabel->setAlignment(Qt::AlignCenter);
        hoursGrid->addWidget(dayLabel, 0, i);

        m_dayHoursSpins[i] = new QDoubleSpinBox(m_individualPane);
        configureHourSpin(m_dayHoursSpins[i]);
        hoursGrid->addWidget(m_dayHoursSpins[i], 1, i);
    }
    timeLayout->addWidget(m_individualPane);
    workLayout->addWidget(timeGroup);
    workLayout->addStretch();
    tabs->addTab(workPage, QStringLiteral("Arbeitszeit"));

    auto *vacationPage = new QWidget(tabs);
    auto *vacationLayout = new QVBoxLayout(vacationPage);
    vacationLayout->setContentsMargins(8, 12, 8, 8);

    auto *vacationGroup = new QGroupBox(QStringLiteral("Jahresurlaub"), vacationPage);
    auto *vacationForm = new QFormLayout(vacationGroup);
    m_vacationSpin = new QDoubleSpinBox(vacationGroup);
    m_vacationSpin->setRange(0.0, 365.0);
    m_vacationSpin->setDecimals(1);
    m_vacationSpin->setSingleStep(0.5);
    m_vacationSpin->setAlignment(Qt::AlignRight);
    m_vacationSpin->setMinimumWidth(100);
    vacationForm->addRow(QStringLiteral("Jahresurlaubstage:"), m_vacationSpin);
    vacationLayout->addWidget(vacationGroup);

    auto *eveGroup = new QGroupBox(QStringLiteral("Heiligabend und Silvester"), vacationPage);
    auto *eveLayout = new QVBoxLayout(eveGroup);
    auto *eveForm = new QFormLayout();
    m_eveCombo = new QComboBox(eveGroup);
    m_eveCombo->setMinimumWidth(320);
    m_eveCombo->addItem(QStringLiteral("Normaler Arbeitstag"),
                        static_cast<int>(EveDayTreatment::Normal));
    m_eveCombo->addItem(QStringLiteral("Jeweils ein Urlaubstag"),
                        static_cast<int>(EveDayTreatment::FullVacation));
    m_eveCombo->addItem(QStringLiteral("Jeweils ein halber Urlaubstag"),
                        static_cast<int>(EveDayTreatment::HalfVacation));
    m_eveCombo->addItem(QStringLiteral("Vollständig frei ohne Arbeitspflicht"),
                        static_cast<int>(EveDayTreatment::CompanyFree));
    eveForm->addRow(QStringLiteral("24.12. und 31.12.:"), m_eveCombo);
    eveLayout->addLayout(eveForm);
    auto *eveHint = new QLabel(
        QStringLiteral("Gilt nur, wenn der Tag ein Arbeitstag und kein gesetzlicher Feiertag ist. "
                       "Weihnachten (25./26.12.) bleibt Feiertag. Eine manuell gesetzte "
                       "Abwesenheit an diesem Tag hat Vorrang."),
        eveGroup);
    eveHint->setWordWrap(true);
    eveLayout->addWidget(eveHint);
    vacationLayout->addWidget(eveGroup);
    vacationLayout->addStretch();
    tabs->addTab(vacationPage, QStringLiteral("Urlaub"));

    auto *overtimePage = new QWidget(tabs);
    auto *overtimePageLayout = new QVBoxLayout(overtimePage);
    overtimePageLayout->setContentsMargins(8, 12, 8, 8);

    auto *overtimeGroup = new QGroupBox(QStringLiteral("Überstundenkonto"), overtimePage);
    auto *overtimeLayout = new QVBoxLayout(overtimeGroup);
    m_overtimeLimitsCheck =
        new QCheckBox(QStringLiteral("Saldo zum Periodenende auf Grenzen kappen"), overtimeGroup);
    overtimeLayout->addWidget(m_overtimeLimitsCheck);

    m_overtimeLimitsPane = new QWidget(overtimeGroup);
    auto *overtimeForm = new QFormLayout(m_overtimeLimitsPane);
    overtimeForm->setContentsMargins(24, 0, 0, 0);

    m_overtimePeriodCombo = new QComboBox(m_overtimeLimitsPane);
    m_overtimePeriodCombo->addItem(QStringLiteral("Monatlich"),
                                   static_cast<int>(OvertimeLimitPeriod::Monthly));
    m_overtimePeriodCombo->addItem(QStringLiteral("Quartalsweise"),
                                   static_cast<int>(OvertimeLimitPeriod::Quarterly));
    overtimeForm->addRow(QStringLiteral("Geltung:"), m_overtimePeriodCombo);

    auto configureLimitSpin = [](QDoubleSpinBox *spin) {
        spin->setRange(-500.0, 500.0);
        spin->setDecimals(2);
        spin->setSingleStep(1.0);
        spin->setSuffix(QStringLiteral(" h"));
        spin->setAlignment(Qt::AlignRight);
        spin->setMinimumWidth(120);
    };

    m_overtimeMinSpin = new QDoubleSpinBox(m_overtimeLimitsPane);
    configureLimitSpin(m_overtimeMinSpin);
    overtimeForm->addRow(QStringLiteral("Untergrenze:"), m_overtimeMinSpin);

    m_overtimeMaxSpin = new QDoubleSpinBox(m_overtimeLimitsPane);
    configureLimitSpin(m_overtimeMaxSpin);
    overtimeForm->addRow(QStringLiteral("Obergrenze:"), m_overtimeMaxSpin);
    overtimeLayout->addWidget(m_overtimeLimitsPane);

    auto *overtimeHint = new QLabel(
        QStringLiteral("Zum Periodenende wird der Kontostand auf diese Grenzen gekürzt. "
                       "Der Rest wird abgeschnitten und nicht in die nächste Periode "
                       "übernommen. Innerhalb der laufenden Periode darf der Saldo "
                       "die Grenzen überschreiten. Vorgabe: −20 / +60 Stunden, quartalsweise."),
        overtimeGroup);
    overtimeHint->setWordWrap(true);
    overtimeLayout->addWidget(overtimeHint);
    overtimePageLayout->addWidget(overtimeGroup);

    auto *openingGroup = new QGroupBox(QStringLiteral("Anfangssaldo"), overtimePage);
    auto *openingLayout = new QVBoxLayout(openingGroup);
    m_openingCheck = new QCheckBox(
        QStringLiteral("Konto ab diesem Monat mit festem Übertrag starten"), openingGroup);
    openingLayout->addWidget(m_openingCheck);
    m_openingPane = new QWidget(openingGroup);
    auto *openingForm = new QFormLayout(m_openingPane);
    openingForm->setContentsMargins(24, 0, 0, 0);
    auto *openingFromRow = new QHBoxLayout();
    m_openingMonthCombo = new QComboBox(m_openingPane);
    for (int month = 1; month <= 12; ++month) {
        m_openingMonthCombo->addItem(locale.monthName(month), month);
    }
    m_openingYearSpin = new QSpinBox(m_openingPane);
    m_openingYearSpin->setRange(1970, 2100);
    m_openingYearSpin->setValue(QDate::currentDate().year());
    openingFromRow->addWidget(m_openingMonthCombo);
    openingFromRow->addWidget(m_openingYearSpin);
    openingForm->addRow(QStringLiteral("Ab Monat:"), openingFromRow);
    m_openingHoursSpin = new QDoubleSpinBox(m_openingPane);
    m_openingHoursSpin->setRange(-500.0, 500.0);
    m_openingHoursSpin->setDecimals(2);
    m_openingHoursSpin->setSingleStep(0.25);
    m_openingHoursSpin->setSuffix(QStringLiteral(" h"));
    m_openingHoursSpin->setAlignment(Qt::AlignRight);
    openingForm->addRow(QStringLiteral("Stundenkonto:"), m_openingHoursSpin);
    openingLayout->addWidget(m_openingPane);
    auto *openingHint = new QLabel(
        QStringLiteral("Ersetzt den errechneten Vormonats-Saldo, z. B. nach einem offiziellen "
                       "Übertrag der Zeitabrechnung."),
        openingGroup);
    openingHint->setWordWrap(true);
    openingLayout->addWidget(openingHint);
    overtimePageLayout->addWidget(openingGroup);
    overtimePageLayout->addStretch();
    tabs->addTab(overtimePage, QStringLiteral("Konto"));

    auto *dayPage = new QWidget(tabs);
    auto *dayLayout = new QVBoxLayout(dayPage);
    dayLayout->setContentsMargins(8, 12, 8, 8);

    auto *boundsGroup = new QGroupBox(QStringLiteral("Tagesgrenzen"), dayPage);
    auto *boundsLayout = new QVBoxLayout(boundsGroup);
    auto *boundsRow = new QHBoxLayout();
    boundsRow->addWidget(new QLabel(QStringLiteral("Von:"), boundsGroup));
    m_dayStartEdit = new QTimeEdit(boundsGroup);
    m_dayStartEdit->setDisplayFormat(QStringLiteral("HH:mm"));
    m_dayStartEdit->setWrapping(false);
    boundsRow->addWidget(m_dayStartEdit);
    boundsRow->addSpacing(16);
    boundsRow->addWidget(new QLabel(QStringLiteral("Bis:"), boundsGroup));
    m_dayEndEdit = new QTimeEdit(boundsGroup);
    m_dayEndEdit->setDisplayFormat(QStringLiteral("HH:mm"));
    m_dayEndEdit->setWrapping(false);
    boundsRow->addWidget(m_dayEndEdit);
    boundsRow->addStretch();
    boundsLayout->addLayout(boundsRow);
    auto *boundsHint = new QLabel(
        QStringLiteral("Nur Zeiten innerhalb dieser Grenzen zählen für Ist und Saldo. "
                       "Die Erfassung bleibt vollständig. Einzelne Tage können abweichend "
                       "gesetzt werden."),
        boundsGroup);
    boundsHint->setWordWrap(true);
    boundsLayout->addWidget(boundsHint);
    dayLayout->addWidget(boundsGroup);

    auto *pauseGroup = new QGroupBox(QStringLiteral("Pausen"), dayPage);
    auto *pauseLayout = new QVBoxLayout(pauseGroup);
    auto *pauseGrid = new QGridLayout();
    pauseGrid->setHorizontalSpacing(8);
    pauseGrid->setVerticalSpacing(6);
    pauseGrid->addWidget(new QLabel(QStringLiteral("Name"), pauseGroup), 0, 1);
    pauseGrid->addWidget(new QLabel(QStringLiteral("Von"), pauseGroup), 0, 2);
    pauseGrid->addWidget(new QLabel(QStringLiteral("Bis"), pauseGroup), 0, 3);

    for (int i = 0; i < kPausePresetCount; ++i) {
        pauseGrid->addWidget(new QLabel(QStringLiteral("%1.").arg(i + 1), pauseGroup), i + 1, 0);
        m_pauseNameEdits[i] = new QLineEdit(pauseGroup);
        m_pauseNameEdits[i]->setPlaceholderText(QStringLiteral("z. B. Frühstück"));
        m_pauseNameEdits[i]->setMaxLength(24);
        m_pauseNameEdits[i]->setMinimumWidth(140);
        pauseGrid->addWidget(m_pauseNameEdits[i], i + 1, 1);
        m_pauseStartEdits[i] = new QTimeEdit(pauseGroup);
        m_pauseStartEdits[i]->setDisplayFormat(QStringLiteral("HH:mm"));
        m_pauseStartEdits[i]->setWrapping(false);
        pauseGrid->addWidget(m_pauseStartEdits[i], i + 1, 2);
        m_pauseEndEdits[i] = new QTimeEdit(pauseGroup);
        m_pauseEndEdits[i]->setDisplayFormat(QStringLiteral("HH:mm"));
        m_pauseEndEdits[i]->setWrapping(false);
        pauseGrid->addWidget(m_pauseEndEdits[i], i + 1, 3);
    }
    pauseLayout->addLayout(pauseGrid);
    auto *pauseHint = new QLabel(
        QStringLiteral("Bis zu drei Vorlagen. In der Tagesübersicht kannst du sie per Häkchen "
                       "einfügen oder wieder entfernen. Leerer Name = ungenutzt. "
                       "Journal markiert die Fenster und weist hin, wenn du um diese Zeit "
                       "noch durcharbeitest. Gesetzlich zählt eine Pause von mindestens "
                       "15 Minuten vor mehr als 6 Stunden ununterbrochener Arbeit."),
        pauseGroup);
    pauseHint->setWordWrap(true);
    pauseLayout->addWidget(pauseHint);
    dayLayout->addWidget(pauseGroup);
    dayLayout->addStretch();
    tabs->addTab(dayPage, QStringLiteral("Tag"));

    auto *buttons = new QDialogButtonBox(QDialogButtonBox::Ok | QDialogButtonBox::Cancel, this);
    if (auto *ok = buttons->button(QDialogButtonBox::Ok)) {
        ok->setAutoDefault(false);
        ok->setDefault(false);
    }
    if (auto *cancel = buttons->button(QDialogButtonBox::Cancel)) {
        cancel->setText(QStringLiteral("Abbrechen"));
        cancel->setAutoDefault(false);
    }
    root->addWidget(buttons);

    connect(m_evenRadio, &QRadioButton::toggled, this, [this](bool checked) {
        if (checked) {
            applyEvenHoursToWorkDays();
            updateModeUi();
        }
    });
    connect(m_individualRadio, &QRadioButton::toggled, this, [this](bool checked) {
        if (!checked) {
            return;
        }
        const double even = evenHoursPerDay();
        if (even > 0.0) {
            bool allZero = true;
            for (int i = 0; i < 7; ++i) {
                if (m_workDayChecks[i]->isChecked() && m_dayHoursSpins[i]->value() > 0.0) {
                    allZero = false;
                    break;
                }
            }
            if (allZero) {
                for (int i = 0; i < 7; ++i) {
                    if (m_workDayChecks[i]->isChecked()) {
                        m_dayHoursSpins[i]->setValue(even);
                    }
                }
            }
        }
        updateModeUi();
    });
    connect(m_weeklyHoursSpin, &QDoubleSpinBox::valueChanged,
            this, &SettingsDialog::updateEvenPreview);
    connect(m_weeklyHoursSpin, &QDoubleSpinBox::editingFinished,
            this, &SettingsDialog::applyEvenHoursToWorkDays);
    connect(m_overtimeLimitsCheck, &QCheckBox::toggled,
            this, &SettingsDialog::updateOvertimeUi);
    connect(m_openingCheck, &QCheckBox::toggled,
            this, &SettingsDialog::updateOvertimeUi);
    connect(buttons, &QDialogButtonBox::accepted, this, &QDialog::accept);
    connect(buttons, &QDialogButtonBox::rejected, this, &QDialog::reject);
}

void SettingsDialog::loadFromSettings()
{
    const WorkSettings ws = AppSettings::instance().workSettings();

    const QString stateCode = AppSettings::instance().stateCode();
    const int stateIndex = m_stateCombo->findData(stateCode);
    if (stateIndex >= 0) {
        m_stateCombo->setCurrentIndex(stateIndex);
    } else {
        m_stateCombo->setCurrentIndex(m_stateCombo->findData(QStringLiteral("NI")));
    }

    m_vacationSpin->setValue(ws.annualVacationDays);
    const int eveIndex = m_eveCombo->findData(static_cast<int>(ws.eveDayTreatment));
    m_eveCombo->setCurrentIndex(eveIndex >= 0 ? eveIndex : 0);
    m_weeklyHoursSpin->setValue(ws.weeklyHours);

    for (int i = 0; i < 7; ++i) {
        QSignalBlocker blocker(m_workDayChecks[i]);
        m_workDayChecks[i]->setChecked(ws.workDays[i]);
        m_dayHoursSpins[i]->setValue(ws.hoursPerDay[i]);
    }

    if (ws.workTimeMode == WorkTimeMode::Individual) {
        m_individualRadio->setChecked(true);
    } else {
        m_evenRadio->setChecked(true);
    }

    updateModeUi();
    updateEvenPreview();
    if (m_evenRadio->isChecked()) {
        applyEvenHoursToWorkDays();
    }

    auto &settings = AppSettings::instance();
    m_dayStartEdit->setTime(minuteToTime(settings.dayStartMinute()));
    m_dayEndEdit->setTime(minuteToTime(settings.dayEndMinute()));

    const auto pauseSlots = settings.pausePresetSlots();
    for (int i = 0; i < kPausePresetCount; ++i) {
        m_pauseNameEdits[i]->setText(pauseSlots[i].name);
        const int start = pauseSlots[i].isValid() ? pauseSlots[i].startMinute
                                                  : (i == 0 ? kDefaultBreakfastStartMinute
                                                            : (i == 1 ? kUsualPauseStartDefault : 12 * 60));
        const int end = pauseSlots[i].isValid() ? pauseSlots[i].endMinute
                                                : (i == 0 ? kDefaultBreakfastEndMinute
                                                          : (i == 1 ? kUsualPauseEndDefault : 12 * 60 + 15));
        m_pauseStartEdits[i]->setTime(minuteToTime(start));
        m_pauseEndEdits[i]->setTime(minuteToTime(end));
    }

    const OvertimeAccountSettings overtime = settings.overtimeAccount();
    m_overtimeLimitsCheck->setChecked(overtime.limitsEnabled);
    const int periodIndex =
        m_overtimePeriodCombo->findData(static_cast<int>(overtime.period));
    m_overtimePeriodCombo->setCurrentIndex(periodIndex >= 0 ? periodIndex : 1);
    m_overtimeMinSpin->setValue(overtime.minHours);
    m_overtimeMaxSpin->setValue(overtime.maxHours);
    m_openingCheck->setChecked(overtime.openingEnabled);
    const int openingMonth = (overtime.openingMonth >= 1 && overtime.openingMonth <= 12)
                                 ? overtime.openingMonth
                                 : 1;
    m_openingMonthCombo->setCurrentIndex(openingMonth - 1);
    m_openingYearSpin->setValue(overtime.openingYear >= 1970 ? overtime.openingYear
                                                             : QDate::currentDate().year());
    m_openingHoursSpin->setValue(overtime.openingHours);
    updateOvertimeUi();
}

void SettingsDialog::saveToSettings()
{
    WorkSettings ws;
    ws.annualVacationDays = m_vacationSpin->value();
    ws.eveDayTreatment = static_cast<EveDayTreatment>(m_eveCombo->currentData().toInt());
    ws.workTimeMode = m_individualRadio->isChecked() ? WorkTimeMode::Individual
                                                     : WorkTimeMode::Even;
    ws.weeklyHours = m_weeklyHoursSpin->value();

    for (int i = 0; i < 7; ++i) {
        ws.workDays[i] = m_workDayChecks[i]->isChecked();
        ws.hoursPerDay[i] = m_dayHoursSpins[i]->value();
    }

    AppSettings::instance().setWorkSettings(ws);
    AppSettings::instance().setDayWindow(timeToMinute(m_dayStartEdit->time()),
                                         timeToMinute(m_dayEndEdit->time()));
    std::array<PausePreset, kPausePresetCount> pauseSlots {};
    for (int i = 0; i < kPausePresetCount; ++i) {
        pauseSlots[i].name = m_pauseNameEdits[i]->text().trimmed();
        pauseSlots[i].startMinute = timeToMinute(m_pauseStartEdits[i]->time());
        pauseSlots[i].endMinute = timeToMinute(m_pauseEndEdits[i]->time());
    }
    AppSettings::instance().setPausePresetSlots(pauseSlots);
    AppSettings::instance().setStateCode(m_stateCombo->currentData().toString());

    OvertimeAccountSettings overtime;
    overtime.limitsEnabled = m_overtimeLimitsCheck->isChecked();
    overtime.period = static_cast<OvertimeLimitPeriod>(
        m_overtimePeriodCombo->currentData().toInt());
    overtime.minHours = m_overtimeMinSpin->value();
    overtime.maxHours = m_overtimeMaxSpin->value();
    overtime.openingEnabled = m_openingCheck->isChecked();
    overtime.openingMonth = m_openingMonthCombo->currentData().toInt();
    overtime.openingYear = m_openingYearSpin->value();
    overtime.openingHours = m_openingHoursSpin->value();
    AppSettings::instance().setOvertimeAccount(overtime);
}

void SettingsDialog::updateModeUi()
{
    const bool even = m_evenRadio->isChecked();
    m_evenPane->setEnabled(even);

    for (int i = 0; i < 7; ++i) {
        const bool workDay = m_workDayChecks[i]->isChecked();
        m_dayHoursSpins[i]->setEnabled(workDay);
        m_dayHoursSpins[i]->setReadOnly(even);
    }
}

void SettingsDialog::applyEvenHoursToWorkDays()
{
    if (!m_evenRadio->isChecked()) {
        return;
    }

    const double hours = evenHoursPerDay();
    for (int i = 0; i < 7; ++i) {
        m_dayHoursSpins[i]->setValue(m_workDayChecks[i]->isChecked() ? hours : 0.0);
    }
}

void SettingsDialog::updateEvenPreview()
{
    const int count = selectedWorkDayCount();
    if (count == 0) {
        m_evenPreviewLabel->setText(
            QStringLiteral("Bitte mindestens einen Arbeitstag auswählen."));
        return;
    }

    const QLocale locale;
    m_evenPreviewLabel->setText(
        QStringLiteral("Entspricht %1 h je Arbeitstag (%2 Arbeitstage).")
            .arg(locale.toString(evenHoursPerDay(), 'f', 2),
                 locale.toString(count)));
}

void SettingsDialog::updateOvertimeUi()
{
    m_overtimeLimitsPane->setEnabled(m_overtimeLimitsCheck->isChecked());
    m_openingPane->setEnabled(m_openingCheck->isChecked());
}

int SettingsDialog::selectedWorkDayCount() const
{
    int count = 0;
    for (const auto *check : m_workDayChecks) {
        if (check->isChecked()) {
            ++count;
        }
    }
    return count;
}

double SettingsDialog::evenHoursPerDay() const
{
    const int count = selectedWorkDayCount();
    if (count <= 0) {
        return 0.0;
    }
    return m_weeklyHoursSpin->value() / static_cast<double>(count);
}

void SettingsDialog::accept()
{
    if (selectedWorkDayCount() == 0) {
        QMessageBox::warning(
            this,
            QStringLiteral("Einstellungen"),
            QStringLiteral("Bitte mindestens einen Arbeitstag auswählen."));
        return;
    }

    if (timeToMinute(m_dayStartEdit->time()) >= timeToMinute(m_dayEndEdit->time())) {
        QMessageBox::warning(
            this,
            QStringLiteral("Einstellungen"),
            QStringLiteral("Die Tagesgrenze „Von“ muss vor „Bis“ liegen."));
        return;
    }

    if (m_overtimeLimitsCheck->isChecked()
        && m_overtimeMinSpin->value() > m_overtimeMaxSpin->value()) {
        QMessageBox::warning(
            this,
            QStringLiteral("Einstellungen"),
            QStringLiteral("Die Untergrenze des Überstundenkontos muss kleiner oder gleich "
                           "der Obergrenze sein."));
        return;
    }

    std::array<PausePreset, kPausePresetCount> pauseSlots {};
    for (int i = 0; i < kPausePresetCount; ++i) {
        pauseSlots[i].name = m_pauseNameEdits[i]->text().trimmed();
        pauseSlots[i].startMinute = timeToMinute(m_pauseStartEdits[i]->time());
        pauseSlots[i].endMinute = timeToMinute(m_pauseEndEdits[i]->time());
        if (pauseSlots[i].name.isEmpty()) {
            continue;
        }
        if (pauseSlots[i].endMinute <= pauseSlots[i].startMinute) {
            QMessageBox::warning(
                this,
                QStringLiteral("Einstellungen"),
                QStringLiteral("Bei Pause „%1“ muss „Von“ vor „Bis“ liegen.")
                    .arg(pauseSlots[i].name));
            return;
        }
    }
    for (int i = 0; i < kPausePresetCount; ++i) {
        if (!pauseSlots[i].isValid()) {
            continue;
        }
        for (int j = i + 1; j < kPausePresetCount; ++j) {
            if (!pauseSlots[j].isValid()) {
                continue;
            }
            if (pauseSlots[i].startMinute < pauseSlots[j].endMinute
                && pauseSlots[j].startMinute < pauseSlots[i].endMinute) {
                QMessageBox::warning(
                    this,
                    QStringLiteral("Einstellungen"),
                    QStringLiteral("Die Pausen „%1“ und „%2“ überlappen sich.")
                        .arg(pauseSlots[i].label(), pauseSlots[j].label()));
                return;
            }
        }
    }

    saveToSettings();
    QDialog::accept();
}
