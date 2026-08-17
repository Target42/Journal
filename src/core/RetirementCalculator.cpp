#include "RetirementCalculator.h"

#include "AppSettings.h"
#include "CalendarService.h"
#include "TimeTotals.h"

#include <QtGlobal>

#include <cmath>

namespace {
int fullMonthsWorked(int year, const QDate &lastWorkDate)
{
    if (!lastWorkDate.isValid() || lastWorkDate.year() != year) {
        return 0;
    }

    int count = 0;
    for (int month = 1; month <= 12; ++month) {
        const QDate start(year, month, 1);
        const QDate end(year, month, start.daysInMonth());
        if (end <= lastWorkDate) {
            ++count;
        }
    }
    return count;
}

double proratedVacation(double annualDays, int fullMonths)
{
    const int months = qBound(0, fullMonths, 12);
    const double raw = annualDays * static_cast<double>(months) / 12.0;
    return std::round(raw * 2.0) / 2.0;
}

QDate lastWorkDateBefore(const QDate &retirementDate)
{
    return retirementDate.addDays(-1);
}
} // namespace

RetirementPlan RetirementCalculator::compute(const QDate &from, const QDate &retirementDate,
                                             bool prorateLastYear)
{
    RetirementPlan plan;
    plan.startDate = from;
    plan.retirementDate = retirementDate;
    plan.proratedLastYear = prorateLastYear;

    auto &settings = AppSettings::instance();
    plan.stateName = settings.stateDisplayName();
    plan.annualVacation = settings.workSettings().annualVacationDays;

    if (!from.isValid() || !retirementDate.isValid()) {
        plan.error = QStringLiteral("Bitte gültige Daten wählen.");
        return plan;
    }
    if (retirementDate <= from) {
        plan.error = QStringLiteral("Der Renteneintritt muss nach dem Stichtag liegen.");
        return plan;
    }

    plan.lastWorkDate = lastWorkDateBefore(retirementDate);
    if (plan.lastWorkDate < from) {
        plan.error = QStringLiteral("Zwischen Stichtag und Renteneintritt liegt kein Arbeitstag.");
        return plan;
    }

    plan.fullMonthsInExitYear = fullMonthsWorked(plan.lastWorkDate.year(), plan.lastWorkDate);

    auto &calendar = CalendarService::instance();
    const QDate today = QDate::currentDate();

    for (int year = from.year(); year <= plan.lastWorkDate.year(); ++year) {
        calendar.ensureYearLoaded(year);

        RetirementYearBreakdown row;
        row.year = year;
        row.from = QDate(year, 1, 1);
        if (row.from < from) {
            row.from = from;
        }
        row.to = QDate(year, 12, 31);
        if (row.to > plan.lastWorkDate) {
            row.to = plan.lastWorkDate;
        }
        row.holidaysAvailable = calendar.hasPublicHolidays(year);
        if (!row.holidaysAvailable) {
            plan.missingHolidayYears.append(year);
        }

        double hoursPool = 0.0;
        for (QDate day = row.from; day <= row.to; day = day.addDays(1)) {
            if (settings.targetHoursForDate(day) <= 0.0) {
                continue;
            }
            ++row.workDays;
            if (calendar.isPublicHoliday(day)) {
                ++row.holidaysOnWorkDays;
            } else {
                hoursPool += settings.targetHoursForDate(day);
            }
        }

        const int countable = row.workDays - row.holidaysOnWorkDays;
        const double hoursPerDay = countable > 0 ? hoursPool / static_cast<double>(countable) : 0.0;

        const bool isExitYear = year == plan.lastWorkDate.year();
        if (isExitYear && prorateLastYear) {
            row.vacationDays = proratedVacation(plan.annualVacation, plan.fullMonthsInExitYear);
        } else {
            row.vacationDays = plan.annualVacation;
        }

        if (year == today.year()) {
            TimeTotals::instance().ensureYear(year);
            const double taken = TimeTotals::instance().yearTotals(year).vacationTaken;
            row.vacationDays = qMax(0.0, row.vacationDays - taken);
        }

        row.remainingDays = static_cast<double>(countable) - row.vacationDays;
        if (row.remainingDays < 0.0) {
            row.remainingDays = 0.0;
        }
        row.remainingHours = row.remainingDays * hoursPerDay;

        plan.years.append(row);
        plan.totalWorkDays += row.workDays;
        plan.totalHolidays += row.holidaysOnWorkDays;
        plan.totalVacation += row.vacationDays;
        plan.totalRemainingDays += row.remainingDays;
        plan.totalRemainingHours += row.remainingHours;
    }

    return plan;
}
