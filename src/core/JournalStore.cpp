#include "JournalStore.h"

#include "AppSettings.h"
#include "BreakRules.h"
#include "TitleCatalog.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSet>
#include <QTime>
#include <QUuid>
#include <algorithm>

namespace {
WorkPackage packageFromJson(const QJsonObject &obj)
{
    WorkPackage pkg;
    pkg.id = obj.value(QStringLiteral("id")).toString();
    pkg.title = obj.value(QStringLiteral("title")).toString();
    pkg.details = obj.value(QStringLiteral("details")).toString();
    pkg.start = QTime::fromString(obj.value(QStringLiteral("start")).toString(),
                                  QStringLiteral("HH:mm"));
    pkg.end = QTime::fromString(obj.value(QStringLiteral("end")).toString(),
                                QStringLiteral("HH:mm"));
    pkg.active = obj.value(QStringLiteral("active")).toBool(false);
    return pkg;
}

QJsonObject packageToJson(const WorkPackage &pkg)
{
    QJsonObject obj;
    obj.insert(QStringLiteral("id"), pkg.id);
    obj.insert(QStringLiteral("title"), pkg.title);
    obj.insert(QStringLiteral("details"), pkg.details);
    obj.insert(QStringLiteral("start"), pkg.start.toString(QStringLiteral("HH:mm")));
    obj.insert(QStringLiteral("end"), pkg.end.toString(QStringLiteral("HH:mm")));
    obj.insert(QStringLiteral("active"), pkg.active);
    return obj;
}

void sortByStart(QVector<WorkPackage> &packages)
{
    std::sort(packages.begin(), packages.end(), [](const WorkPackage &a, const WorkPackage &b) {
        return a.startMinute() < b.startMinute();
    });
}
} // namespace

JournalStore &JournalStore::instance()
{
    static JournalStore store;
    return store;
}

JournalStore::JournalStore()
    : QObject(nullptr)
{
    m_tick.setInterval(60 * 1000);
    connect(&m_tick, &QTimer::timeout, this, [this]() {
        persistActivePackagesToday();
    });
    m_tick.start();

    connect(&AppSettings::instance(), &AppSettings::changed,
            this, &JournalStore::reloadIfPathChanged);
    reloadIfPathChanged();
}

QString JournalStore::monthKey(int year, int month)
{
    return QStringLiteral("%1-%2").arg(year).arg(month, 2, 10, QLatin1Char('0'));
}

QString JournalStore::monthFilePath(int year, int month) const
{
    const QString dir =
        QDir(AppSettings::instance().dataPath()).filePath(QStringLiteral("monate"));
    return QDir(dir).filePath(monthKey(year, month) + QStringLiteral(".json"));
}

void JournalStore::reloadIfPathChanged()
{
    const QString path = AppSettings::instance().dataPath();
    if (path == m_dataPath && !m_dataPath.isEmpty()) {
        return;
    }
    m_dataPath = path;
    m_months.clear();
    emit dataReloaded();
    emit changed();
}

void JournalStore::ensureMonthLoaded(int year, int month)
{
    reloadIfPathChanged();
    const QString key = monthKey(year, month);
    if (m_months.contains(key) && m_months[key].loaded) {
        return;
    }
    loadMonth(year, month);
}

JournalStore::MonthData &JournalStore::monthData(int year, int month)
{
    ensureMonthLoaded(year, month);
    return m_months[monthKey(year, month)];
}

const JournalStore::MonthData *JournalStore::monthDataIfLoaded(int year, int month) const
{
    const auto it = m_months.constFind(monthKey(year, month));
    if (it == m_months.cend() || !it->loaded) {
        return nullptr;
    }
    return &*it;
}

