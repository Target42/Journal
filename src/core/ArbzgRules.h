#pragma once

#include "BreakRules.h"

#include <QDate>
#include <QString>
#include <QStringList>
#include <QVector>

inline constexpr int kMinutesPerDay = 24 * 60;
inline constexpr int kNightStartMinute = 23 * 60;
inline constexpr int kNightEndMinute = 6 * 60;
inline constexpr int kNightWorkThresholdMinutes = 2 * 60;
inline constexpr int kMinRestMinutes = 11 * 60;
inline constexpr int kWeekdayMaxMinutes = 8 * 60;
inline constexpr int kWeekdayHardMaxMinutes = 10 * 60;
inline constexpr int kUsualPauseStartDefault = 11 * 60 + 30;
inline constexpr int kUsualPauseEndDefault = 12 * 60;
inline constexpr int kFreeSundaysRequired = 15;
inline constexpr int kSundayErsatzDays = 14;
inline constexpr int kHolidayErsatzWeeks = 8;
inline constexpr int kNightWorkerDaysPerYear = 48;

struct ArbzgDay {
    QDate date;
    bool hasWork = false;
    int firstWorkMinute = -1;
    int lastWorkMinute = -1;
    int rawWorkMinutes = 0;
    int actualPauseMinutes = 0;
    int maxConsecutiveWorkMinutes = 0;
    int nightMinutes = 0;
    int restMinutesBefore = -1;
    bool nightWork = false;
    bool sunday = false;
    bool publicHoliday = false;
    bool sundayOrHolidayWork = false;
    bool sixHoursUninterrupted = false;
    bool requiredPauseMissing = false;
    bool usualPauseMissed = false;
    bool overEightHours = false;
    bool overTenHours = false;
    bool restTooShort = false;
    bool ersatzruheMissing = false;
    QVector<PauseInterval> pauses;
    QStringList issues;
    QStringList notes;

    bool hasIssue() const { return !issues.isEmpty(); }
};

struct ArbzgPeriod {
    QDate from;
    QDate to;
    int weekdayCount = 0;
    double averageWeekdayHours = 0.0;
    bool averageExceeded = false;
};

struct ArbzgSummary {
    int year = 0;
    ArbzgPeriod sixMonths;
    ArbzgPeriod twentyFourWeeks;
    bool compensationFailed = false;
    int daysOverEight = 0;
    int daysOverTen = 0;
    int restViolations = 0;
    int pauseViolations = 0;
    int consecutiveSixHourViolations = 0;
    int sundayWorkDays = 0;
    int holidayWorkDays = 0;
    int freeSundays = 0;
    int sundaysInYear = 0;
    bool tooFewFreeSundays = false;
    int nightWorkDays = 0;
    bool nightWorker = false;
    int ersatzruheMissing = 0;
    int usualPauseHints = 0;
    QVector<ArbzgDay> issueDays;
    QVector<ArbzgDay> noteDays;
};

class ArbzgCompliance
{
public:
    static ArbzgDay assessDay(const QDate &date);
    static ArbzgSummary summarizeYear(int year);
    static QString nachweisHtml(int year, int month);
    static QString formatClock(int minute);
    static QString formatDuration(int minutes);
};
