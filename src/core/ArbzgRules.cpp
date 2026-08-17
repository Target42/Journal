#include "ArbzgRules.h"

#include "AppSettings.h"
#include "BreakRules.h"
#include "CalendarService.h"
#include "JournalStore.h"
#include "WorkPackage.h"

#include <QDateTime>
#include <QLocale>
#include <algorithm>

namespace {
int requiredPauseMinutes(int workMinutes)
{
    if (workMinutes > kNineHourThresholdMinutes) {
        return kPauseAfterNineHoursMinutes;
    }
    if (workMinutes > kSixHourThresholdMinutes) {
        return kPauseAfterSixHoursMinutes;
    }
    return 0;
}

int firstCovered(const QVector<char> &covered)
{
    for (int i = 0; i < covered.size(); ++i) {
        if (covered[i]) {
            return i;
        }
    }
    return -1;
}

int lastCoveredEnd(const QVector<char> &covered)
{
    for (int i = covered.size() - 1; i >= 0; --i) {
        if (covered[i]) {
            return i + 1;
        }
    }
    return -1;
}

int nightMinutesIn(const QVector<char> &covered)
{
    int minutes = 0;
    for (int i = 0; i < covered.size(); ++i) {
        if (!covered[i]) {
            continue;
        }
        if (i >= kNightStartMinute || i < kNightEndMinute) {
            ++minutes;
        }
    }
    return minutes;
}

QVector<PauseInterval> qualifyingPauses(const QVector<char> &covered)
{
    QVector<PauseInterval> pauses;
    int rawWork = 0;
    int gapStart = -1;
    int gapRun = 0;

    auto flush = [&]() {
        if (gapRun >= kMinQualifyingPauseSegmentMinutes
            && rawWork > kMinWorkBeforeQualifyingPauseMinutes) {
            pauses.append({gapStart, gapStart + gapRun});
        }
        gapStart = -1;
        gapRun = 0;
    };

    for (int i = 0; i < covered.size(); ++i) {
        if (covered[i]) {
            flush();
            ++rawWork;
        } else if (rawWork > kMinWorkBeforeQualifyingPauseMinutes) {
            if (gapRun == 0) {
                gapStart = i;
            }
            ++gapRun;
        }
    }
    return pauses;
}

int maxConsecutive(const QVector<char> &covered)
{
    int best = 0;
    int run = 0;
    for (char flag : covered) {
        if (flag) {
            ++run;
            best = qMax(best, run);
        } else {
            run = 0;
        }
    }
    return best;
}

int countCovered(const QVector<char> &covered)
{
    int n = 0;
    for (char flag : covered) {
        if (flag) {
            ++n;
        }
    }
    return n;
}

bool isWeekday(const QDate &date)
{
    return date.dayOfWeek() >= 1 && date.dayOfWeek() <= 6;
}

int restMinutesBefore(const QDate &date, int firstWorkMinute)
{
    if (firstWorkMinute < 0) {
        return -1;
    }

    QDate cursor = date.addDays(-1);
    int skippedDays = 0;
    for (int i = 0; i < 14; ++i) {
        const QVector<char> prev = JournalStore::instance().fullDayCoverage(cursor);
        const int prevEnd = lastCoveredEnd(prev);
        if (prevEnd >= 0) {
            return (kMinutesPerDay - prevEnd) + skippedDays * kMinutesPerDay + firstWorkMinute;
        }
        ++skippedDays;
        cursor = cursor.addDays(-1);
    }
    return -1;
}

bool dayHasWork(const QDate &date)
{
    return countCovered(JournalStore::instance().fullDayCoverage(date)) > 0;
}

bool hasErsatzruhe(const QDate &workDate, int maxDays)
{
    const QDate today = QDate::currentDate();
    const QDate deadline = workDate.addDays(maxDays);
    for (QDate d = workDate.addDays(1); d.isValid() && d <= deadline; d = d.addDays(1)) {
        if (!isWeekday(d)) {
            continue;
        }
        if (!dayHasWork(d)) {
            return true;
        }
    }
    return deadline > today;
}

ArbzgPeriod averagePeriod(const QDate &from, const QDate &to)
{
    ArbzgPeriod period;
    period.from = from;
    period.to = to;
    int weekdayMinutes = 0;
    for (QDate d = from; d.isValid() && d <= to; d = d.addDays(1)) {
        if (!isWeekday(d)) {
            continue;
        }
        ++period.weekdayCount;
        weekdayMinutes += countCovered(JournalStore::instance().fullDayCoverage(d));
    }
    period.averageWeekdayHours =
        period.weekdayCount > 0 ? weekdayMinutes / 60.0 / period.weekdayCount : 0.0;
    period.averageExceeded = period.averageWeekdayHours > 8.0001;
    return period;
}
} // namespace

