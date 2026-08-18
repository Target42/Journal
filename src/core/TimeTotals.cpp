#include "TimeTotals.h"

#include "Absence.h"
#include "AppSettings.h"
#include "CalendarService.h"
#include "JournalStore.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QList>
#include <QtGlobal>

#include <algorithm>

namespace {
void addMonth(int &year, int &month)
{
    if (month >= 12) {
        ++year;
        month = 1;
    } else {
        ++month;
    }
}

bool isOvertimeLimitMonth(int month, OvertimeLimitPeriod period)
{
    if (period == OvertimeLimitPeriod::Monthly) {
        return true;
    }
    return month == 3 || month == 6 || month == 9 || month == 12;
}

bool overtimePeriodHasEnded(int year, int month)
{
    const QDate today = QDate::currentDate();
    const QDate lastDay(year, month, QDate(year, month, 1).daysInMonth());
    return lastDay.isValid() && lastDay < today;
}

void applyOvertimeLimits(MonthTotals &totals)
{
    totals.clippedHours = 0.0;
    totals.closingSaldo = totals.carryIn + totals.monthSaldo;

    const OvertimeAccountSettings account = AppSettings::instance().overtimeAccount();
    if (!account.limitsEnabled) {
        return;
    }
    if (!isOvertimeLimitMonth(totals.month, account.period)) {
        return;
    }
    if (!overtimePeriodHasEnded(totals.year, totals.month)) {
        return;
    }

    const double limited = qBound(account.minHours, totals.closingSaldo, account.maxHours);
    totals.clippedHours = totals.closingSaldo - limited;
    totals.closingSaldo = limited;
}

double creditedHours(const QDate &date, double target, double workHours, const Absence &absence)
{
    if (!absence.isSet() || target <= 0.0 || date > QDate::currentDate()) {
        return workHours;
    }
    if (absence.fraction >= 0.999) {
        return target;
    }
    return workHours + target * absence.fraction;
}

Absence effectiveAbsence(const QDate &date)
{
    const Absence stored = JournalStore::instance().absenceForDate(date);
    if (stored.isSet()) {
        return stored;
    }
    if (CalendarService::instance().isPublicHoliday(date)) {
        return {};
    }
    return AppSettings::instance().impliedAbsenceForDate(date);
}
} // namespace

TimeTotals &TimeTotals::instance()
{
    static TimeTotals totals;
    return totals;
}

TimeTotals::TimeTotals()
    : QObject(nullptr)
{
    auto &store = JournalStore::instance();
    connect(&store, &JournalStore::packagesChanged, this, &TimeTotals::onPackagesChanged);
    connect(&store, &JournalStore::absencesChanged, this, &TimeTotals::onAbsencesChanged);
    connect(&store, &JournalStore::dayBoundsChanged, this, &TimeTotals::onPackagesChanged);
    connect(&store, &JournalStore::activeDayTicked, this, [this]() {
        recalculateLiveMonth({});
    });
    connect(&store, &JournalStore::dataReloaded, this, &TimeTotals::clearCache);

    connect(&AppSettings::instance(), &AppSettings::changed, this, [this]() {
        clearCache();
    });

    connect(&CalendarService::instance(), &CalendarService::yearDataChanged,
            this, [this](int year) {
                m_years.remove(year);
                for (int month = 1; month <= 12; ++month) {
                    m_months.remove(monthKey(year, month));
                }
                ensureYear(year);
                emit yearRecalculated(year);
            });
}

QString TimeTotals::monthKey(int year, int month)
{
    return QStringLiteral("%1-%2").arg(year).arg(month, 2, 10, QLatin1Char('0'));
}

QString TimeTotals::yearFilePath(int year) const
{
    const QString dir =
        QDir(AppSettings::instance().dataPath()).filePath(QStringLiteral("jahre"));
    return QDir(dir).filePath(QStringLiteral("%1.json").arg(year));
}

