#pragma once

#include "WorkPackage.h"

#include <QObject>
#include <QVector>

class TitleCatalog : public QObject
{
    Q_OBJECT

public:
    static TitleCatalog &instance();

    QVector<PackageTitle> titles() const;
    bool contains(const QString &title) const;
    QString canonicalTitle(const QString &title) const;
    QColor colorFor(const QString &title) const;
    QColor nextUnusedColor() const;

    void upsert(const QString &title, const QColor &color);
    bool rename(const QString &from, const QString &to);

signals:
    void changed();

private:
    TitleCatalog();

    QString filePath() const;
    void reloadIfPathChanged();
    void loadFromDisk();
    void saveToDisk() const;
    void sortTitles();
    int indexOf(const QString &title) const;

    QString m_dataPath;
    QVector<PackageTitle> m_titles;
};
