#include "TitleCatalog.h"

#include "AppSettings.h"

#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <algorithm>

namespace {
const QColor kPalette[] = {
    QColor(74, 144, 217),
    QColor(124, 179, 66),
    QColor(251, 140, 0),
    QColor(171, 71, 188),
    QColor(38, 166, 154),
    QColor(239, 83, 80),
    QColor(92, 107, 192),
    QColor(141, 110, 99),
    QColor(236, 64, 122),
    QColor(120, 144, 156),
};
} // namespace

TitleCatalog &TitleCatalog::instance()
{
    static TitleCatalog catalog;
    return catalog;
}

TitleCatalog::TitleCatalog()
    : QObject(nullptr)
{
    connect(&AppSettings::instance(), &AppSettings::changed,
            this, &TitleCatalog::reloadIfPathChanged);
    reloadIfPathChanged();
}

QVector<PackageTitle> TitleCatalog::titles() const
{
    return m_titles;
}

bool TitleCatalog::contains(const QString &title) const
{
    return indexOf(title) >= 0;
}

QString TitleCatalog::canonicalTitle(const QString &title) const
{
    const int index = indexOf(title);
    if (index < 0) {
        return title.trimmed();
    }
    return m_titles[index].title;
}

QColor TitleCatalog::colorFor(const QString &title) const
{
    const int index = indexOf(title);
    if (index < 0) {
        return QColor(120, 120, 120);
    }
    return m_titles[index].color;
}

QColor TitleCatalog::nextUnusedColor() const
{
    QVector<QRgb> used;
    used.reserve(m_titles.size());
    for (const auto &entry : m_titles) {
        used.append(entry.color.rgb());
    }

    for (const auto &color : kPalette) {
        if (!used.contains(color.rgb())) {
            return color;
        }
    }

    return kPalette[m_titles.size() % (sizeof(kPalette) / sizeof(kPalette[0]))];
}

void TitleCatalog::upsert(const QString &title, const QColor &color)
{
    const QString trimmed = title.trimmed();
    if (trimmed.isEmpty() || !color.isValid()) {
        return;
    }

    reloadIfPathChanged();

    const int index = indexOf(trimmed);
    if (index >= 0) {
        if (m_titles[index].color == color) {
            return;
        }
        m_titles[index].color = color;
    } else {
        m_titles.append({trimmed, color});
        sortTitles();
    }

    saveToDisk();
    emit changed();
}

bool TitleCatalog::rename(const QString &from, const QString &to)
{
    const QString oldTitle = from.trimmed();
    const QString newTitle = to.trimmed();
    if (oldTitle.isEmpty() || newTitle.isEmpty()) {
        return false;
    }

    reloadIfPathChanged();

    const int fromIndex = indexOf(oldTitle);
    if (fromIndex < 0) {
        return false;
    }

    const int toIndex = indexOf(newTitle);
    if (toIndex == fromIndex) {
        if (m_titles[fromIndex].title == newTitle) {
            return true;
        }
        m_titles[fromIndex].title = newTitle;
        sortTitles();
    } else if (toIndex >= 0) {
        m_titles.removeAt(fromIndex);
    } else {
        m_titles[fromIndex].title = newTitle;
        sortTitles();
    }

    saveToDisk();
    emit changed();
    return true;
}

QString TitleCatalog::filePath() const
{
    return QDir(AppSettings::instance().dataPath()).filePath(QStringLiteral("titel.json"));
}

void TitleCatalog::reloadIfPathChanged()
{
    const QString path = AppSettings::instance().dataPath();
    if (path == m_dataPath && !m_dataPath.isEmpty()) {
        return;
    }
    m_dataPath = path;
    loadFromDisk();
    emit changed();
}

void TitleCatalog::loadFromDisk()
{
    m_titles.clear();

    QFile file(filePath());
    if (!file.exists() || !file.open(QIODevice::ReadOnly)) {
        return;
    }

    const auto doc = QJsonDocument::fromJson(file.readAll());
    const auto array = doc.object().value(QStringLiteral("titles")).toArray();
    for (const auto &value : array) {
        const auto obj = value.toObject();
        const QString title = obj.value(QStringLiteral("title")).toString().trimmed();
        const QColor color(obj.value(QStringLiteral("color")).toString());
        if (title.isEmpty() || !color.isValid() || indexOf(title) >= 0) {
            continue;
        }
        m_titles.append({title, color});
    }

    sortTitles();
}

void TitleCatalog::sortTitles()
{
    std::sort(m_titles.begin(), m_titles.end(), [](const PackageTitle &a, const PackageTitle &b) {
        return QString::localeAwareCompare(a.title, b.title) < 0;
    });
}

void TitleCatalog::saveToDisk() const
{
    QDir().mkpath(AppSettings::instance().dataPath());

    QJsonArray array;
    for (const auto &entry : m_titles) {
        QJsonObject obj;
        obj.insert(QStringLiteral("title"), entry.title);
        obj.insert(QStringLiteral("color"), entry.color.name(QColor::HexRgb));
        array.append(obj);
    }

    QJsonObject root;
    root.insert(QStringLiteral("titles"), array);

    QFile file(filePath());
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        return;
    }
    file.write(QJsonDocument(root).toJson(QJsonDocument::Indented));
}

int TitleCatalog::indexOf(const QString &title) const
{
    const QString trimmed = title.trimmed();
    for (int i = 0; i < m_titles.size(); ++i) {
        if (m_titles[i].title.compare(trimmed, Qt::CaseInsensitive) == 0) {
            return i;
        }
    }
    return -1;
}