int TimeTotals::earliestDataYear() const
{
    int earliest = QDate::currentDate().year();
    const QString dataPath = AppSettings::instance().dataPath();

    auto considerYear = [&earliest](int year) {
        if (year >= 1970 && year <= 2100 && year < earliest) {
            earliest = year;
        }
    };

    const QDir yearsDir(QDir(dataPath).filePath(QStringLiteral("jahre")));
    for (const QString &name : yearsDir.entryList({QStringLiteral("*.json")}, QDir::Files)) {
        bool ok = false;
        const int year = QFileInfo(name).completeBaseName().toInt(&ok);
        if (ok) {
            considerYear(year);
        }
    }

    const QDir monthsDir(QDir(dataPath).filePath(QStringLiteral("monate")));
    for (const QString &name : monthsDir.entryList({QStringLiteral("*.json")}, QDir::Files)) {
        const QString base = QFileInfo(name).completeBaseName();
        const int dash = base.indexOf(QLatin1Char('-'));
        bool ok = false;
        const int year = (dash > 0 ? base.left(dash) : base).toInt(&ok);
        if (ok) {
            considerYear(year);
        }
    }

    return earliest;
}

void TimeTotals::clearCache()
{
    m_months.clear();
    m_years.clear();
    m_firstMonthFile = {};
    m_firstMonthFileKnown = false;
}

QDate TimeTotals::firstMonthFile() const
{
    if (m_firstMonthFileKnown) {
        return m_firstMonthFile;
    }

    QDate first;
    const QDir monthsDir(
        QDir(AppSettings::instance().dataPath()).filePath(QStringLiteral("monate")));
    for (const QString &name : monthsDir.entryList({QStringLiteral("*.json")}, QDir::Files)) {
        const QString base = QFileInfo(name).completeBaseName();
        const auto parts = base.split(QLatin1Char('-'));
        if (parts.size() != 2) {
            continue;
        }
        bool okYear = false;
        bool okMonth = false;
        const int year = parts[0].toInt(&okYear);
        const int month = parts[1].toInt(&okMonth);
        if (!okYear || !okMonth) {
            continue;
        }
        const QDate candidate(year, month, 1);
        if (!candidate.isValid()) {
            continue;
        }
        if (!first.isValid() || candidate < first) {
            first = candidate;
        }
    }

    m_firstMonthFile = first;
    m_firstMonthFileKnown = true;
    return first;
}

void TimeTotals::ensureYear(int year)
{
    if (year < 1970 || year > 2100) {
        return;
    }
    if (m_years.contains(year)) {
        return;
    }
    fillYearMonths(year, false);
    persistYear(year);
}

MonthTotals TimeTotals::monthTotals(int year, int month)
{
    ensureYear(year);
    MonthTotals totals = m_months.value(monthKey(year, month));
    if (totals.year != year) {
        return totals;
    }
    totals.carryIn = openingCarry(year, month);
    applyOvertimeLimits(totals);
    m_months.insert(monthKey(year, month), totals);
    return totals;
}

YearTotals TimeTotals::yearTotals(int year)
{
    ensureYear(year);
    return m_years.value(year);
}

double TimeTotals::creditedHoursForDate(const QDate &date) const
{
    if (!date.isValid()) {
        return 0.0;
    }
    const double target = CalendarService::instance().isPublicHoliday(date)
                              ? 0.0
                              : AppSettings::instance().targetHoursForDate(date);
    auto &store = JournalStore::instance();
    return creditedHours(date, target, store.actualHoursForDate(date),
                         effectiveAbsence(date));
}

Absence TimeTotals::effectiveAbsenceForDate(const QDate &date) const
{
    if (!date.isValid()) {
        return {};
    }
    return effectiveAbsence(date);
}

