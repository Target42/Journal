#pragma once

#include <QDate>
#include <QHash>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QVector>

class QNetworkAccessManager;

class CalendarService : public QObject
{
    Q_OBJECT

public:
    static CalendarService &instance();

    /** Lädt Feiertage/Ferien für das Jahr aus lokalen JSON-Dateien. */
    void ensureYearLoaded(int year);

    /** Lädt das Jahr erneut aus dem Datenordner (z. B. nach Pfadwechsel). */
    void reloadYear(int year);

    /** Lädt Feiertage von der API und speichert sie lokal. */
    void downloadPublicHolidays(int year);

    /** Lädt Feiertage mehrerer Jahre nacheinander (ein Abschluss-Signal). */
    void downloadPublicHolidayYears(const QVector<int> &years);

    /** Lädt Schulferien von der API und speichert sie lokal. */
    void downloadSchoolHolidays(int year);

    QString publicHolidayFilePath(int year) const;
    QString schoolHolidayFilePath(int year) const;

    bool publicHolidaysFileExists(int year) const;
    bool hasPublicHolidays(int year) const;

    bool isPublicHoliday(const QDate &date) const;
    QString publicHolidayName(const QDate &date) const;

    bool isSchoolHoliday(const QDate &date) const;
    QString schoolHolidayName(const QDate &date) const;

signals:
    void yearDataChanged(int year);
    void downloadFinished(const QString &kind, int year, bool ok, const QString &message);
    void downloadProgress(const QString &kind, int year, int current, int total);

private:
    explicit CalendarService(QObject *parent = nullptr);

    QString stateCode() const;
    QString calendarDir() const;
    bool ensureCalendarDir() const;

    bool loadPublicHolidaysFromDisk(int year);
    bool loadSchoolHolidaysFromDisk(int year);

    void applyPublicHolidaysJson(int year, const QByteArray &json);
    void applySchoolHolidaysJson(int year, const QByteArray &json);

    bool saveJsonFile(const QString &path, const QByteArray &json, QString *error) const;

    void startPublicHolidayDownload(int year, bool batch);
    void startNextHolidayYearDownload();
    void finishHolidayYearBatch();

    struct YearCache {
        QHash<QDate, QString> publicHolidays;
        QHash<QDate, QString> schoolHolidays;
        bool publicTried = false;
        bool schoolTried = false;
    };

    QNetworkAccessManager *m_network = nullptr;
    mutable QHash<int, YearCache> m_years;
    QString m_loadedState;

    QVector<int> m_holidayYearQueue;
    int m_holidayYearTotal = 0;
    int m_holidayYearOk = 0;
    QStringList m_holidayYearErrors;
    bool m_holidayYearBatch = false;
};
