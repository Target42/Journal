#include "AppSettings.h"

#include "ArbzgRules.h"
#include "WorkPackage.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>
#include <QSettings>
#include <QStandardPaths>
#include <QVector>

#include <algorithm>
#include <array>

namespace {
QString eveTreatmentToString(EveDayTreatment treatment)
{
    switch (treatment) {
    case EveDayTreatment::FullVacation:
        return QStringLiteral("full");
    case EveDayTreatment::HalfVacation:
        return QStringLiteral("half");
    case EveDayTreatment::CompanyFree:
        return QStringLiteral("free");
    case EveDayTreatment::Normal:
        break;
    }
    return QStringLiteral("normal");
}

EveDayTreatment eveTreatmentFromString(const QString &value)
{
    if (value == QLatin1String("full")) {
        return EveDayTreatment::FullVacation;
    }
    if (value == QLatin1String("half")) {
        return EveDayTreatment::HalfVacation;
    }
    if (value == QLatin1String("free")) {
        return EveDayTreatment::CompanyFree;
    }
    return EveDayTreatment::Normal;
}

QString defaultDataPath()
{
    return QDir::cleanPath(
        QDir(QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation))
            .filePath(QStringLiteral("Journal")));
}

QString legacyNestedDataPath()
{
    return QDir::cleanPath(QDir(defaultDataPath()).filePath(QStringLiteral("Journal")));
}

bool samePath(const QString &left, const QString &right)
{
    return QDir::cleanPath(left).compare(QDir::cleanPath(right), Qt::CaseInsensitive) == 0;
}

bool looksLikeJournalData(const QString &path)
{
    const QDir dir(path);
    return dir.exists(QStringLiteral("monate")) || dir.exists(QStringLiteral("jahre"))
        || dir.exists(QStringLiteral("kalender")) || dir.exists(QStringLiteral("titel.json"))
        || dir.exists(QStringLiteral("einstellungen.json"));
}

bool removeDirIfEmpty(const QString &path)
{
    const QDir dir(path);
    if (!dir.exists() || !dir.isEmpty()) {
        return !dir.exists();
    }
    return QDir(QFileInfo(path).absolutePath()).rmdir(QFileInfo(path).fileName());
}

bool moveEntry(const QString &from, const QString &to)
{
    const QFileInfo fromInfo(from);
    QFileInfo toInfo(to);
    if (toInfo.exists() && toInfo.isFile()) {
        QFile::remove(to);
        toInfo.refresh();
    }
    if (!toInfo.exists()) {
        return QFile::rename(from, to);
    }
    if (!fromInfo.isDir() || !toInfo.isDir()) {
        return false;
    }

    bool ok = true;
    const auto children =
        QDir(from).entryInfoList(QDir::Dirs | QDir::Files | QDir::NoDotAndDotDot);
    for (const QFileInfo &child : children) {
        if (!moveEntry(child.absoluteFilePath(), QDir(to).filePath(child.fileName()))) {
            ok = false;
        }
    }
    if (!removeDirIfEmpty(from)) {
        ok = false;
    }
    return ok;
}
} // namespace

AppSettings::AppSettings()
    : QObject(nullptr)
{
    migrateLegacyDataPath();
}

AppSettings &AppSettings::instance()
{
    static AppSettings settings;
    return settings;
}

void AppSettings::migrateLegacyDataPath()
{
    QSettings settings;
    const QString stored = settings.value(QStringLiteral("dataPath")).toString().trimmed();
    const QString dest = defaultDataPath();
    const QString legacy = legacyNestedDataPath();
    const bool custom = !stored.isEmpty() && !samePath(stored, dest) && !samePath(stored, legacy);
    if (custom) {
        return;
    }

    if (QDir(legacy).exists() && looksLikeJournalData(legacy)) {
        QDir().mkpath(dest);
        moveEntry(legacy, dest);
    }

    if (looksLikeJournalData(legacy) && !QDir(dest).exists(QStringLiteral("monate"))) {
        settings.setValue(QStringLiteral("dataPath"), legacy);
        return;
    }

    if (stored.isEmpty() || samePath(stored, legacy)) {
        settings.setValue(QStringLiteral("dataPath"), dest);
    }
}