AccountTrend TimeTotals::accountTrend(int workedDays) const
{
    AccountTrend trend;
    if (workedDays <= 0) {
        return trend;
    }

    const QDate today = QDate::currentDate();
    QDate limit = today.addMonths(-18);
    const QDate dataStart = firstMonthFile();
    if (dataStart.isValid() && dataStart > limit) {
        limit = dataStart;
    }

    auto &store = JournalStore::instance();
    auto &calendar = CalendarService::instance();
    auto &settings = AppSettings::instance();

    QVector<AccountTrendPoint> newestFirst;
    newestFirst.reserve(workedDays);

    for (QDate date = today; date.isValid() && date >= limit && newestFirst.size() < workedDays;
         date = date.addDays(-1)) {
        calendar.ensureYearLoaded(date.year());
        const double workHours = store.actualHoursForDate(date);
        if (workHours <= 0.005) {
            continue;
        }

        const Absence absence = effectiveAbsence(date);
        if (absence.isSet() && !absence.isHalfDay()) {
            continue;
        }

        const double target = calendar.isPublicHoliday(date)
                                  ? 0.0
                                  : settings.targetHoursForDate(date);
        const double actual = creditedHours(date, target, workHours, absence);
        AccountTrendPoint point;
        point.date = date;
        point.saldo = actual - target;
        newestFirst.append(point);
        trend.totalSaldo += point.saldo;
    }

    std::reverse(newestFirst.begin(), newestFirst.end());
    trend.points = newestFirst;
    if (trend.points.isEmpty()) {
        return trend;
    }

    trend.from = trend.points.first().date;
    trend.to = trend.points.last().date;
    trend.averagePerWorkedDay = trend.totalSaldo / trend.points.size();
    const int workDayCount = qMax(1, settings.workDayCount());
    trend.projectedPerWeek = trend.averagePerWorkedDay * workDayCount;
    trend.projectedPerMonth = trend.projectedPerWeek * (52.0 / 12.0);
    return trend;
}

MonthTotals TimeTotals::computeMonth(int year, int month, double carryIn) const
{
    MonthTotals totals;
    totals.year = year;
    totals.month = month;
    totals.carryIn = carryIn;

    const QDate first(year, month, 1);
    if (!first.isValid()) {
        totals.closingSaldo = carryIn;
        return totals;
    }

    const QDate dataStart = firstMonthFile();
    if (dataStart.isValid() && first < dataStart) {
        totals.closingSaldo = carryIn;
        return totals;
    }

    auto &calendar = CalendarService::instance();
    auto &settings = AppSettings::instance();
    auto &store = JournalStore::instance();
    calendar.ensureYearLoaded(year);

    const QDate today = QDate::currentDate();
    const int days = first.daysInMonth();
    for (int day = 1; day <= days; ++day) {
        const QDate date(year, month, day);
        const double target = calendar.isPublicHoliday(date)
                                  ? 0.0
                                  : settings.targetHoursForDate(date);
        const Absence absence = effectiveAbsence(date);
        const double actual =
            creditedHours(date, target, store.actualHoursForDate(date), absence);
        totals.targetHours += target;
        totals.actualHours += actual;
        if (date <= today) {
            totals.monthSaldo += actual - target;
        }
        if (absence.type == AbsenceType::Vacation && target > 0.0) {
            const double daysOff = absence.fraction >= 0.999 ? 1.0 : 0.5;
            if (date <= today) {
                totals.vacationTaken += daysOff;
            } else {
                totals.vacationPlanned += daysOff;
            }
        }
    }

    applyOvertimeLimits(totals);
    return totals;
}

YearTotals TimeTotals::assembleYear(int year) const
{
    YearTotals totals;
    totals.year = year;
    const MonthTotals january = m_months.value(monthKey(year, 1));
    totals.carryIn = january.carryIn;

    for (int month = 1; month <= 12; ++month) {
        const MonthTotals monthTotals = m_months.value(monthKey(year, month));
        totals.targetHours += monthTotals.targetHours;
        totals.actualHours += monthTotals.actualHours;
        totals.saldo += monthTotals.monthSaldo;
        totals.clippedHours += monthTotals.clippedHours;
        totals.vacationTaken += monthTotals.vacationTaken;
        totals.vacationPlanned += monthTotals.vacationPlanned;
    }
    totals.saldo += totals.carryIn;
    totals.closingSaldo = totals.carryIn;
    const MonthTotals december = m_months.value(monthKey(year, 12));
    if (december.year == year) {
        totals.closingSaldo = december.closingSaldo;
    } else {
        totals.closingSaldo = totals.saldo;
    }
    return totals;
}