QString ArbzgCompliance::formatClock(int minute)
{
    if (minute < 0) {
        return QStringLiteral("–");
    }
    if (minute >= kMinutesPerDay) {
        return QStringLiteral("24:00");
    }
    return minuteToTime(minute).toString(QStringLiteral("HH:mm"));
}

QString ArbzgCompliance::formatDuration(int minutes)
{
    if (minutes < 0) {
        return QStringLiteral("–");
    }
    return QLocale().toString(minutes / 60.0, 'f', 2) + QStringLiteral(" h");
}

ArbzgDay ArbzgCompliance::assessDay(const QDate &date)
{
    ArbzgDay day;
    day.date = date;
    if (!date.isValid() || date > QDate::currentDate()) {
        return day;
    }

    const QVector<char> covered = JournalStore::instance().fullDayCoverage(date);
    day.rawWorkMinutes = countCovered(covered);
    day.hasWork = day.rawWorkMinutes > 0;
    day.firstWorkMinute = firstCovered(covered);
    day.lastWorkMinute = lastCoveredEnd(covered);
    day.pauses = qualifyingPauses(covered);
    for (const auto &pause : day.pauses) {
        day.actualPauseMinutes += pause.endMinute - pause.startMinute;
    }
    day.maxConsecutiveWorkMinutes = maxConsecutive(covered);
    day.nightMinutes = nightMinutesIn(covered);
    day.nightWork = day.nightMinutes > kNightWorkThresholdMinutes;
    day.sunday = date.dayOfWeek() == 7;
    day.publicHoliday = CalendarService::instance().isPublicHoliday(date);
    day.sundayOrHolidayWork = day.hasWork && (day.sunday || day.publicHoliday);
    day.sixHoursUninterrupted = day.maxConsecutiveWorkMinutes > kSixHourThresholdMinutes;
    day.overEightHours = day.rawWorkMinutes > kWeekdayMaxMinutes;
    day.overTenHours = day.rawWorkMinutes > kWeekdayHardMaxMinutes;

    const int needed = requiredPauseMinutes(day.rawWorkMinutes);
    day.requiredPauseMissing = needed > 0 && day.actualPauseMinutes < needed;

    const QVector<char> &coveredRef = covered;
    for (const auto &preset : AppSettings::instance().pausePresets()) {
        if (day.firstWorkMinute < 0 || day.firstWorkMinute >= preset.startMinute
            || preset.startMinute < 0 || preset.startMinute >= coveredRef.size()
            || !coveredRef[preset.startMinute]) {
            continue;
        }
        bool startedInWindow = false;
        for (const auto &pause : day.pauses) {
            if ((pause.startMinute >= preset.startMinute && pause.startMinute <= preset.endMinute)
                || (pause.startMinute <= preset.startMinute
                    && pause.endMinute >= preset.endMinute)) {
                startedInWindow = true;
                break;
            }
        }
        if (!startedInWindow) {
            day.usualPauseMissed = true;
            day.notes << QStringLiteral("Keine Pause im Fenster %1 %2–%3")
                             .arg(preset.label(),
                                  formatClock(preset.startMinute),
                                  formatClock(preset.endMinute));
        }
    }

    if (day.hasWork) {
        day.restMinutesBefore = restMinutesBefore(date, day.firstWorkMinute);
        day.restTooShort =
            day.restMinutesBefore >= 0 && day.restMinutesBefore < kMinRestMinutes;
    }

    if (day.requiredPauseMissing) {
        day.issues << QStringLiteral("Pause zu kurz (§4): %1 statt %2")
                          .arg(formatDuration(day.actualPauseMinutes),
                               formatDuration(needed));
    }
    if (day.sixHoursUninterrupted) {
        day.issues << QStringLiteral("Mehr als 6 h ohne Unterbrechung (§4)");
    }
    if (day.overTenHours) {
        day.issues << QStringLiteral("Mehr als 10 h Arbeitszeit (§3)");
    } else if (day.overEightHours) {
        day.notes << QStringLiteral("Mehr als 8 h (§3, Ausgleich nötig)");
    }
    if (day.restTooShort) {
        day.issues << QStringLiteral("Ruhezeit unter 11 h (§5): %1")
                          .arg(formatDuration(day.restMinutesBefore));
    }
    if (day.sundayOrHolidayWork) {
        const QString kind = day.sunday ? QStringLiteral("Sonntag")
                                        : CalendarService::instance().publicHolidayName(date);
        day.issues << QStringLiteral("Arbeit am %1 (§9)").arg(kind);
    }
    if (day.nightWork) {
        day.notes << QStringLiteral("Nachtarbeit %1 (§6)")
                         .arg(formatDuration(day.nightMinutes));
    }

    return day;
}

