#pragma once

#include <QDate>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QVector>

enum class AppointmentKind {
    Once,
    Weekly,
};

struct Appointment {
    QString id;
    QString title;
    int startMinute = 0;
    int endMinute = 0;
    AppointmentKind kind = AppointmentKind::Once;
    QDate date;
    QVector<int> weekdays;

    bool occursOn(const QDate &day) const;
    QString summary() const;
};

class AppointmentCatalog : public QObject
{
    Q_OBJECT

public:
    static AppointmentCatalog &instance();

    QVector<Appointment> all() const;
    QVector<Appointment> forDate(const QDate &date) const;
    QStringList titlesForDate(const QDate &date) const;
    Appointment byId(const QString &id) const;
    bool contains(const QString &id) const;

    bool upsert(Appointment appointment, QString *error = nullptr);
    bool remove(const QString &id);

signals:
    void changed();

private:
    AppointmentCatalog();

    QString filePath() const;
    void reloadIfPathChanged();
    void loadFromDisk();
    void saveToDisk() const;
    int indexOf(const QString &id) const;
    static bool sanitize(Appointment *appointment, QString *error);

    QString m_dataPath;
    QVector<Appointment> m_items;
};