QString AppSettings::settingsFilePath() const
{
    return QDir(dataPath()).filePath(QStringLiteral("einstellungen.json"));
}

void AppSettings::ensureStore() const
{
    if (m_storeLoaded) {
        return;
    }
    m_storeLoaded = true;

    QFile file(settingsFilePath());
    if (file.open(QIODevice::ReadOnly)) {
        const QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
        if (doc.isObject()) {
            m_store = doc.object();
            return;
        }
    }

    migrateFromNative();
    persistStore();
}

void AppSettings::persistStore() const
{
    QDir().mkpath(dataPath());
    QSaveFile file(settingsFilePath());
    if (!file.open(QIODevice::WriteOnly)) {
        return;
    }
    file.write(QJsonDocument(m_store).toJson(QJsonDocument::Indented));
    file.commit();
}

void AppSettings::migrateFromNative() const
{
    QSettings settings;
    m_store = QJsonObject();

    m_store.insert(QStringLiteral("stateCode"),
                   settings.value(QStringLiteral("stateCode"), QStringLiteral("NI")).toString().toUpper());

    QJsonObject vacation;
    vacation.insert(QStringLiteral("annualDays"),
                    settings.value(QStringLiteral("vacation/annualDays"), 30.0).toDouble());
    vacation.insert(QStringLiteral("eveDays"),
                    settings.value(QStringLiteral("vacation/eveDays"), QStringLiteral("normal")).toString());
    m_store.insert(QStringLiteral("vacation"), vacation);

    QJsonObject workTime;
    workTime.insert(QStringLiteral("mode"),
                    settings.value(QStringLiteral("workTime/mode"), QStringLiteral("even")).toString());
    workTime.insert(QStringLiteral("weeklyHours"),
                    settings.value(QStringLiteral("workTime/weeklyHours"), 40.0).toDouble());
    QJsonArray hours;
    static constexpr double defaultHours[7] = {8.0, 8.0, 8.0, 8.0, 8.0, 0.0, 0.0};
    for (int i = 0; i < 7; ++i) {
        hours.append(settings.value(QStringLiteral("workTime/hours/%1").arg(i), defaultHours[i]).toDouble());
    }
    workTime.insert(QStringLiteral("hours"), hours);
    m_store.insert(QStringLiteral("workTime"), workTime);

    QJsonArray workDays;
    static constexpr bool defaultDays[7] = {true, true, true, true, true, false, false};
    for (int i = 0; i < 7; ++i) {
        workDays.append(settings.value(QStringLiteral("workDays/%1").arg(i), defaultDays[i]).toBool());
    }
    m_store.insert(QStringLiteral("workDays"), workDays);

    QJsonObject overtime;
    overtime.insert(QStringLiteral("limitsEnabled"),
                    settings.value(QStringLiteral("overtime/limitsEnabled"), true).toBool());
    overtime.insert(QStringLiteral("period"),
                    settings.value(QStringLiteral("overtime/period"), QStringLiteral("quarterly")).toString());
    overtime.insert(QStringLiteral("minHours"),
                    settings.value(QStringLiteral("overtime/minHours"), -20.0).toDouble());
    overtime.insert(QStringLiteral("maxHours"),
                    settings.value(QStringLiteral("overtime/maxHours"), 60.0).toDouble());
    overtime.insert(QStringLiteral("openingEnabled"),
                    settings.value(QStringLiteral("overtime/openingEnabled"), false).toBool());
    overtime.insert(QStringLiteral("openingYear"),
                    settings.value(QStringLiteral("overtime/openingYear"), 0).toInt());
    overtime.insert(QStringLiteral("openingMonth"),
                    settings.value(QStringLiteral("overtime/openingMonth"), 0).toInt());
    overtime.insert(QStringLiteral("openingHours"),
                    settings.value(QStringLiteral("overtime/openingHours"), 0.0).toDouble());
    m_store.insert(QStringLiteral("overtime"), overtime);

    QJsonObject retirement;
    retirement.insert(QStringLiteral("date"),
                      settings.value(QStringLiteral("retirement/date"), QStringLiteral("2037-12-01")).toString());
    retirement.insert(QStringLiteral("prorateVacation"),
                      settings.value(QStringLiteral("retirement/prorateVacation"), true).toBool());
    m_store.insert(QStringLiteral("retirement"), retirement);

    QJsonObject dayBounds;
    dayBounds.insert(QStringLiteral("startMinute"),
                     settings.value(QStringLiteral("dayBounds/startMinute"), kDefaultDayStartMinute).toInt());
    dayBounds.insert(QStringLiteral("endMinute"),
                     settings.value(QStringLiteral("dayBounds/endMinute"), kDefaultDayEndMinute).toInt());
    m_store.insert(QStringLiteral("dayBounds"), dayBounds);

    QJsonObject pause;
    pause.insert(QStringLiteral("usualStartMinute"),
                 settings.value(QStringLiteral("pause/usualStartMinute"), kUsualPauseStartDefault).toInt());
    pause.insert(QStringLiteral("usualEndMinute"),
                 settings.value(QStringLiteral("pause/usualEndMinute"), kUsualPauseEndDefault).toInt());
    QJsonArray presets;
    const bool hasPresets = settings.contains(QStringLiteral("pause/preset/0/name"))
        || settings.contains(QStringLiteral("pause/preset/1/name"))
        || settings.contains(QStringLiteral("pause/preset/2/name"));
    if (hasPresets) {
        for (int i = 0; i < kPausePresetCount; ++i) {
            const QString prefix = QStringLiteral("pause/preset/%1/").arg(i);
            QJsonObject slot;
            slot.insert(QStringLiteral("name"), settings.value(prefix + QStringLiteral("name")).toString());
            slot.insert(QStringLiteral("startMinute"),
                        settings.value(prefix + QStringLiteral("startMinute"), 0).toInt());
            slot.insert(QStringLiteral("endMinute"),
                        settings.value(prefix + QStringLiteral("endMinute"), 0).toInt());
            presets.append(slot);
        }
    } else {
        const DayBounds legacy = sanitizedDayBounds(
            settings.value(QStringLiteral("pause/usualStartMinute"), kUsualPauseStartDefault).toInt(),
            settings.value(QStringLiteral("pause/usualEndMinute"), kUsualPauseEndDefault).toInt());
        presets.append(QJsonObject{{QStringLiteral("name"), QStringLiteral("Frühstück")},
                                   {QStringLiteral("startMinute"), kDefaultBreakfastStartMinute},
                                   {QStringLiteral("endMinute"), kDefaultBreakfastEndMinute}});
        presets.append(QJsonObject{{QStringLiteral("name"), QStringLiteral("Mittag")},
                                   {QStringLiteral("startMinute"), legacy.startMinute},
                                   {QStringLiteral("endMinute"), legacy.endMinute}});
        presets.append(QJsonObject{{QStringLiteral("name"), QString()},
                                   {QStringLiteral("startMinute"), 0},
                                   {QStringLiteral("endMinute"), 0}});
    }
    pause.insert(QStringLiteral("presets"), presets);
    m_store.insert(QStringLiteral("pause"), pause);
}