void JournalStore::loadMonth(int year, int month)
{
    MonthData data;
    data.year = year;
    data.month = month;
    data.loaded = true;

    QFile file(monthFilePath(year, month));
    if (file.exists() && file.open(QIODevice::ReadOnly)) {
        const auto doc = QJsonDocument::fromJson(file.readAll());
        const auto daysObj = doc.object().value(QStringLiteral("days")).toObject();
        for (auto it = daysObj.begin(); it != daysObj.end(); ++it) {
            const QDate date = QDate::fromString(it.key(), Qt::ISODate);
            if (!date.isValid() || date.year() != year || date.month() != month) {
                continue;
            }

            QVector<WorkPackage> packages;
            const auto array = it.value().toArray();
            for (const auto &value : array) {
                WorkPackage pkg = packageFromJson(value.toObject());
                if (pkg.id.isEmpty() || !pkg.start.isValid()) {
                    continue;
                }
                if (pkg.active && date != QDate::currentDate()) {
                    pkg.active = false;
                }
                packages.append(pkg);
            }
            sortByStart(packages);
            data.days.insert(date.day(), packages);
        }

        const auto absencesObj = doc.object().value(QStringLiteral("absences")).toObject();
        for (auto it = absencesObj.begin(); it != absencesObj.end(); ++it) {
            const QDate date = QDate::fromString(it.key(), Qt::ISODate);
            if (!date.isValid() || date.year() != year || date.month() != month) {
                continue;
            }
            const QJsonObject obj = it.value().toObject();
            const Absence absence =
                Absence::fromJson(obj.value(QStringLiteral("type")).toString(),
                                  obj.value(QStringLiteral("fraction")).toDouble(1.0));
            if (absence.isSet()) {
                data.absences.insert(date.day(), absence);
            }
        }

        const auto boundsObj = doc.object().value(QStringLiteral("dayBounds")).toObject();
        for (auto it = boundsObj.begin(); it != boundsObj.end(); ++it) {
            const QDate date = QDate::fromString(it.key(), Qt::ISODate);
            if (!date.isValid() || date.year() != year || date.month() != month) {
                continue;
            }
            const QJsonObject obj = it.value().toObject();
            const QTime start = QTime::fromString(obj.value(QStringLiteral("start")).toString(),
                                                  QStringLiteral("HH:mm"));
            const QTime end = QTime::fromString(obj.value(QStringLiteral("end")).toString(),
                                                QStringLiteral("HH:mm"));
            if (!start.isValid() || !end.isValid() || timeToMinute(start) >= timeToMinute(end)) {
                continue;
            }
            data.dayBounds.insert(date.day(),
                                  sanitizedDayBounds(timeToMinute(start), timeToMinute(end), true));
        }
    }

    m_months.insert(monthKey(year, month), data);
}

bool JournalStore::saveMonth(int year, int month, QString *error)
{
    const QString path = monthFilePath(year, month);
    QDir().mkpath(QFileInfo(path).absolutePath());

    const MonthData &data = m_months[monthKey(year, month)];
    QJsonObject daysObj;
    for (auto it = data.days.constBegin(); it != data.days.constEnd(); ++it) {
        if (it.value().isEmpty()) {
            continue;
        }
        const QDate date(year, month, it.key());
        QJsonArray array;
        for (const auto &pkg : it.value()) {
            array.append(packageToJson(pkg));
        }
        daysObj.insert(date.toString(Qt::ISODate), array);
    }

    QJsonObject absencesObj;
    for (auto it = data.absences.constBegin(); it != data.absences.constEnd(); ++it) {
        if (!it.value().isSet()) {
            continue;
        }
        const QDate date(year, month, it.key());
        QJsonObject obj;
        obj.insert(QStringLiteral("type"), it.value().typeString());
        obj.insert(QStringLiteral("fraction"), it.value().fraction);
        absencesObj.insert(date.toString(Qt::ISODate), obj);
    }

    QJsonObject root;
    root.insert(QStringLiteral("year"), year);
    root.insert(QStringLiteral("month"), month);
    root.insert(QStringLiteral("days"), daysObj);
    if (!absencesObj.isEmpty()) {
        root.insert(QStringLiteral("absences"), absencesObj);
    }

    QJsonObject boundsObj;
    for (auto it = data.dayBounds.constBegin(); it != data.dayBounds.constEnd(); ++it) {
        const DayBounds bounds = it.value();
        if (!bounds.custom) {
            continue;
        }
        const QDate date(year, month, it.key());
        QJsonObject obj;
        obj.insert(QStringLiteral("start"),
                   minuteToTime(bounds.startMinute).toString(QStringLiteral("HH:mm")));
        obj.insert(QStringLiteral("end"),
                   minuteToTime(bounds.endMinute).toString(QStringLiteral("HH:mm")));
        boundsObj.insert(date.toString(Qt::ISODate), obj);
    }
    if (!boundsObj.isEmpty()) {
        root.insert(QStringLiteral("dayBounds"), boundsObj);
    }

    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        if (error) {
            *error = QStringLiteral("Monatdatei konnte nicht geschrieben werden.");
        }
        return false;
    }
    file.write(QJsonDocument(root).toJson(QJsonDocument::Indented));
    return true;
}

