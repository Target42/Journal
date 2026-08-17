#include "AppSettings.h"

#include "ArbzgRules.h"
#include "WorkPackage.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QSettings>
#include <QStandardPaths>
#include <QVector>

#include <algorithm>
#include <array>

namespace {
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
        || dir.exists(QStringLiteral("kalender")) || dir.exists(QStringLiteral("titel.json"));
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
    QSettings settings;
    settings.setValue(QStringLiteral("dataPath"), path);
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
    QSettings settings;
    return settings.value(QStringLiteral("stateCode"), QStringLiteral("NI")).toString().toUpper();
}

void AppSettings::setStateCode(const QString &code)
{
    const QString normalized = code.trimmed().toUpper();
    if (normalized.isEmpty() || normalized == stateCode()) {
        return;
    }
    QSettings settings;
    settings.setValue(QStringLiteral("stateCode"), normalized);
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
    QSettings settings;
    WorkSettings ws;

    ws.annualVacationDays =
        settings.value(QStringLiteral("vacation/annualDays"), 30.0).toDouble();

    const QString mode =
        settings.value(QStringLiteral("workTime/mode"), QStringLiteral("even")).toString();
    ws.workTimeMode = (mode == QStringLiteral("individual"))
                          ? WorkTimeMode::Individual
                          : WorkTimeMode::Even;

    ws.weeklyHours =
        settings.value(QStringLiteral("workTime/weeklyHours"), 40.0).toDouble();

    static constexpr bool defaultDays[7] = {true, true, true, true, true, false, false};
    static constexpr double defaultHours[7] = {8.0, 8.0, 8.0, 8.0, 8.0, 0.0, 0.0};

    for (int i = 0; i < 7; ++i) {
        ws.workDays[i] =
            settings.value(QStringLiteral("workDays/%1").arg(i), defaultDays[i]).toBool();
        ws.hoursPerDay[i] =
            settings.value(QStringLiteral("workTime/hours/%1").arg(i), defaultHours[i]).toDouble();
    }

    return ws;
}

void AppSettings::setWorkSettings(const WorkSettings &ws)
{
    QSettings settings;
    settings.setValue(QStringLiteral("vacation/annualDays"), ws.annualVacationDays);
    settings.setValue(QStringLiteral("workTime/mode"),
                      ws.workTimeMode == WorkTimeMode::Individual
                          ? QStringLiteral("individual")
                          : QStringLiteral("even"));
    settings.setValue(QStringLiteral("workTime/weeklyHours"), ws.weeklyHours);

    for (int i = 0; i < 7; ++i) {
        settings.setValue(QStringLiteral("workDays/%1").arg(i), ws.workDays[i]);
        settings.setValue(QStringLiteral("workTime/hours/%1").arg(i), ws.hoursPerDay[i]);
    }

    emit changed();
}

OvertimeAccountSettings AppSettings::overtimeAccount() const
{
    QSettings settings;
    OvertimeAccountSettings account;

    account.limitsEnabled =
        settings.value(QStringLiteral("overtime/limitsEnabled"), true).toBool();

    const QString period =
        settings.value(QStringLiteral("overtime/period"), QStringLiteral("quarterly")).toString();
    account.period = (period == QStringLiteral("monthly"))
                         ? OvertimeLimitPeriod::Monthly
                         : OvertimeLimitPeriod::Quarterly;

    account.minHours =
        settings.value(QStringLiteral("overtime/minHours"), -20.0).toDouble();
    account.maxHours =
        settings.value(QStringLiteral("overtime/maxHours"), 60.0).toDouble();

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

    QSettings settings;
    settings.setValue(QStringLiteral("overtime/limitsEnabled"), sanitized.limitsEnabled);
    settings.setValue(QStringLiteral("overtime/period"),
                      sanitized.period == OvertimeLimitPeriod::Monthly
                          ? QStringLiteral("monthly")
                          : QStringLiteral("quarterly"));
    settings.setValue(QStringLiteral("overtime/minHours"), sanitized.minHours);
    settings.setValue(QStringLiteral("overtime/maxHours"), sanitized.maxHours);
    emit changed();
}