double TimeTotals::openingCarry(int year, int month)
{
    if (month <= 1) {
        const int prevYear = year - 1;
        if (prevYear < 1970) {
            return 0.0;
        }
        if (prevYear < earliestDataYear()) {
            const YearTotals previous = loadYearFile(prevYear);
            return previous.year == prevYear ? previous.closingSaldo : 0.0;
        }
        ensureYear(prevYear);
        if (const auto it = m_years.constFind(prevYear); it != m_years.cend()) {
            return it->closingSaldo;
        }
        return 0.0;
    }

    const QString key = monthKey(year, month - 1);
    if (const auto it = m_months.constFind(key); it != m_months.cend()) {
        MonthTotals previous = *it;
        applyOvertimeLimits(previous);
        m_months.insert(key, previous);
        return previous.closingSaldo;
    }

    const double carry = openingCarry(year, month - 1);
    const MonthTotals previous = computeMonth(year, month - 1, carry);
    m_months.insert(key, previous);
    return previous.closingSaldo;
}

void TimeTotals::fillYearMonths(int year, bool emitMonthSignals)
{
    CalendarService::instance().ensureYearLoaded(year);
    double carry = openingCarry(year, 1);
    for (int month = 1; month <= 12; ++month) {
        const MonthTotals totals = computeMonth(year, month, carry);
        m_months.insert(monthKey(year, month), totals);
        carry = totals.closingSaldo;
        if (emitMonthSignals) {
            emit monthRecalculated(year, month);
        }
    }
    m_years.insert(year, assembleYear(year));
}

void TimeTotals::persistYear(int year)
{
    const YearTotals totals = m_years.value(year);
    if (totals.year != year) {
        return;
    }

    QJsonArray months;
    for (int month = 1; month <= 12; ++month) {
        const MonthTotals m = m_months.value(monthKey(year, month));
        QJsonObject obj;
        obj.insert(QStringLiteral("month"), month);
        obj.insert(QStringLiteral("targetHours"), m.targetHours);
        obj.insert(QStringLiteral("actualHours"), m.actualHours);
        obj.insert(QStringLiteral("carryIn"), m.carryIn);
        obj.insert(QStringLiteral("monthSaldo"), m.monthSaldo);
        obj.insert(QStringLiteral("closingSaldo"), m.closingSaldo);
        obj.insert(QStringLiteral("clippedHours"), m.clippedHours);
        obj.insert(QStringLiteral("vacationTaken"), m.vacationTaken);
        obj.insert(QStringLiteral("vacationPlanned"), m.vacationPlanned);
        months.append(obj);
    }

    QJsonObject root;
    root.insert(QStringLiteral("year"), year);
    root.insert(QStringLiteral("targetHours"), totals.targetHours);
    root.insert(QStringLiteral("actualHours"), totals.actualHours);
    root.insert(QStringLiteral("carryIn"), totals.carryIn);
    root.insert(QStringLiteral("saldo"), totals.saldo);
    root.insert(QStringLiteral("closingSaldo"), totals.closingSaldo);
    root.insert(QStringLiteral("clippedHours"), totals.clippedHours);
    root.insert(QStringLiteral("vacationTaken"), totals.vacationTaken);
    root.insert(QStringLiteral("vacationPlanned"), totals.vacationPlanned);
    root.insert(QStringLiteral("months"), months);

    const QString path = yearFilePath(year);
    QDir().mkpath(QFileInfo(path).absolutePath());
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        return;
    }
    file.write(QJsonDocument(root).toJson(QJsonDocument::Indented));
}

YearTotals TimeTotals::loadYearFile(int year) const
{
    YearTotals totals;
    QFile file(yearFilePath(year));
    if (!file.exists() || !file.open(QIODevice::ReadOnly)) {
        return totals;
    }

    const auto doc = QJsonDocument::fromJson(file.readAll());
    const QJsonObject root = doc.object();
    if (root.value(QStringLiteral("year")).toInt() != year) {
        return totals;
    }

    totals.year = year;
    totals.targetHours = root.value(QStringLiteral("targetHours")).toDouble();
    totals.actualHours = root.value(QStringLiteral("actualHours")).toDouble();
    totals.carryIn = root.value(QStringLiteral("carryIn")).toDouble();
    totals.saldo = root.value(QStringLiteral("saldo")).toDouble();
    totals.closingSaldo = root.value(QStringLiteral("closingSaldo")).toDouble();
    totals.clippedHours = root.value(QStringLiteral("clippedHours")).toDouble();
    totals.vacationTaken = root.value(QStringLiteral("vacationTaken")).toDouble();
    totals.vacationPlanned = root.value(QStringLiteral("vacationPlanned")).toDouble();
    return totals;
}

