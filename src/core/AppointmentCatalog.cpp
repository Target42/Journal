#include "AppointmentCatalog.h"

#include "AppSettings.h"
#include "WorkPackage.h"

#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLocale>
#include <QUuid>
#include <algorithm>

namespace {
const QString kDays[] = {
    QString(),
    QStringLiteral("Mo"),
    QStringLiteral("Di"),
    QStringLiteral("Mi"),
    QStringLiteral("Do"),
    QStringLiteral("Fr"),
    QStringLiteral("Sa"),
    QStringLiteral("So"),
};

QVector<int> normalizedWeekdays(const QVector<int> &days)
{
    QVector<int> result;
    for (int day = 1; day <= 7; ++day) {
        if (days.contains(day)) {
            result.append(day);
        }
    }
    return result;
}

QString weekdayList(const QVector<int> &days)
{
    QStringList names;
    for (int day : normalizedWeekdays(days)) {
        names << kDays[day];
    }
    return names.join(QStringLiteral(", "));
}

void sortAppointments(QVector<Appointment> &items)
{
    std::sort(items.begin(), items.end(), [](const Appointment &a, const Appointment &b) {
        if (a.kind != b.kind) {
            return a.kind == AppointmentKind::Weekly;
        }
        if (a.kind == AppointmentKind::Once && a.date != b.date) {
            return a.date < b.date;
        }
        if (a.startMinute != b.startMinute) {
            return a.startMinute < b.startMinute;
        }
        return QString::localeAwareCompare(a.title, b.title) < 0;
    });
}

Appointment appointmentFromJson(const QJsonObject &obj)
{
    Appointment apt;
    apt.id = obj.value(QStringLiteral("id")).toString().trimmed();
    apt.title = obj.value(QStringLiteral("title")).toString().trimmed();
    apt.startMinute = timeToMinute(QTime::fromString(
        obj.value(QStringLiteral("start")).toString(), QStringLiteral("HH:mm")));
    apt.endMinute = timeToMinute(QTime::fromString(
        obj.value(QStringLiteral("end")).toString(), QStringLiteral("HH:mm")));
    const QString kind = obj.value(QStringLiteral("kind")).toString().trimmed().toLower();
    if (kind == QLatin1String("weekly")) {
        apt.kind = AppointmentKind::Weekly;
        const auto days = obj.value(QStringLiteral("weekdays")).toArray();
        for (const auto &value : days) {
            const int day = value.toInt();
            if (day >= 1 && day <= 7 && !apt.weekdays.contains(day)) {
                apt.weekdays.append(day);
            }
        }
        apt.weekdays = normalizedWeekdays(apt.weekdays);
    } else {
        apt.kind = AppointmentKind::Once;
        apt.date = QDate::fromString(obj.value(QStringLiteral("date")).toString(), Qt::ISODate);
    }
    return apt;
}

QJsonObject appointmentToJson(const Appointment &apt)
{
    QJsonObject obj;
    obj.insert(QStringLiteral("id"), apt.id);
    obj.insert(QStringLiteral("title"), apt.title);
    obj.insert(QStringLiteral("start"), minuteToTime(apt.startMinute).toString(QStringLiteral("HH:mm")));
    obj.insert(QStringLiteral("end"), minuteToTime(apt.endMinute).toString(QStringLiteral("HH:mm")));
    if (apt.kind == AppointmentKind::Weekly) {
        obj.insert(QStringLiteral("kind"), QStringLiteral("weekly"));
        QJsonArray days;
        for (int day : normalizedWeekdays(apt.weekdays)) {
            days.append(day);
        }
        obj.insert(QStringLiteral("weekdays"), days);
    } else {
        obj.insert(QStringLiteral("kind"), QStringLiteral("once"));
        obj.insert(QStringLiteral("date"), apt.date.toString(Qt::ISODate));
    }
    return obj;
}
} // namespace

bool Appointment::occursOn(const QDate &day) const
{
    if (!day.isValid()) {
        return false;
    }
    if (kind == AppointmentKind::Once) {
        return date == day;
    }
    return weekdays.contains(day.dayOfWeek());
}

QString Appointment::summary() const
{
    const QString span = QStringLiteral("%1–%2")
                             .arg(minuteToTime(startMinute).toString(QStringLiteral("HH:mm")),
                                  minuteToTime(endMinute).toString(QStringLiteral("HH:mm")));
    QString when;
    if (kind == AppointmentKind::Weekly) {
        when = QStringLiteral("wöchentlich %1").arg(weekdayList(weekdays));
    } else if (date.isValid()) {
        when = QLocale().toString(date, QStringLiteral("dd.MM.yyyy"));
    }
    if (when.isEmpty()) {
        return QStringLiteral("%1  %2").arg(span, title);
    }
    return QStringLiteral("%1  %2  ·  %3").arg(span, title, when);
}

AppointmentCatalog &AppointmentCatalog::instance()
{
    static AppointmentCatalog catalog;
    return catalog;
}

AppointmentCatalog::AppointmentCatalog()
    : QObject(nullptr)
{
    connect(&AppSettings::instance(), &AppSettings::changed,
            this, &AppointmentCatalog::reloadIfPathChanged);
    reloadIfPathChanged();
}

