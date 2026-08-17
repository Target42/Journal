#include "CalendarService.h"

#include "AppSettings.h"

#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QList>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QSet>
#include <QUrl>

#include <algorithm>

CalendarService &CalendarService::instance()
{
    static CalendarService service;
    return service;
}

CalendarService::CalendarService(QObject *parent)
    : QObject(parent)
    , m_network(new QNetworkAccessManager(this))
    , m_loadedState(stateCode())
{
    connect(&AppSettings::instance(), &AppSettings::changed, this, [this]() {
        const QString state = stateCode();
        if (state == m_loadedState) {
            return;
        }
        m_loadedState = state;
        const QList<int> years = m_years.keys();
        for (int year : years) {
            reloadYear(year);
        }
    });
}

QString CalendarService::stateCode() const
{
    return AppSettings::instance().stateCode().toUpper();
}

QString CalendarService::calendarDir() const
{
    return QDir(AppSettings::instance().dataPath()).filePath(QStringLiteral("kalender"));
}

bool CalendarService::ensureCalendarDir() const
{
    QDir dir(calendarDir());
    if (dir.exists()) {
        return true;
    }
    return QDir().mkpath(dir.absolutePath());
}

QString CalendarService::publicHolidayFilePath(int year) const
{
    return QDir(calendarDir()).filePath(
        QStringLiteral("feiertage_%1_%2.json").arg(stateCode()).arg(year));
}

QString CalendarService::schoolHolidayFilePath(int year) const
{
    return QDir(calendarDir()).filePath(
        QStringLiteral("ferien_%1_%2.json").arg(stateCode()).arg(year));
}

bool CalendarService::publicHolidaysFileExists(int year) const
{
    return QFile::exists(publicHolidayFilePath(year));
}

bool CalendarService::hasPublicHolidays(int year) const
{
    const auto it = m_years.constFind(year);
    if (it != m_years.cend() && !it->publicHolidays.isEmpty()) {
        return true;
    }
    return publicHolidaysFileExists(year);
}

void CalendarService::ensureYearLoaded(int year)
{
    auto &cache = m_years[year];
    bool changed = false;

    if (!cache.publicTried) {
        cache.publicTried = true;
        changed = loadPublicHolidaysFromDisk(year) || changed;
    }
    if (!cache.schoolTried) {
        cache.schoolTried = true;
        changed = loadSchoolHolidaysFromDisk(year) || changed;
    }

    if (changed) {
        emit yearDataChanged(year);
    }
}

void CalendarService::reloadYear(int year)
{
    auto &cache = m_years[year];
    cache.publicHolidays.clear();
    cache.schoolHolidays.clear();
    cache.publicTried = false;
    cache.schoolTried = false;
    ensureYearLoaded(year);
    emit yearDataChanged(year);
}

bool CalendarService::loadPublicHolidaysFromDisk(int year)
{
    QFile file(publicHolidayFilePath(year));
    if (!file.exists() || !file.open(QIODevice::ReadOnly)) {
        return false;
    }
    applyPublicHolidaysJson(year, file.readAll());
    return true;
}

bool CalendarService::loadSchoolHolidaysFromDisk(int year)
{
    QFile file(schoolHolidayFilePath(year));
    if (!file.exists() || !file.open(QIODevice::ReadOnly)) {
        return false;
    }
    applySchoolHolidaysJson(year, file.readAll());
    return true;
}

void CalendarService::applyPublicHolidaysJson(int year, const QByteArray &json)
{
    auto &cache = m_years[year];
    cache.publicHolidays.clear();

    const auto doc = QJsonDocument::fromJson(json);
    const auto feiertage = doc.object().value(QStringLiteral("feiertage")).toArray();
    for (const auto &value : feiertage) {
        const auto obj = value.toObject();
        const QDate date = QDate::fromString(obj.value(QStringLiteral("date")).toString(),
                                             Qt::ISODate);
        const QString name = obj.value(QStringLiteral("fname")).toString();
        if (date.isValid()) {
            cache.publicHolidays.insert(date, name);
        }
    }
}

static QString schoolHolidayNameFromObject(const QJsonObject &obj)
{
    // OpenHolidays: "name": [ { "language": "DE", "text": "Osterferien" } ]
    const auto names = obj.value(QStringLiteral("name"));
    if (names.isArray()) {
        for (const auto &entry : names.toArray()) {
            const auto nameObj = entry.toObject();
            if (nameObj.value(QStringLiteral("language")).toString().compare(
                    QLatin1String("DE"), Qt::CaseInsensitive)
                == 0) {
                return nameObj.value(QStringLiteral("text")).toString();
            }
        }
        if (!names.toArray().isEmpty()) {
            return names.toArray().first().toObject().value(QStringLiteral("text")).toString();
        }
    }

    // Älteres Format (ferien-api): "name": "osterferien niedersachsen 2025"
    QString name = names.toString();
    if (name.isEmpty()) {
        return {};
    }
    if (const int space = name.indexOf(QLatin1Char(' ')); space > 0) {
        name = name.left(space);
    }
    if (!name.isEmpty()) {
        name[0] = name[0].toUpper();
    }
    return name;
}