QVector<WorkPackage> JournalStore::packagesForDate(const QDate &date)
{
    if (!date.isValid()) {
        return {};
    }
    return monthData(date.year(), date.month()).days.value(date.day());
}

WorkPackage JournalStore::packageById(const QDate &date, const QString &id)
{
    const auto packages = packagesForDate(date);
    for (const auto &pkg : packages) {
        if (pkg.id == id) {
            return pkg;
        }
    }
    return {};
}

bool JournalStore::startMinuteTaken(const QDate &date, int startMinute, const QString &excludeId)
{
    if (!date.isValid()) {
        return false;
    }
    for (const auto &pkg : packagesForDate(date)) {
        if (pkg.id != excludeId && pkg.startMinute() == startMinute) {
            return true;
        }
    }
    return false;
}

bool JournalStore::savePackage(const QDate &date, WorkPackage package, QString *error)
{
    if (!date.isValid() || package.id.isEmpty() || package.title.trimmed().isEmpty()
        || !package.start.isValid()) {
        if (error) {
            *error = QStringLiteral("Ungültiges Arbeitspaket.");
        }
        return false;
    }

    package.title = TitleCatalog::instance().canonicalTitle(package.title);
    if (package.active && date != QDate::currentDate()) {
        package.active = false;
    }
    if (package.active) {
        package.end = QTime::currentTime();
        package.end = minuteToTime(timeToMinute(package.end));
    }

    MonthData &data = monthData(date.year(), date.month());
    auto packages = data.days.value(date.day());

    for (const auto &pkg : packages) {
        if (pkg.id != package.id && pkg.startMinute() == package.startMinute()) {
            if (error) {
                *error = QStringLiteral(
                    "Ein anderes Arbeitspaket beginnt bereits in derselben Minute.");
            }
            return false;
        }
    }

    bool replaced = false;
    for (auto &pkg : packages) {
        if (pkg.id == package.id) {
            pkg = package;
            replaced = true;
            break;
        }
    }
    if (!replaced) {
        packages.append(package);
    }

    sortByStart(packages);
    data.days.insert(date.day(), packages);

    if (!saveMonth(date.year(), date.month(), error)) {
        return false;
    }
    emit changed();
    emit packagesChanged(date);
    return true;
}

bool JournalStore::renameTitle(const QString &from, const QString &to, QString *error)
{
    const QString oldTitle = from.trimmed();
    const QString newTitle = to.trimmed();
    if (oldTitle.isEmpty() || newTitle.isEmpty()) {
        if (error) {
            *error = QStringLiteral("Titel darf nicht leer sein.");
        }
        return false;
    }

    reloadIfPathChanged();

    const QDir monthsDir(
        QDir(AppSettings::instance().dataPath()).filePath(QStringLiteral("monate")));
    const QStringList files = monthsDir.entryList({QStringLiteral("*.json")}, QDir::Files);

    bool anyChanged = false;
    for (const QString &name : files) {
        const QString base = QFileInfo(name).completeBaseName();
        const auto parts = base.split(QLatin1Char('-'));
        if (parts.size() != 2) {
            continue;
        }
        bool yearOk = false;
        bool monthOk = false;
        const int year = parts.at(0).toInt(&yearOk);
        const int month = parts.at(1).toInt(&monthOk);
        if (!yearOk || !monthOk || year < 1970 || year > 2100 || month < 1 || month > 12) {
            continue;
        }

        MonthData &data = monthData(year, month);
        bool monthChanged = false;
        for (auto it = data.days.begin(); it != data.days.end(); ++it) {
            for (auto &pkg : it.value()) {
                if (pkg.title.compare(oldTitle, Qt::CaseInsensitive) == 0
                    && pkg.title != newTitle) {
                    pkg.title = newTitle;
                    monthChanged = true;
                }
            }
        }
        if (!monthChanged) {
            continue;
        }
        if (!saveMonth(year, month, error)) {
            return false;
        }
        anyChanged = true;
    }

    if (anyChanged) {
        emit changed();
    }
    return true;
}