QVector<Appointment> AppointmentCatalog::all() const
{
    return m_items;
}

QVector<Appointment> AppointmentCatalog::forDate(const QDate &date) const
{
    QVector<Appointment> result;
    for (const auto &apt : m_items) {
        if (apt.occursOn(date)) {
            result.append(apt);
        }
    }
    std::sort(result.begin(), result.end(), [](const Appointment &a, const Appointment &b) {
        if (a.startMinute != b.startMinute) {
            return a.startMinute < b.startMinute;
        }
        return QString::localeAwareCompare(a.title, b.title) < 0;
    });
    return result;
}

QStringList AppointmentCatalog::titlesForDate(const QDate &date) const
{
    QStringList titles;
    for (const auto &apt : forDate(date)) {
        if (!apt.title.isEmpty()) {
            titles << apt.title;
        }
    }
    return titles;
}

Appointment AppointmentCatalog::byId(const QString &id) const
{
    const int index = indexOf(id);
    if (index < 0) {
        return {};
    }
    return m_items[index];
}

bool AppointmentCatalog::contains(const QString &id) const
{
    return indexOf(id) >= 0;
}

bool AppointmentCatalog::sanitize(Appointment *appointment, QString *error)
{
    if (!appointment) {
        return false;
    }
    appointment->title = appointment->title.trimmed();
    if (appointment->title.isEmpty()) {
        if (error) {
            *error = QStringLiteral("Bitte einen Titel eingeben.");
        }
        return false;
    }
    appointment->startMinute = qBound(0, appointment->startMinute, 23 * 60 + 58);
    appointment->endMinute = qBound(appointment->startMinute + 1, appointment->endMinute, 24 * 60);
    if (appointment->endMinute <= appointment->startMinute) {
        if (error) {
            *error = QStringLiteral("Das Ende muss nach dem Beginn liegen.");
        }
        return false;
    }
    if (appointment->kind == AppointmentKind::Weekly) {
        appointment->weekdays = normalizedWeekdays(appointment->weekdays);
        appointment->date = QDate();
        if (appointment->weekdays.isEmpty()) {
            if (error) {
                *error = QStringLiteral("Bitte mindestens einen Wochentag wählen.");
            }
            return false;
        }
    } else {
        appointment->kind = AppointmentKind::Once;
        appointment->weekdays.clear();
        if (!appointment->date.isValid()) {
            if (error) {
                *error = QStringLiteral("Bitte ein Datum wählen.");
            }
            return false;
        }
    }
    if (appointment->id.trimmed().isEmpty()) {
        appointment->id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    }
    return true;
}

bool AppointmentCatalog::upsert(Appointment appointment, QString *error)
{
    reloadIfPathChanged();
    if (!sanitize(&appointment, error)) {
        return false;
    }

    const int index = indexOf(appointment.id);
    if (index >= 0) {
        m_items[index] = appointment;
    } else {
        m_items.append(appointment);
    }
    sortAppointments(m_items);
    saveToDisk();
    emit changed();
    return true;
}

bool AppointmentCatalog::remove(const QString &id)
{
    reloadIfPathChanged();
    const int index = indexOf(id);
    if (index < 0) {
        return false;
    }
    m_items.removeAt(index);
    saveToDisk();
    emit changed();
    return true;
}

QString AppointmentCatalog::filePath() const
{
    return QDir(AppSettings::instance().dataPath()).filePath(QStringLiteral("termine.json"));
}

void AppointmentCatalog::reloadIfPathChanged()
{
    const QString path = AppSettings::instance().dataPath();
    if (path == m_dataPath && !m_dataPath.isEmpty()) {
        return;
    }
    m_dataPath = path;
    loadFromDisk();
    emit changed();
}

void AppointmentCatalog::loadFromDisk()
{
    m_items.clear();

    QFile file(filePath());
    if (!file.exists() || !file.open(QIODevice::ReadOnly)) {
        return;
    }

    const auto doc = QJsonDocument::fromJson(file.readAll());
    const auto array = doc.object().value(QStringLiteral("appointments")).toArray();
    for (const auto &value : array) {
        Appointment apt = appointmentFromJson(value.toObject());
        if (!sanitize(&apt, nullptr) || indexOf(apt.id) >= 0) {
            continue;
        }
        m_items.append(apt);
    }
    sortAppointments(m_items);
}

void AppointmentCatalog::saveToDisk() const
{
    QDir().mkpath(AppSettings::instance().dataPath());

    QJsonArray array;
    for (const auto &apt : m_items) {
        array.append(appointmentToJson(apt));
    }

    QJsonObject root;
    root.insert(QStringLiteral("appointments"), array);

    QFile file(filePath());
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        return;
    }
    file.write(QJsonDocument(root).toJson(QJsonDocument::Indented));
}

int AppointmentCatalog::indexOf(const QString &id) const
{
    const QString trimmed = id.trimmed();
    if (trimmed.isEmpty()) {
        return -1;
    }
    for (int i = 0; i < m_items.size(); ++i) {
        if (m_items[i].id == trimmed) {
            return i;
        }
    }
    return -1;
}