QJsonObject AppSettings::group(const QString &name) const
{
    ensureStore();
    return m_store.value(name).toObject();
}

void AppSettings::setGroup(const QString &name, const QJsonObject &group) const
{
    ensureStore();
    m_store.insert(name, group);
    persistStore();
}

QString AppSettings::dataPath() const
{
    QSettings settings;
    const QString stored = settings.value(QStringLiteral("dataPath")).toString().trimmed();
    if (!stored.isEmpty()) {
        return stored;
    }
    return defaultDataPath();
}

void AppSettings::setDataPath(const QString &path)
{
    const QString cleaned = QDir::cleanPath(path.trimmed());
    if (cleaned.isEmpty() || samePath(cleaned, dataPath())) {
        return;
    }

    ensureStore();
    const QJsonObject current = m_store;

    QSettings settings;
    settings.setValue(QStringLiteral("dataPath"), cleaned);

    m_storeLoaded = false;
    if (QFile::exists(QDir(cleaned).filePath(QStringLiteral("einstellungen.json")))) {
        ensureStore();
    } else {
        m_store = current;
        m_storeLoaded = true;
        persistStore();
    }
    emit changed();
}

const QList<GermanState> &AppSettings::germanStates()
{
    static const QList<GermanState> states = {
        {QStringLiteral("BW"), QStringLiteral("Baden-Württemberg")},
        {QStringLiteral("BY"), QStringLiteral("Bayern")},
        {QStringLiteral("BE"), QStringLiteral("Berlin")},
        {QStringLiteral("BB"), QStringLiteral("Brandenburg")},
        {QStringLiteral("HB"), QStringLiteral("Bremen")},
        {QStringLiteral("HH"), QStringLiteral("Hamburg")},
        {QStringLiteral("HE"), QStringLiteral("Hessen")},
        {QStringLiteral("MV"), QStringLiteral("Mecklenburg-Vorpommern")},
        {QStringLiteral("NI"), QStringLiteral("Niedersachsen")},
        {QStringLiteral("NW"), QStringLiteral("Nordrhein-Westfalen")},
        {QStringLiteral("RP"), QStringLiteral("Rheinland-Pfalz")},
        {QStringLiteral("SL"), QStringLiteral("Saarland")},
        {QStringLiteral("SN"), QStringLiteral("Sachsen")},
        {QStringLiteral("ST"), QStringLiteral("Sachsen-Anhalt")},
        {QStringLiteral("SH"), QStringLiteral("Schleswig-Holstein")},
        {QStringLiteral("TH"), QStringLiteral("Thüringen")},
    };
    return states;
}