bool JournalStore::removePackage(const QDate &date, const QString &id, QString *error)
{
    if (!date.isValid() || id.isEmpty()) {
        return false;
    }

    MonthData &data = monthData(date.year(), date.month());
    auto packages = data.days.value(date.day());
    const auto before = packages.size();
    packages.erase(std::remove_if(packages.begin(), packages.end(),
                                  [&id](const WorkPackage &pkg) { return pkg.id == id; }),
                   packages.end());
    if (packages.size() == before) {
        return false;
    }

    if (packages.isEmpty()) {
        data.days.remove(date.day());
    } else {
        data.days.insert(date.day(), packages);
    }

    if (!saveMonth(date.year(), date.month(), error)) {
        return false;
    }
    emit changed();
    emit packagesChanged(date);
    return true;
}

QVector<PauseInterval> JournalStore::pausesForDate(const QDate &date)
{
    QVector<PauseInterval> pauses;
    const QVector<char> covered = fullDayCoverage(date);
    int first = -1;
    int last = -1;
    for (int i = 0; i < covered.size(); ++i) {
        if (covered[i]) {
            if (first < 0) {
                first = i;
            }
            last = i;
        }
    }
    if (first < 0) {
        return pauses;
    }

    int run = -1;
    for (int i = first; i <= last; ++i) {
        if (!covered[i]) {
            if (run < 0) {
                run = i;
            }
        } else if (run >= 0) {
            pauses.append({run, i});
            run = -1;
        }
    }
    return pauses;
}

PauseInterval JournalStore::pauseCoveringRange(const QDate &date, int startMinute, int endMinute)
{
    if (!date.isValid() || endMinute <= startMinute) {
        return {};
    }
    for (const auto &pause : pausesForDate(date)) {
        if (pause.startMinute <= startMinute && pause.endMinute >= endMinute) {
            return pause;
        }
    }
    return {};
}

bool JournalStore::suggestPause(const QDate &date, int atMinute, int *startMinute, int *endMinute,
                               bool *existingGap)
{
    atMinute = qBound(0, atMinute, 24 * 60 - 1);
    const auto setRange = [&](int start, int end, bool existing) {
        if (startMinute) {
            *startMinute = start;
        }
        if (endMinute) {
            *endMinute = end;
        }
        if (existingGap) {
            *existingGap = existing;
        }
        return end > start;
    };

    for (const auto &pause : pausesForDate(date)) {
        if (atMinute >= pause.startMinute && atMinute < pause.endMinute) {
            return setRange(pause.startMinute, pause.endMinute, true);
        }
    }

    const DayBounds bounds = boundsForDate(date);
    const BreakAdjustment breaks = breakAdjustmentForDate(date);
    const int idx = atMinute - bounds.startMinute;
    if (idx >= 0 && idx < breaks.autoPause.size() && breaks.autoPause[idx]) {
        int from = idx;
        int to = idx + 1;
        while (from > 0 && breaks.autoPause[from - 1]) {
            --from;
        }
        while (to < breaks.autoPause.size() && breaks.autoPause[to]) {
            ++to;
        }
        return setRange(bounds.startMinute + from, bounds.startMinute + to, false);
    }

    for (const auto &preset : AppSettings::instance().pausePresets()) {
        if (atMinute >= preset.startMinute && atMinute < preset.endMinute) {
            return setRange(preset.startMinute, preset.endMinute, false);
        }
    }

    int start = atMinute;
    int end = qMin(atMinute + kPauseAfterSixHoursMinutes, 24 * 60);
    for (const auto &pkg : packagesForDate(date)) {
        const int pkgStart = pkg.startMinute();
        const int pkgEnd = pkg.endMinute(date);
        if (atMinute < pkgStart || atMinute >= pkgEnd) {
            continue;
        }
        const int innerFirst = pkgStart + 1;
        const int innerLast = pkgEnd - 1;
        if (innerLast >= innerFirst) {
            start = qBound(innerFirst, atMinute, innerLast);
            end = qMin(innerLast, start + kPauseAfterSixHoursMinutes);
            if (end <= start) {
                end = qMin(pkgEnd, start + 1);
            }
        } else {
            start = pkgStart;
            end = qMin(24 * 60, pkgStart + kPauseAfterSixHoursMinutes);
        }
        break;
    }
    return setRange(start, end, false);
}