void CalendarService::applySchoolHolidaysJson(int year, const QByteArray &json)
{
    auto &cache = m_years[year];
    cache.schoolHolidays.clear();

    const auto doc = QJsonDocument::fromJson(json);
    const auto holidays = doc.isArray() ? doc.array() : QJsonArray();
    for (const auto &value : holidays) {
        const auto obj = value.toObject();

        QDate start = QDate::fromString(obj.value(QStringLiteral("startDate")).toString(),
                                        Qt::ISODate);
        QDate end = QDate::fromString(obj.value(QStringLiteral("endDate")).toString(), Qt::ISODate);
        if (!start.isValid()) {
            start = QDate::fromString(obj.value(QStringLiteral("start")).toString(), Qt::ISODate);
        }
        if (!end.isValid()) {
            end = QDate::fromString(obj.value(QStringLiteral("end")).toString(), Qt::ISODate);
        }

        const QString name = schoolHolidayNameFromObject(obj);
        if (!start.isValid() || !end.isValid() || name.isEmpty()) {
            continue;
        }

        for (QDate day = start; day <= end; day = day.addDays(1)) {
            if (day.year() != year) {
                continue;
            }
            if (!cache.schoolHolidays.contains(day)) {
                cache.schoolHolidays.insert(day, name);
            }
        }
    }
}

bool CalendarService::saveJsonFile(const QString &path, const QByteArray &json, QString *error) const
{
    if (!ensureCalendarDir()) {
        if (error) {
            *error = QStringLiteral("Kalender-Ordner konnte nicht angelegt werden.");
        }
        return false;
    }

    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        if (error) {
            *error = QStringLiteral("Datei konnte nicht geschrieben werden:\n%1").arg(path);
        }
        return false;
    }
    if (file.write(json) != json.size()) {
        if (error) {
            *error = QStringLiteral("Schreiben der Datei fehlgeschlagen:\n%1").arg(path);
        }
        return false;
    }
    return true;
}

void CalendarService::downloadPublicHolidays(int year)
{
    startPublicHolidayDownload(year, false);
}

void CalendarService::downloadPublicHolidayYears(const QVector<int> &years)
{
    if (m_holidayYearBatch) {
        emit downloadFinished(
            QStringLiteral("feiertage-jahre"), 0, false,
            QStringLiteral("Es läuft bereits ein Feiertags-Download."));
        return;
    }

    QVector<int> unique;
    QSet<int> seen;
    for (int year : years) {
        if (year < 1970 || year > 2100 || seen.contains(year)) {
            continue;
        }
        seen.insert(year);
        unique.append(year);
    }
    std::sort(unique.begin(), unique.end());

    if (unique.isEmpty()) {
        emit downloadFinished(
            QStringLiteral("feiertage-jahre"), 0, true,
            QStringLiteral("Alle benötigten Feiertage liegen bereits vor."));
        return;
    }

    m_holidayYearQueue = unique;
    m_holidayYearTotal = unique.size();
    m_holidayYearOk = 0;
    m_holidayYearErrors.clear();
    m_holidayYearBatch = true;
    startNextHolidayYearDownload();
}

void CalendarService::startNextHolidayYearDownload()
{
    if (m_holidayYearQueue.isEmpty()) {
        finishHolidayYearBatch();
        return;
    }

    const int year = m_holidayYearQueue.takeFirst();
    const int current = m_holidayYearTotal - m_holidayYearQueue.size();
    emit downloadProgress(QStringLiteral("feiertage"), year, current, m_holidayYearTotal);
    startPublicHolidayDownload(year, true);
}

void CalendarService::finishHolidayYearBatch()
{
    m_holidayYearBatch = false;
    const int total = m_holidayYearTotal;
    const int ok = m_holidayYearOk;
    const QStringList errors = m_holidayYearErrors;
    m_holidayYearTotal = 0;
    m_holidayYearOk = 0;
    m_holidayYearErrors.clear();

    if (errors.isEmpty()) {
        emit downloadFinished(
            QStringLiteral("feiertage-jahre"), 0, true,
            QStringLiteral("Feiertage für %1 %2 gespeichert.")
                .arg(total)
                .arg(total == 1 ? QStringLiteral("Jahr") : QStringLiteral("Jahre")));
        return;
    }

    const bool partial = ok > 0;
    emit downloadFinished(
        QStringLiteral("feiertage-jahre"), 0, partial,
        QStringLiteral("%1 von %2 Jahren gespeichert.\n%3")
            .arg(ok)
            .arg(total)
            .arg(errors.join(QLatin1Char('\n'))));
}