QString AppSettings::stateCode() const
{
    ensureStore();
    return m_store.value(QStringLiteral("stateCode")).toString(QStringLiteral("NI")).toUpper();
}

void AppSettings::setStateCode(const QString &code)
{
    const QString normalized = code.trimmed().toUpper();
    if (normalized.isEmpty() || normalized == stateCode()) {
        return;
    }
    ensureStore();
    m_store.insert(QStringLiteral("stateCode"), normalized);
    persistStore();
    emit changed();
}

QString AppSettings::stateDisplayName() const
{
    const QString code = stateCode();
    for (const auto &state : germanStates()) {
        if (state.code == code) {
            return QStringLiteral("%1 (%2)").arg(state.name, state.code);
        }
    }
    return code;
}

WorkSettings AppSettings::workSettings() const
{
    const QJsonObject vacation = group(QStringLiteral("vacation"));
    const QJsonObject workTime = group(QStringLiteral("workTime"));
    const QJsonArray workDays = m_store.value(QStringLiteral("workDays")).toArray();
    const QJsonArray hours = workTime.value(QStringLiteral("hours")).toArray();

    WorkSettings ws;
    ws.annualVacationDays = vacation.value(QStringLiteral("annualDays")).toDouble(30.0);
    ws.eveDayTreatment = eveTreatmentFromString(
        vacation.value(QStringLiteral("eveDays")).toString(QStringLiteral("normal")));
    ws.workTimeMode = workTime.value(QStringLiteral("mode")).toString() == QLatin1String("individual")
                          ? WorkTimeMode::Individual
                          : WorkTimeMode::Even;
    ws.weeklyHours = workTime.value(QStringLiteral("weeklyHours")).toDouble(40.0);

    static constexpr bool defaultDays[7] = {true, true, true, true, true, false, false};
    static constexpr double defaultHours[7] = {8.0, 8.0, 8.0, 8.0, 8.0, 0.0, 0.0};
    for (int i = 0; i < 7; ++i) {
        ws.workDays[i] = workDays.size() > i ? workDays.at(i).toBool(defaultDays[i]) : defaultDays[i];
        ws.hoursPerDay[i] = hours.size() > i ? hours.at(i).toDouble(defaultHours[i]) : defaultHours[i];
    }
    return ws;
}