bool JournalStore::applyPause(const QDate &date, int startMinute, int endMinute, QString *error)
{
    if (!date.isValid()) {
        if (error) {
            *error = QStringLiteral("Ungültiges Datum.");
        }
        return false;
    }
    startMinute = qBound(0, startMinute, 23 * 60 + 58);
    endMinute = qBound(startMinute + 1, endMinute, 24 * 60);
    if (endMinute <= startMinute) {
        if (error) {
            *error = QStringLiteral("Das Pausenende muss nach dem Beginn liegen.");
        }
        return false;
    }

    MonthData &data = monthData(date.year(), date.month());
    const auto original = data.days.value(date.day());
    QVector<WorkPackage> result;
    result.reserve(original.size() + 2);
    bool cutAny = false;

    for (const auto &pkg : original) {
        const int pkgStart = pkg.startMinute();
        const int pkgEnd = pkg.endMinute(date);
        if (pkgEnd <= startMinute || pkgStart >= endMinute) {
            result.append(pkg);
            continue;
        }

        cutAny = true;
        if (pkgStart < startMinute) {
            WorkPackage left = pkg;
            left.end = minuteToTime(startMinute);
            left.active = false;
            result.append(left);
        }
        if (pkgEnd > endMinute) {
            WorkPackage right = pkg;
            if (pkgStart < startMinute) {
                right.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
            }
            right.start = minuteToTime(endMinute);
            result.append(right);
        }
    }

    if (!cutAny) {
        if (error) {
            *error = QStringLiteral("In diesem Zeitraum liegt kein Arbeitspaket.");
        }
        return false;
    }

    QSet<int> starts;
    for (auto &pkg : result) {
        int start = pkg.startMinute();
        while (starts.contains(start) && start < 23 * 60 + 58) {
            ++start;
        }
        if (starts.contains(start)) {
            if (error) {
                *error = QStringLiteral(
                    "Ein anderes Arbeitspaket beginnt bereits in derselben Minute.");
            }
            return false;
        }
        if (start != pkg.startMinute()) {
            pkg.start = minuteToTime(start);
        }
        starts.insert(start);
    }

    sortByStart(result);
    if (result.isEmpty()) {
        data.days.remove(date.day());
    } else {
        data.days.insert(date.day(), result);
    }

    if (!saveMonth(date.year(), date.month(), error)) {
        return false;
    }
    emit changed();
    emit packagesChanged(date);
    return true;
}

bool JournalStore::closePause(const QDate &date, int startMinute, int endMinute, QString *error)
{
    if (!date.isValid() || endMinute <= startMinute) {
        if (error) {
            *error = QStringLiteral("Ungültige Pause.");
        }
        return false;
    }

    MonthData &data = monthData(date.year(), date.month());
    auto packages = data.days.value(date.day());
    int leftIdx = -1;
    int rightIdx = -1;
    for (int i = 0; i < packages.size(); ++i) {
        if (packages[i].endMinute(date) == startMinute) {
            if (leftIdx < 0 || packages[i].startMinute() > packages[leftIdx].startMinute()) {
                leftIdx = i;
            }
        }
        if (packages[i].startMinute() == endMinute) {
            if (rightIdx < 0 || packages[i].startMinute() < packages[rightIdx].startMinute()) {
                rightIdx = i;
            }
        }
    }

    if (leftIdx < 0 && rightIdx < 0) {
        if (error) {
            *error = QStringLiteral("Keine angrenzenden Arbeitspakete für diese Pause.");
        }
        return false;
    }

    if (leftIdx >= 0 && rightIdx >= 0
        && packages[leftIdx].title.compare(packages[rightIdx].title, Qt::CaseInsensitive) == 0) {
        packages[leftIdx].end = minuteToTime(packages[rightIdx].endMinute(date));
        packages[leftIdx].active = packages[leftIdx].active || packages[rightIdx].active;
        if (packages[leftIdx].details.isEmpty()) {
            packages[leftIdx].details = packages[rightIdx].details;
        } else if (!packages[rightIdx].details.isEmpty()
                   && packages[leftIdx].details != packages[rightIdx].details) {
            packages[leftIdx].details += QLatin1Char('\n') + packages[rightIdx].details;
        }
        packages.removeAt(rightIdx);
    } else if (leftIdx >= 0) {
        packages[leftIdx].end = minuteToTime(endMinute);
        packages[leftIdx].active = false;
    } else if (startMinuteTaken(date, startMinute, packages[rightIdx].id)) {
        if (error) {
            *error = QStringLiteral(
                "Ein anderes Arbeitspaket beginnt bereits in derselben Minute.");
        }
        return false;
    } else {
        packages[rightIdx].start = minuteToTime(startMinute);
    }

    sortByStart(packages);
    data.days.insert(date.day(), packages);
    if (!saveMonth(date.year(), date.month(), error)) {
        return false;
    }
    emit changed();
    emit packagesChanged(date);
    return true;
}