ArbzgSummary ArbzgCompliance::summarizeYear(int year)
{
    ArbzgSummary summary;
    summary.year = year;

    const QDate today = QDate::currentDate();
    const QDate sixMonthsFrom = QDate(today.year(), today.month(), 1).addMonths(-5);
    summary.sixMonths = averagePeriod(sixMonthsFrom, today);
    summary.twentyFourWeeks = averagePeriod(today.addDays(-24 * 7 + 1), today);
    summary.compensationFailed =
        summary.sixMonths.averageExceeded && summary.twentyFourWeeks.averageExceeded;

    const QDate yearStart(year, 1, 1);
    const QDate yearEnd(year, 12, 31);
    CalendarService::instance().ensureYearLoaded(year);

    for (QDate d = yearStart; d.isValid() && d <= yearEnd; d = d.addDays(1)) {
        if (d.dayOfWeek() == 7) {
            ++summary.sundaysInYear;
            if (d > today || !dayHasWork(d)) {
                ++summary.freeSundays;
            }
        }

        if (d > today) {
            continue;
        }

        ArbzgDay day = assessDay(d);
        if (day.overEightHours) {
            ++summary.daysOverEight;
        }
        if (day.overTenHours) {
            ++summary.daysOverTen;
        }
        if (day.restTooShort) {
            ++summary.restViolations;
        }
        if (day.requiredPauseMissing || day.sixHoursUninterrupted) {
            ++summary.pauseViolations;
        }
        if (day.sixHoursUninterrupted) {
            ++summary.consecutiveSixHourViolations;
        }
        if (day.sunday && day.hasWork) {
            ++summary.sundayWorkDays;
            day.ersatzruheMissing = !hasErsatzruhe(d, kSundayErsatzDays);
        }
        if (day.publicHoliday && day.hasWork) {
            ++summary.holidayWorkDays;
            day.ersatzruheMissing = day.ersatzruheMissing
                                    || !hasErsatzruhe(d, kHolidayErsatzWeeks * 7);
        }
        if (day.ersatzruheMissing) {
            ++summary.ersatzruheMissing;
            day.issues << QStringLiteral("Ersatzruhetag fehlt (§11)");
        }
        if (day.nightWork) {
            ++summary.nightWorkDays;
        }
        if (day.usualPauseMissed) {
            ++summary.usualPauseHints;
        }
        if (day.hasIssue()) {
            summary.issueDays.append(day);
        } else if (!day.notes.isEmpty()) {
            summary.noteDays.append(day);
        }
    }

    summary.tooFewFreeSundays = summary.freeSundays < kFreeSundaysRequired;
    summary.nightWorker = summary.nightWorkDays >= kNightWorkerDaysPerYear;
    return summary;
}