QDate AppSettings::retirementDate() const
{
    QSettings settings;
    const QDate fallback(2037, 12, 1);
    const QDate date = QDate::fromString(
        settings.value(QStringLiteral("retirement/date"), fallback.toString(Qt::ISODate)).toString(),
        Qt::ISODate);
    return date.isValid() ? date : fallback;
}

void AppSettings::setRetirementDate(const QDate &date)
{
    if (!date.isValid() || date == retirementDate()) {
        return;
    }
    QSettings settings;
    settings.setValue(QStringLiteral("retirement/date"), date.toString(Qt::ISODate));
}

bool AppSettings::prorateVacationInExitYear() const
{
    QSettings settings;
    return settings.value(QStringLiteral("retirement/prorateVacation"), true).toBool();
}

void AppSettings::setProrateVacationInExitYear(bool enabled)
{
    if (enabled == prorateVacationInExitYear()) {
        return;
    }
    QSettings settings;
    settings.setValue(QStringLiteral("retirement/prorateVacation"), enabled);
}

int AppSettings::dayStartMinute() const
{
    QSettings settings;
    return sanitizedDayBounds(
               settings.value(QStringLiteral("dayBounds/startMinute"), kDefaultDayStartMinute)
                   .toInt(),
               settings.value(QStringLiteral("dayBounds/endMinute"), kDefaultDayEndMinute).toInt())
        .startMinute;
}

int AppSettings::dayEndMinute() const
{
    QSettings settings;
    return sanitizedDayBounds(
               settings.value(QStringLiteral("dayBounds/startMinute"), kDefaultDayStartMinute)
                   .toInt(),
               settings.value(QStringLiteral("dayBounds/endMinute"), kDefaultDayEndMinute).toInt())
        .endMinute;
}

void AppSettings::setDayWindow(int startMinute, int endMinute)
{
    const DayBounds bounds = sanitizedDayBounds(startMinute, endMinute);
    QSettings settings;
    settings.setValue(QStringLiteral("dayBounds/startMinute"), bounds.startMinute);
    settings.setValue(QStringLiteral("dayBounds/endMinute"), bounds.endMinute);
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
    QSettings settings;
    const bool hasPresets = settings.contains(QStringLiteral("pause/preset/0/name"))
        || settings.contains(QStringLiteral("pause/preset/1/name"))
        || settings.contains(QStringLiteral("pause/preset/2/name"));

    if (!hasPresets) {
        const DayBounds legacy = sanitizedDayBounds(
            settings.value(QStringLiteral("pause/usualStartMinute"), kUsualPauseStartDefault).toInt(),
            settings.value(QStringLiteral("pause/usualEndMinute"), kUsualPauseEndDefault).toInt());
        return {
            PausePreset{QStringLiteral("Frühstück"),
                        kDefaultBreakfastStartMinute,
                        kDefaultBreakfastEndMinute},
            PausePreset{QStringLiteral("Mittag"), legacy.startMinute, legacy.endMinute},
            PausePreset{},
        };
    }

    std::array<PausePreset, kPausePresetCount> presetSlots {};
    for (int i = 0; i < kPausePresetCount; ++i) {
        const QString prefix = QStringLiteral("pause/preset/%1/").arg(i);
        presetSlots[i].name = settings.value(prefix + QStringLiteral("name")).toString().trimmed();
        presetSlots[i].startMinute =
            settings.value(prefix + QStringLiteral("startMinute"), 0).toInt();
        presetSlots[i].endMinute =
            settings.value(prefix + QStringLiteral("endMinute"), 0).toInt();
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
    QSettings settings;
    for (int i = 0; i < kPausePresetCount; ++i) {
        const QString prefix = QStringLiteral("pause/preset/%1/").arg(i);
        const PausePreset slot = presetSlots[i];
        if (slot.isValid()) {
            settings.setValue(prefix + QStringLiteral("name"), slot.label());
            settings.setValue(prefix + QStringLiteral("startMinute"), slot.startMinute);
            settings.setValue(prefix + QStringLiteral("endMinute"), slot.endMinute);
        } else {
            settings.setValue(prefix + QStringLiteral("name"), QString());
            settings.setValue(prefix + QStringLiteral("startMinute"), 0);
            settings.setValue(prefix + QStringLiteral("endMinute"), 0);
        }
    }
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
    return targetHoursForWeekday(date.dayOfWeek());
}