bool JournalStore::persistActivePackagesToday()
{
    if (!hasActivePackagesToday()) {
        return false;
    }

    const QDate today = QDate::currentDate();
    MonthData &data = monthData(today.year(), today.month());
    auto packages = data.days.value(today.day());
    const QTime now = minuteToTime(timeToMinute(QTime::currentTime()));
    for (auto &pkg : packages) {
        if (pkg.active) {
            pkg.end = now;
        }
    }
    data.days.insert(today.day(), packages);

    if (!saveMonth(today.year(), today.month(), nullptr)) {
        return false;
    }

    emit changed();
    emit activeDayTicked();
    return true;
}

int JournalStore::lastCountableMinute(const QDate &date) const
{
    const QDate today = QDate::currentDate();
    if (!date.isValid() || date > today) {
        return -1;
    }
    if (date < today) {
        return 24 * 60;
    }
    return timeToMinute(QTime::currentTime());
}

QVector<char> JournalStore::coverageForDate(const QDate &date)
{
    const DayBounds bounds = boundsForDate(date);
    QVector<char> covered(bounds.span(), 0);
    const int last = lastCountableMinute(date);
    if (last < 0) {
        return covered;
    }

    for (const auto &pkg : packagesForDate(date)) {
        const int start = qMax(pkg.startMinute(), bounds.startMinute);
        const int end = qMin(pkg.endMinute(date), qMin(bounds.endMinute, last));
        for (int minute = start; minute < end; ++minute) {
            covered[minute - bounds.startMinute] = 1;
        }
    }
    return covered;
}

QVector<char> JournalStore::fullDayCoverage(const QDate &date)
{
    QVector<char> covered(24 * 60, 0);
    const int last = lastCountableMinute(date);
    if (last < 0) {
        return covered;
    }

    for (const auto &pkg : packagesForDate(date)) {
        const int start = qBound(0, pkg.startMinute(), 24 * 60);
        const int end = qBound(start, qMin(pkg.endMinute(date), last), 24 * 60);
        for (int minute = start; minute < end; ++minute) {
            covered[minute] = 1;
        }
    }
    return covered;
}

BreakAdjustment JournalStore::breakAdjustmentForDate(const QDate &date)
{
    return applyAutomaticBreaks(coverageForDate(date));
}

double JournalStore::actualHoursForDate(const QDate &date)
{
    return breakAdjustmentForDate(date).creditedMinutes / 60.0;
}

double JournalStore::actualHoursForMonth(int year, int month)
{
    const QDate first(year, month, 1);
    if (!first.isValid()) {
        return 0.0;
    }

    double total = 0.0;
    const int days = first.daysInMonth();
    for (int day = 1; day <= days; ++day) {
        total += actualHoursForDate(QDate(year, month, day));
    }
    return total;
}

