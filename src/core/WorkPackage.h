#pragma once

#include <QColor>
#include <QDate>
#include <QString>
#include <QTime>
#include <QtGlobal>

inline int timeToMinute(const QTime &time)
{
    if (!time.isValid()) {
        return 0;
    }
    return time.hour() * 60 + time.minute();
}

inline QTime minuteToTime(int minute)
{
    minute = qBound(0, minute, 23 * 60 + 59);
    return QTime(minute / 60, minute % 60);
}

struct PackageTitle {
    QString title;
    QColor color;
};

struct WorkPackage {
    QString id;
    QString title;
    QString details;
    QTime start;
    QTime end;
    bool active = false;

    int startMinute() const { return timeToMinute(start); }

    int endMinute(const QDate &date) const
    {
        if (active && date == QDate::currentDate()) {
            const int now = timeToMinute(QTime::currentTime());
            return qMax(now, startMinute());
        }
        if (!end.isValid()) {
            return startMinute();
        }
        return qMax(timeToMinute(end), startMinute());
    }
};

inline constexpr int kDefaultDayStartMinute = 6 * 60;
inline constexpr int kDefaultDayEndMinute = 20 * 60;

struct DayBounds {
    int startMinute = kDefaultDayStartMinute;
    int endMinute = kDefaultDayEndMinute;
    bool custom = false;

    int span() const { return qMax(1, endMinute - startMinute); }

    QString label() const
    {
        return QStringLiteral("%1–%2")
            .arg(minuteToTime(startMinute).toString(QStringLiteral("HH:mm")),
                 minuteToTime(endMinute).toString(QStringLiteral("HH:mm")));
    }
};

inline DayBounds sanitizedDayBounds(int startMinute, int endMinute, bool custom = false)
{
    startMinute = qBound(0, startMinute, 23 * 60 + 58);
    endMinute = qBound(startMinute + 1, endMinute, 24 * 60);
    return {startMinute, endMinute, custom};
}

inline constexpr int kPausePresetCount = 3;
inline constexpr int kDefaultBreakfastStartMinute = 9 * 60;
inline constexpr int kDefaultBreakfastEndMinute = 9 * 60 + 15;

struct PausePreset {
    QString name;
    int startMinute = 0;
    int endMinute = 0;

    bool isValid() const
    {
        return !name.trimmed().isEmpty() && endMinute > startMinute;
    }

    QString label() const { return name.trimmed(); }

    QString timeLabel() const
    {
        return QStringLiteral("%1–%2")
            .arg(minuteToTime(startMinute).toString(QStringLiteral("HH:mm")),
                 minuteToTime(endMinute).toString(QStringLiteral("HH:mm")));
    }
};