void AppSettings::setWorkSettings(const WorkSettings &ws)
{
    ensureStore();

    QJsonObject vacation = m_store.value(QStringLiteral("vacation")).toObject();
    vacation.insert(QStringLiteral("annualDays"), ws.annualVacationDays);
    vacation.insert(QStringLiteral("eveDays"), eveTreatmentToString(ws.eveDayTreatment));
    m_store.insert(QStringLiteral("vacation"), vacation);

    QJsonObject workTime = m_store.value(QStringLiteral("workTime")).toObject();
    workTime.insert(QStringLiteral("mode"),
                    ws.workTimeMode == WorkTimeMode::Individual
                        ? QStringLiteral("individual")
                        : QStringLiteral("even"));
    workTime.insert(QStringLiteral("weeklyHours"), ws.weeklyHours);
    QJsonArray hours;
    QJsonArray workDays;
    for (int i = 0; i < 7; ++i) {
        hours.append(ws.hoursPerDay[i]);
        workDays.append(ws.workDays[i]);
    }
    workTime.insert(QStringLiteral("hours"), hours);
    m_store.insert(QStringLiteral("workTime"), workTime);
    m_store.insert(QStringLiteral("workDays"), workDays);

    persistStore();
    emit changed();
}

OvertimeAccountSettings AppSettings::overtimeAccount() const
{
    const QJsonObject overtime = group(QStringLiteral("overtime"));
    OvertimeAccountSettings account;
    account.limitsEnabled = overtime.value(QStringLiteral("limitsEnabled")).toBool(true);
    account.period = overtime.value(QStringLiteral("period")).toString() == QLatin1String("monthly")
                         ? OvertimeLimitPeriod::Monthly
                         : OvertimeLimitPeriod::Quarterly;
    account.minHours = overtime.value(QStringLiteral("minHours")).toDouble(-20.0);
    account.maxHours = overtime.value(QStringLiteral("maxHours")).toDouble(60.0);
    account.openingEnabled = overtime.value(QStringLiteral("openingEnabled")).toBool(false);
    account.openingYear = overtime.value(QStringLiteral("openingYear")).toInt(0);
    account.openingMonth = overtime.value(QStringLiteral("openingMonth")).toInt(0);
    account.openingHours = overtime.value(QStringLiteral("openingHours")).toDouble(0.0);
    if (account.minHours > account.maxHours) {
        std::swap(account.minHours, account.maxHours);
    }
    return account;
}

void AppSettings::setOvertimeAccount(const OvertimeAccountSettings &account)
{
    OvertimeAccountSettings sanitized = account;
    if (sanitized.minHours > sanitized.maxHours) {
        std::swap(sanitized.minHours, sanitized.maxHours);
    }

    QJsonObject overtime;
    overtime.insert(QStringLiteral("limitsEnabled"), sanitized.limitsEnabled);
    overtime.insert(QStringLiteral("period"),
                    sanitized.period == OvertimeLimitPeriod::Monthly
                        ? QStringLiteral("monthly")
                        : QStringLiteral("quarterly"));
    overtime.insert(QStringLiteral("minHours"), sanitized.minHours);
    overtime.insert(QStringLiteral("maxHours"), sanitized.maxHours);
    overtime.insert(QStringLiteral("openingEnabled"), sanitized.openingEnabled);
    overtime.insert(QStringLiteral("openingYear"), sanitized.openingYear);
    overtime.insert(QStringLiteral("openingMonth"), sanitized.openingMonth);
    overtime.insert(QStringLiteral("openingHours"), sanitized.openingHours);
    setGroup(QStringLiteral("overtime"), overtime);
    emit changed();
}

QDate AppSettings::retirementDate() const
{
    const QDate fallback(2037, 12, 1);
    const QDate date = QDate::fromString(
        group(QStringLiteral("retirement")).value(QStringLiteral("date")).toString(fallback.toString(Qt::ISODate)),
        Qt::ISODate);
    return date.isValid() ? date : fallback;
}