QString ArbzgCompliance::nachweisHtml(int year, int month)
{
    const QDate first(year, month, 1);
    if (!first.isValid()) {
        return {};
    }

    CalendarService::instance().ensureYearLoaded(year);
    const QLocale locale;
    const int days = first.daysInMonth();
    const QDate today = QDate::currentDate();

    QString html;
    html += QStringLiteral("<!DOCTYPE html><html lang=\"de\"><head><meta charset=\"utf-8\">");
    html += QStringLiteral("<title>Arbeitszeitnachweis %1</title>").arg(locale.toString(first, QStringLiteral("MMMM yyyy")));
    html += QStringLiteral(
        "<style>body{font-family:Segoe UI,sans-serif;font-size:13px;}"
        "table{border-collapse:collapse;width:100%;}"
        "th,td{border:1px solid #ccc;padding:4px 6px;text-align:left;}"
        "th{background:#eee;} td.num{text-align:right;font-variant-numeric:tabular-nums;}"
        ".issue{color:#b40000;} .note{color:#b35c00;}</style></head><body>");
    html += QStringLiteral("<h1>Arbeitszeitnachweis</h1>");
    html += QStringLiteral("<p>%1 · Bundesland: %2</p>")
                .arg(locale.toString(first, QStringLiteral("MMMM yyyy")),
                     AppSettings::instance().stateDisplayName());
    html += QStringLiteral(
        "<p>Beginn, Ende und Pausen nach ArbZG / BAG. "
        "Arbeitszeit ist die Zeit ohne Ruhepausen (volle Erfassung, ohne Tagesgrenzen, "
        "ohne automatischen Pausenabzug des Stundenkontos).</p>");
    html += QStringLiteral(
        "<table><thead><tr>"
        "<th>Tag</th><th>Beginn</th><th>Ende</th><th>Pausen</th>"
        "<th class=\"num\">Dauer</th><th class=\"num\">Nacht</th><th>Hinweise</th>"
        "</tr></thead><tbody>");

    int totalWork = 0;
    int totalNight = 0;
    for (int day = 1; day <= days; ++day) {
        const QDate date(year, month, day);
        ArbzgDay assessed;
        if (date <= today) {
            assessed = assessDay(date);
        } else {
            assessed.date = date;
        }
        totalWork += assessed.rawWorkMinutes;
        totalNight += assessed.nightMinutes;

        QStringList pauseTexts;
        for (const auto &pause : assessed.pauses) {
            pauseTexts << QStringLiteral("%1–%2")
                              .arg(formatClock(pause.startMinute), formatClock(pause.endMinute));
        }

        QStringList hints = assessed.issues + assessed.notes;
        if (CalendarService::instance().isPublicHoliday(date)) {
            hints.prepend(CalendarService::instance().publicHolidayName(date));
        }
        const QString cls = assessed.hasIssue()
                                ? QStringLiteral(" class=\"issue\"")
                                : (!assessed.notes.isEmpty() ? QStringLiteral(" class=\"note\"")
                                                             : QString());

        html += QStringLiteral("<tr%1>").arg(cls);
        html += QStringLiteral("<td>%1</td>")
                    .arg(locale.toString(date, QStringLiteral("ddd, dd.MM.")));
        html += QStringLiteral("<td>%1</td>").arg(formatClock(assessed.firstWorkMinute));
        html += QStringLiteral("<td>%1</td>").arg(formatClock(assessed.lastWorkMinute));
        html += QStringLiteral("<td>%1</td>")
                    .arg(pauseTexts.isEmpty() ? QStringLiteral("–") : pauseTexts.join(QStringLiteral(", ")));
        html += QStringLiteral("<td class=\"num\">%1</td>")
                    .arg(assessed.hasWork ? formatDuration(assessed.rawWorkMinutes)
                                          : QStringLiteral("–"));
        html += QStringLiteral("<td class=\"num\">%1</td>")
                    .arg(assessed.nightMinutes > 0 ? formatDuration(assessed.nightMinutes)
                                                   : QStringLiteral("–"));
        html += QStringLiteral("<td>%1</td>").arg(hints.join(QStringLiteral("; ")));
        html += QStringLiteral("</tr>");
    }

    html += QStringLiteral("</tbody></table>");
    html += QStringLiteral("<p>Summe Arbeitszeit: %1 · davon Nachtzeit: %2 · erstellt %3</p>")
                .arg(formatDuration(totalWork),
                     formatDuration(totalNight),
                     locale.toString(QDateTime::currentDateTime(), QStringLiteral("dd.MM.yyyy HH:mm")));
    html += QStringLiteral("</body></html>");
    return html;
}
