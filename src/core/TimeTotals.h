#pragma once

#include <QDate>
#include <QHash>
#include <QObject>
#include <QString>
#include <QVector>

struct MonthTotals {
    int year = 0;
    int month = 0;
    double targetHours = 0.0;
    double actualHours = 0.0;
    double carryIn = 0.0;
    double monthSaldo = 0.0;
    double closingSaldo = 0.0;
    double clippedHours = 0.0;
    double vacationTaken = 0.0;
    double vacationPlanned = 0.0;
};

struct YearTotals {
    int year = 0;
    double targetHours = 0.0;
    double actualHours = 0.0;
    double carryIn = 0.0;
    double saldo = 0.0;
    double closingSaldo = 0.0;
    double clippedHours = 0.0;
    double vacationTaken = 0.0;
    double vacationPlanned = 0.0;
};

struct AccountTrendPoint {
    QDate date;
    double saldo = 0.0;
};

struct AccountTrend {
    QVector<AccountTrendPoint> points;
    QDate from;
    QDate to;
    double totalSaldo = 0.0;
    double averagePerWorkedDay = 0.0;
    double projectedPerWeek = 0.0;
    double projectedPerMonth = 0.0;
};

class TimeTotals : public QObject
{
    Q_OBJECT

public:
    static TimeTotals &instance();

    void ensureYear(int year);

    MonthTotals monthTotals(int year, int month);
    YearTotals yearTotals(int year);

    double creditedHoursForDate(const QDate &date) const;
    AccountTrend accountTrend(int workedDays = 30) const;

signals:
    void dayRecalculated(const QDate &date);
    void monthRecalculated(int year, int month);
    void yearRecalculated(int year);

private:
    TimeTotals();

    static QString monthKey(int year, int month);

    QString yearFilePath(int year) const;
    int earliestDataYear() const;
    QDate firstMonthFile() const;

    MonthTotals computeMonth(int year, int month, double carryIn) const;
    YearTotals assembleYear(int year) const;

    double openingCarry(int year, int month);
    void fillYearMonths(int year, bool emitMonthSignals);
    void persistYear(int year);

    void recalculateLiveMonth(const QDate &changedDay = {});
    void recalculateFrom(int year, int month);
    void onPackagesChanged(const QDate &date);
    void onAbsencesChanged(const QDate &from, const QDate &to);

    void clearCache();

    YearTotals loadYearFile(int year) const;

    QHash<QString, MonthTotals> m_months;
    QHash<int, YearTotals> m_years;
    mutable QDate m_firstMonthFile;
    mutable bool m_firstMonthFileKnown = false;
};