void AppSettings::setRetirementDate(const QDate &date)
{
    if (!date.isValid() || date == retirementDate()) {
        return;
    }
    QJsonObject retirement = group(QStringLiteral("retirement"));
    retirement.insert(QStringLiteral("date"), date.toString(Qt::ISODate));
    setGroup(QStringLiteral("retirement"), retirement);
    emit changed();
}

bool AppSettings::prorateVacationInExitYear() const
{
    return group(QStringLiteral("retirement")).value(QStringLiteral("prorateVacation")).toBool(true);
}

void AppSettings::setProrateVacationInExitYear(bool enabled)
{
    if (enabled == prorateVacationInExitYear()) {
        return;
    }
    QJsonObject retirement = group(QStringLiteral("retirement"));
    retirement.insert(QStringLiteral("prorateVacation"), enabled);
    setGroup(QStringLiteral("retirement"), retirement);
    emit changed();
}

int AppSettings::dayStartMinute() const
{
    const QJsonObject bounds = group(QStringLiteral("dayBounds"));
    return sanitizedDayBounds(
               bounds.value(QStringLiteral("startMinute")).toInt(kDefaultDayStartMinute),
               bounds.value(QStringLiteral("endMinute")).toInt(kDefaultDayEndMinute))
        .startMinute;
}

int AppSettings::dayEndMinute() const
{
    const QJsonObject bounds = group(QStringLiteral("dayBounds"));
    return sanitizedDayBounds(
               bounds.value(QStringLiteral("startMinute")).toInt(kDefaultDayStartMinute),
               bounds.value(QStringLiteral("endMinute")).toInt(kDefaultDayEndMinute))
        .endMinute;
}

void AppSettings::setDayWindow(int startMinute, int endMinute)
{
    const DayBounds bounds = sanitizedDayBounds(startMinute, endMinute);
    QJsonObject obj;
    obj.insert(QStringLiteral("startMinute"), bounds.startMinute);
    obj.insert(QStringLiteral("endMinute"), bounds.endMinute);
    setGroup(QStringLiteral("dayBounds"), obj);
    emit changed();
}

DayBounds AppSettings::usualPauseWindow() const
{
    const QVector<PausePreset> presets = pausePresets();
    for (const auto &preset : presets) {
        if (preset.label().compare(QStringLiteral("Mittag"), Qt::CaseInsensitive) == 0) {
            return {preset.startMinute, preset.endMinute, false};
        }
    }
    if (!presets.isEmpty()) {
        PausePreset longest = presets.first();
        for (const auto &preset : presets) {
            if (preset.endMinute - preset.startMinute > longest.endMinute - longest.startMinute) {
                longest = preset;
            }
        }
        return {longest.startMinute, longest.endMinute, false};
    }
    return sanitizedDayBounds(kUsualPauseStartDefault, kUsualPauseEndDefault);
}

std::array<PausePreset, kPausePresetCount> AppSettings::pausePresetSlots() const
{
    const QJsonObject pause = group(QStringLiteral("pause"));
    const QJsonArray presets = pause.value(QStringLiteral("presets")).toArray();
    std::array<PausePreset, kPausePresetCount> presetSlots {};

    if (presets.isEmpty()) {
        const DayBounds legacy = sanitizedDayBounds(
            pause.value(QStringLiteral("usualStartMinute")).toInt(kUsualPauseStartDefault),
            pause.value(QStringLiteral("usualEndMinute")).toInt(kUsualPauseEndDefault));
        return {
            PausePreset{QStringLiteral("Frühstück"),
                        kDefaultBreakfastStartMinute,
                        kDefaultBreakfastEndMinute},
            PausePreset{QStringLiteral("Mittag"), legacy.startMinute, legacy.endMinute},
            PausePreset{},
        };
    }

    for (int i = 0; i < kPausePresetCount && i < presets.size(); ++i) {
        const QJsonObject slot = presets.at(i).toObject();
        presetSlots[i].name = slot.value(QStringLiteral("name")).toString().trimmed();
        presetSlots[i].startMinute = slot.value(QStringLiteral("startMinute")).toInt(0);
        presetSlots[i].endMinute = slot.value(QStringLiteral("endMinute")).toInt(0);
    }
    return presetSlots;
}