void CalendarService::startPublicHolidayDownload(int year, bool batch)
{
    const QString state = stateCode().toLower();
    const QUrl url(QStringLiteral("https://get.api-feiertage.de?years=%1&states=%2")
                       .arg(year)
                       .arg(state));

    auto *reply = m_network->get(QNetworkRequest(url));
    connect(reply, &QNetworkReply::finished, this, [this, reply, year, batch]() {
        reply->deleteLater();

        bool ok = false;
        QString message;

        if (reply->error() != QNetworkReply::NoError) {
            message = QStringLiteral("Download %1 fehlgeschlagen:\n%2")
                          .arg(year)
                          .arg(reply->errorString());
        } else {
            const QByteArray json = reply->readAll();
            const auto doc = QJsonDocument::fromJson(json);
            if (!doc.isObject()
                || doc.object().value(QStringLiteral("status")).toString()
                       != QLatin1String("success")) {
                message = QStringLiteral("Ungültige Antwort der Feiertags-API für %1.").arg(year);
            } else {
                QString error;
                const QString path = publicHolidayFilePath(year);
                if (!saveJsonFile(path, json, &error)) {
                    message = error;
                } else {
                    applyPublicHolidaysJson(year, json);
                    m_years[year].publicTried = true;
                    emit yearDataChanged(year);
                    ok = true;
                    message = QStringLiteral("Feiertage %1 gespeichert:\n%2").arg(year).arg(path);
                }
            }
        }

        if (batch) {
            if (ok) {
                ++m_holidayYearOk;
            } else {
                m_holidayYearErrors.append(message);
            }
            startNextHolidayYearDownload();
            return;
        }

        emit downloadFinished(QStringLiteral("feiertage"), year, ok, message);
    });
}

void CalendarService::downloadSchoolHolidays(int year)
{
    // OpenHolidays liefert aktuelle Schulferien inkl. 2026+; die alte ferien-api oft nicht.
    const QUrl url(QStringLiteral(
                       "https://openholidaysapi.org/SchoolHolidays"
                       "?countryIsoCode=DE&subdivisionCode=DE-%1&languageIsoCode=DE"
                       "&validFrom=%2-01-01&validTo=%2-12-31")
                       .arg(stateCode(), QString::number(year)));

    QNetworkRequest request(url);
    request.setRawHeader("Accept", "application/json");

    auto *reply = m_network->get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply, year]() {
        reply->deleteLater();

        if (reply->error() != QNetworkReply::NoError) {
            emit downloadFinished(QStringLiteral("ferien"), year, false,
                                  QStringLiteral("Download fehlgeschlagen:\n%1")
                                      .arg(reply->errorString()));
            return;
        }

        const QByteArray json = reply->readAll();
        const auto doc = QJsonDocument::fromJson(json);
        if (!doc.isArray()) {
            emit downloadFinished(QStringLiteral("ferien"), year, false,
                                  QStringLiteral("Ungültige Antwort der Ferien-API."));
            return;
        }
        if (doc.array().isEmpty()) {
            emit downloadFinished(
                QStringLiteral("ferien"), year, false,
                QStringLiteral("Für %1 sind bei der Ferien-API keine Einträge vorhanden.")
                    .arg(year));
            return;
        }

        QString error;
        const QString path = schoolHolidayFilePath(year);
        if (!saveJsonFile(path, json, &error)) {
            emit downloadFinished(QStringLiteral("ferien"), year, false, error);
            return;
        }

        applySchoolHolidaysJson(year, json);
        m_years[year].schoolTried = true;
        emit yearDataChanged(year);
        emit downloadFinished(
            QStringLiteral("ferien"), year, true,
            QStringLiteral("Ferien %1 gespeichert (%2 Zeiträume):\n%3")
                .arg(year)
                .arg(doc.array().size())
                .arg(path));
    });
}

bool CalendarService::isPublicHoliday(const QDate &date) const
{
    const auto it = m_years.constFind(date.year());
    if (it == m_years.cend()) {
        return false;
    }
    return it->publicHolidays.contains(date);
}

QString CalendarService::publicHolidayName(const QDate &date) const
{
    const auto it = m_years.constFind(date.year());
    if (it == m_years.cend()) {
        return {};
    }
    return it->publicHolidays.value(date);
}

bool CalendarService::isSchoolHoliday(const QDate &date) const
{
    const auto it = m_years.constFind(date.year());
    if (it == m_years.cend()) {
        return false;
    }
    return it->schoolHolidays.contains(date);
}

QString CalendarService::schoolHolidayName(const QDate &date) const
{
    const auto it = m_years.constFind(date.year());
    if (it == m_years.cend()) {
        return {};
    }
    return it->schoolHolidays.value(date);
}