QVector<QPair<QString, double>> JournalStore::titleHoursForMonth(int year, int month)
{
    const QDate first(year, month, 1);
    if (!first.isValid()) {
        return {};
    }

    QHash<QString, int> minutesByTitle;
    const int days = first.daysInMonth();
    for (int day = 1; day <= days; ++day) {
        const QDate date(year, month, day);
        const int last = lastCountableMinute(date);
        if (last < 0) {
            continue;
        }

        const auto packages = packagesForDate(date);
        const BreakAdjustment breaks = breakAdjustmentForDate(date);
        const DayBounds bounds = boundsForDate(date);
        for (int minute = bounds.startMinute; minute < bounds.endMinute && minute < last;
             ++minute) {
            const int index = minute - bounds.startMinute;
            if (index < 0 || index >= breaks.credited.size() || !breaks.credited[index]) {
                continue;
            }
            const WorkPackage *top = nullptr;
            int topStart = -1;
            for (const auto &pkg : packages) {
                if (minute >= pkg.startMinute() && minute < pkg.endMinute(date)
                    && (top == nullptr || pkg.startMinute() > topStart)) {
                    top = &pkg;
                    topStart = pkg.startMinute();
                }
            }
            if (top) {
                minutesByTitle[top->title] += 1;
            }
        }
    }

    QVector<QPair<QString, double>> result;
    result.reserve(minutesByTitle.size());
    for (auto it = minutesByTitle.constBegin(); it != minutesByTitle.constEnd(); ++it) {
        result.append({it.key(), it.value() / 60.0});
    }
    std::sort(result.begin(), result.end(),
              [](const QPair<QString, double> &a, const QPair<QString, double> &b) {
                  if (a.second != b.second) {
                      return a.second > b.second;
                  }
                  return QString::localeAwareCompare(a.first, b.first) < 0;
              });
    return result;
}

Absence JournalStore::absenceForDate(const QDate &date)
{
    if (!date.isValid()) {
        return {};
    }
    return monthData(date.year(), date.month()).absences.value(date.day());
}

bool JournalStore::setAbsences(const QVector<QDate> &dates, const Absence &absence, QString *error)
{
    if (dates.isEmpty()) {
        return true;
    }

    QSet<QString> monthKeys;
    QDate from;
    QDate to;
    for (const QDate &date : dates) {
        if (!date.isValid()) {
            continue;
        }
        MonthData &data = monthData(date.year(), date.month());
        if (absence.isSet()) {
            data.absences.insert(date.day(), absence);
        } else {
            data.absences.remove(date.day());
        }
        monthKeys.insert(monthKey(date.year(), date.month()));
        if (!from.isValid() || date < from) {
            from = date;
        }
        if (!to.isValid() || date > to) {
            to = date;
        }
    }

    if (monthKeys.isEmpty()) {
        return true;
    }

    for (const QString &key : monthKeys) {
        const auto parts = key.split(QLatin1Char('-'));
        if (parts.size() != 2) {
            continue;
        }
        if (!saveMonth(parts.at(0).toInt(), parts.at(1).toInt(), error)) {
            return false;
        }
    }

    emit changed();
    emit absencesChanged(from, to);
    return true;
}

DayBounds JournalStore::boundsForDate(const QDate &date)
{
    const DayBounds global =
        sanitizedDayBounds(AppSettings::instance().dayStartMinute(),
                           AppSettings::instance().dayEndMinute());
    if (!date.isValid()) {
        return global;
    }

    const DayBounds override = monthData(date.year(), date.month()).dayBounds.value(date.day());
    if (override.custom) {
        return sanitizedDayBounds(override.startMinute, override.endMinute, true);
    }
    return global;
}

bool JournalStore::setBoundsForDate(const QDate &date, const DayBounds &bounds, QString *error)
{
    if (!date.isValid()) {
        return false;
    }

    MonthData &data = monthData(date.year(), date.month());
    if (bounds.custom) {
        if (bounds.startMinute >= bounds.endMinute) {
            if (error) {
                *error = QStringLiteral("Die Tagesgrenze „Von“ muss vor „Bis“ liegen.");
            }
            return false;
        }
        data.dayBounds.insert(date.day(),
                              sanitizedDayBounds(bounds.startMinute, bounds.endMinute, true));
    } else {
        data.dayBounds.remove(date.day());
    }

    if (!saveMonth(date.year(), date.month(), error)) {
        return false;
    }
    emit changed();
    emit dayBoundsChanged(date);
    return true;
}

bool JournalStore::hasActivePackagesToday() const
{
    const QDate today = QDate::currentDate();
    const MonthData *data = monthDataIfLoaded(today.year(), today.month());
    if (!data) {
        return false;
    }
    for (const auto &pkg : data->days.value(today.day())) {
        if (pkg.active) {
            return true;
        }
    }
    return false;
}
