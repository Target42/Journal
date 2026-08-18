#pragma once

#include "Absence.h"
#include "WorkPackage.h"

#include <QDate>
#include <QList>
#include <QObject>
#include <QString>
#include <QVector>
#include <array>

struct GermanState {
    QString code;
    QString name;
};

enum class WorkTimeMode {
    Even,
    Individual
};

enum class OvertimeLimitPeriod {
    Monthly,
    Quarterly
};

enum class EveDayTreatment {
    Normal,
    FullVacation,
    HalfVacation,
    CompanyFree
};

inline bool isEveDate(const QDate &date)
{
    return date.isValid() && date.month() == 12 && (date.day() == 24 || date.day() == 31);
}

inline QString eveDayName(const QDate &date)
{
    if (!isEveDate(date)) {
        return {};
    }
    return date.day() == 24 ? QStringLiteral("Heiligabend") : QStringLiteral("Silvester");
}

struct OvertimeAccountSettings {
    bool limitsEnabled = true;
    OvertimeLimitPeriod period = OvertimeLimitPeriod::Quarterly;
    double minHours = -20.0;
    double maxHours = 60.0;
};

struct WorkSettings {
    double annualVacationDays = 30.0;
    EveDayTreatment eveDayTreatment = EveDayTreatment::Normal;
    WorkTimeMode workTimeMode = WorkTimeMode::Even;
    double weeklyHours = 40.0;
    std::array<bool, 7> workDays {true, true, true, true, true, false, false};
    std::array<double, 7> hoursPerDay {8.0, 8.0, 8.0, 8.0, 8.0, 0.0, 0.0};
};

class AppSettings : public QObject
{
    Q_OBJECT

public:
    static AppSettings &instance();

    QString dataPath() const;
    void setDataPath(const QString &path);

    QString stateCode() const;
    void setStateCode(const QString &code);
    QString stateDisplayName() const;
    static const QList<GermanState> &germanStates();

    WorkSettings workSettings() const;
    void setWorkSettings(const WorkSettings &settings);

    OvertimeAccountSettings overtimeAccount() const;
    void setOvertimeAccount(const OvertimeAccountSettings &settings);

    QDate retirementDate() const;
    void setRetirementDate(const QDate &date);
    bool prorateVacationInExitYear() const;
    void setProrateVacationInExitYear(bool enabled);

    int dayStartMinute() const;
    int dayEndMinute() const;
    void setDayWindow(int startMinute, int endMinute);

    std::array<PausePreset, kPausePresetCount> pausePresetSlots() const;
    QVector<PausePreset> pausePresets() const;
    void setPausePresetSlots(const std::array<PausePreset, kPausePresetCount> &presetSlots);
    DayBounds usualPauseWindow() const;

    bool isWorkDay(int dayOfWeek) const;
    int workDayCount() const;
    double targetHoursForWeekday(int dayOfWeek) const;
    double targetHoursForDate(const QDate &date) const;
    Absence impliedAbsenceForDate(const QDate &date) const;
    bool isCompanyFreeEveDate(const QDate &date) const;

signals:
    void changed();

private:
    AppSettings();
    void migrateLegacyDataPath();
};
