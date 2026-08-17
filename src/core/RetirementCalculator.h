#pragma once

#include <QDate>
#include <QString>
#include <QVector>

struct RetirementYearBreakdown {
    int year = 0;
    QDate from;
    QDate to;
    int workDays = 0;
    int holidaysOnWorkDays = 0;
    double vacationDays = 0.0;
    double remainingDays = 0.0;
    double remainingHours = 0.0;
    bool holidaysAvailable = false;
};

struct RetirementPlan {
    QDate startDate;
    QDate retirementDate;
    QDate lastWorkDate;
    QString stateName;
    double annualVacation = 0.0;
    bool proratedLastYear = true;
    int fullMonthsInExitYear = 0;
    QVector<RetirementYearBreakdown> years;
    int totalWorkDays = 0;
    int totalHolidays = 0;
    double totalVacation = 0.0;
    double totalRemainingDays = 0.0;
    double totalRemainingHours = 0.0;
    QVector<int> missingHolidayYears;
    QString error;
};

class RetirementCalculator
{
public:
    static RetirementPlan compute(const QDate &from, const QDate &retirementDate,
                                  bool prorateLastYear);
};
