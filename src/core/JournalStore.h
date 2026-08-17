#pragma once

#include "Absence.h"
#include "BreakRules.h"
#include "WorkPackage.h"

#include <QDate>
#include <QHash>
#include <QObject>
#include <QPair>
#include <QTimer>
#include <QVector>

class JournalStore : public QObject
{
    Q_OBJECT

public:
    static JournalStore &instance();

    QVector<WorkPackage> packagesForDate(const QDate &date);
    WorkPackage packageById(const QDate &date, const QString &id);

    bool savePackage(const QDate &date, WorkPackage package, QString *error = nullptr);
    bool removePackage(const QDate &date, const QString &id, QString *error = nullptr);
    bool renameTitle(const QString &from, const QString &to, QString *error = nullptr);

    QVector<PauseInterval> pausesForDate(const QDate &date);
    PauseInterval pauseCoveringRange(const QDate &date, int startMinute, int endMinute);
    bool suggestPause(const QDate &date, int atMinute, int *startMinute, int *endMinute,
                      bool *existingGap);
    bool applyPause(const QDate &date, int startMinute, int endMinute, QString *error = nullptr);
    bool closePause(const QDate &date, int startMinute, int endMinute, QString *error = nullptr);

    bool startMinuteTaken(const QDate &date, int startMinute, const QString &excludeId = {});

    double actualHoursForDate(const QDate &date);
    double actualHoursForMonth(int year, int month);
    BreakAdjustment breakAdjustmentForDate(const QDate &date);
    QVector<char> fullDayCoverage(const QDate &date);
    QVector<QPair<QString, double>> titleHoursForMonth(int year, int month);

    Absence absenceForDate(const QDate &date);
    bool setAbsences(const QVector<QDate> &dates, const Absence &absence, QString *error = nullptr);

    DayBounds boundsForDate(const QDate &date);
    bool setBoundsForDate(const QDate &date, const DayBounds &bounds, QString *error = nullptr);

signals:
    void changed();
    void packagesChanged(const QDate &date);
    void absencesChanged(const QDate &from, const QDate &to);
    void dayBoundsChanged(const QDate &date);
    void activeDayTicked();
    void dataReloaded();

private:
    struct MonthData {
        int year = 0;
        int month = 0;
        QHash<int, QVector<WorkPackage>> days;
        QHash<int, Absence> absences;
        QHash<int, DayBounds> dayBounds;
        bool loaded = false;
    };

    JournalStore();

    static QString monthKey(int year, int month);
    QString monthFilePath(int year, int month) const;

    void reloadIfPathChanged();
    void ensureMonthLoaded(int year, int month);
    void loadMonth(int year, int month);
    bool saveMonth(int year, int month, QString *error);

    MonthData &monthData(int year, int month);
    const MonthData *monthDataIfLoaded(int year, int month) const;

    bool hasActivePackagesToday() const;
    bool persistActivePackagesToday();
    int lastCountableMinute(const QDate &date) const;
    QVector<char> coverageForDate(const QDate &date);

    QString m_dataPath;
    QHash<QString, MonthData> m_months;
    QTimer m_tick;
};