void TimeTotals::recalculateLiveMonth(const QDate &changedDay)
{
    const QDate today = QDate::currentDate();
    const int year = today.year();
    const int month = today.month();
    if (month <= 1) {
        if (year - 1 >= 1970) {
            recalculateFrom(year - 1, 12);
        } else {
            recalculateFrom(year, 1);
        }
    } else {
        recalculateFrom(year, month - 1);
    }

    emit dayRecalculated(changedDay.isValid() ? changedDay : today);
}

void TimeTotals::recalculateFrom(int year, int month)
{
    const QDate today = QDate::currentDate();
    const int endYear = qMax(year, today.year());

    int y = year;
    int m = month;
    double carry = openingCarry(y, m);
    QList<int> years;

    while (y < endYear || (y == endYear && m <= 12)) {
        const MonthTotals totals = computeMonth(y, m, carry);
        m_months.insert(monthKey(y, m), totals);
        carry = totals.closingSaldo;
        emit monthRecalculated(y, m);
        if (!years.contains(y)) {
            years.append(y);
        }
        if (y == endYear && m == 12) {
            break;
        }
        addMonth(y, m);
    }

    for (int affected : years) {
        m_years.insert(affected, assembleYear(affected));
        persistYear(affected);
        emit yearRecalculated(affected);
    }
}

void TimeTotals::onAbsencesChanged(const QDate &from, const QDate &to)
{
    if (!from.isValid()) {
        return;
    }

    QDate start = from;
    QDate end = to.isValid() ? to : from;
    if (end < start) {
        qSwap(start, end);
    }

    if (start.year() == end.year() && start.month() == end.month()) {
        onPackagesChanged(start);
        return;
    }

    const QDate today = QDate::currentDate();
    if (start.year() < today.year()
        || (start.year() == today.year() && start.month() < today.month())) {
        recalculateFrom(start.year(), start.month());
        emit dayRecalculated(start);
        return;
    }

    QDate month(start.year(), start.month(), 1);
    const QDate last(end.year(), end.month(), 1);
    QList<int> years;
    while (month.isValid() && month <= last) {
        const double carry = openingCarry(month.year(), month.month());
        const MonthTotals totals = computeMonth(month.year(), month.month(), carry);
        m_months.insert(monthKey(month.year(), month.month()), totals);
        emit monthRecalculated(month.year(), month.month());
        if (!years.contains(month.year())) {
            years.append(month.year());
        }
        month = month.addMonths(1);
    }
    for (int affected : years) {
        m_years.insert(affected, assembleYear(affected));
        persistYear(affected);
        emit yearRecalculated(affected);
    }
    emit dayRecalculated(start);
}

void TimeTotals::onPackagesChanged(const QDate &date)
{
    if (!date.isValid()) {
        return;
    }

    const QDate today = QDate::currentDate();
    if (date.year() > today.year()
        || (date.year() == today.year() && date.month() > today.month())) {
        const double carry = openingCarry(date.year(), date.month());
        const MonthTotals totals = computeMonth(date.year(), date.month(), carry);
        m_months.insert(monthKey(date.year(), date.month()), totals);
        if (m_years.contains(date.year()) || date.year() == today.year()) {
            m_years.insert(date.year(), assembleYear(date.year()));
            persistYear(date.year());
            emit yearRecalculated(date.year());
        }
        emit dayRecalculated(date);
        emit monthRecalculated(date.year(), date.month());
        return;
    }

    if (date.year() == today.year() && date.month() == today.month()) {
        recalculateLiveMonth(date);
        return;
    }

    recalculateFrom(date.year(), date.month());
    emit dayRecalculated(date);
}