QVector<PausePreset> AppSettings::pausePresets() const
{
    QVector<PausePreset> presets;
    for (const auto &slot : pausePresetSlots()) {
        if (slot.isValid()) {
            presets.append(slot);
        }
    }
    return presets;
}

void AppSettings::setPausePresetSlots(const std::array<PausePreset, kPausePresetCount> &presetSlots)
{
    ensureStore();
    QJsonObject pause = m_store.value(QStringLiteral("pause")).toObject();
    QJsonArray presets;
    DayBounds usual = sanitizedDayBounds(kUsualPauseStartDefault, kUsualPauseEndDefault);
    for (int i = 0; i < kPausePresetCount; ++i) {
        const PausePreset slot = presetSlots[i];
        QJsonObject obj;
        if (slot.isValid()) {
            obj.insert(QStringLiteral("name"), slot.label());
            obj.insert(QStringLiteral("startMinute"), slot.startMinute);
            obj.insert(QStringLiteral("endMinute"), slot.endMinute);
            if (slot.label().compare(QStringLiteral("Mittag"), Qt::CaseInsensitive) == 0) {
                usual = {slot.startMinute, slot.endMinute, false};
            }
        } else {
            obj.insert(QStringLiteral("name"), QString());
            obj.insert(QStringLiteral("startMinute"), 0);
            obj.insert(QStringLiteral("endMinute"), 0);
        }
        presets.append(obj);
    }
    pause.insert(QStringLiteral("presets"), presets);
    pause.insert(QStringLiteral("usualStartMinute"), usual.startMinute);
    pause.insert(QStringLiteral("usualEndMinute"), usual.endMinute);
    m_store.insert(QStringLiteral("pause"), pause);
    persistStore();
    emit changed();
}

bool AppSettings::isWorkDay(int dayOfWeek) const
{
    if (dayOfWeek < 1 || dayOfWeek > 7) {
        return false;
    }
    return workSettings().workDays[dayOfWeek - 1];
}

int AppSettings::workDayCount() const
{
    int count = 0;
    for (bool day : workSettings().workDays) {
        if (day) {
            ++count;
        }
    }
    return count;
}

double AppSettings::targetHoursForWeekday(int dayOfWeek) const
{
    if (dayOfWeek < 1 || dayOfWeek > 7) {
        return 0.0;
    }

    const WorkSettings ws = workSettings();
    const int idx = dayOfWeek - 1;
    if (!ws.workDays[idx]) {
        return 0.0;
    }

    if (ws.workTimeMode == WorkTimeMode::Even) {
        int count = 0;
        for (bool day : ws.workDays) {
            if (day) {
                ++count;
            }
        }
        return count > 0 ? ws.weeklyHours / static_cast<double>(count) : 0.0;
    }

    return ws.hoursPerDay[idx];
}

double AppSettings::targetHoursForDate(const QDate &date) const
{
    if (!date.isValid()) {
        return 0.0;
    }
    if (isEveDate(date)
        && workSettings().eveDayTreatment == EveDayTreatment::CompanyFree) {
        return 0.0;
    }
    return targetHoursForWeekday(date.dayOfWeek());
}

Absence AppSettings::impliedAbsenceForDate(const QDate &date) const
{
    if (!isEveDate(date) || targetHoursForWeekday(date.dayOfWeek()) <= 0.0) {
        return {};
    }
    switch (workSettings().eveDayTreatment) {
    case EveDayTreatment::FullVacation:
        return {AbsenceType::Vacation, 1.0};
    case EveDayTreatment::HalfVacation:
        return {AbsenceType::Vacation, 0.5};
    case EveDayTreatment::Normal:
    case EveDayTreatment::CompanyFree:
        break;
    }
    return {};
}

bool AppSettings::isCompanyFreeEveDate(const QDate &date) const
{
    return isEveDate(date)
        && workSettings().eveDayTreatment == EveDayTreatment::CompanyFree
        && targetHoursForWeekday(date.dayOfWeek()) > 0.0;
}
