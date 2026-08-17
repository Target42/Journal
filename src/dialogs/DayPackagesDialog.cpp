#include "DayPackagesDialog.h"

#include "core/AppSettings.h"
#include "core/JournalStore.h"
#include "core/TitleCatalog.h"
#include "PauseDialog.h"
#include "WorkPackageDialog.h"

#include <algorithm>
#include <QAbstractButton>
#include <QVector>
#include <QAbstractItemView>
#include <QColor>
#include <QDialogButtonBox>
#include <QFont>
#include <QHeaderView>
#include <QHBoxLayout>
#include <QIcon>
#include <QKeyEvent>
#include <QLabel>
#include <QLocale>
#include <QMessageBox>
#include <QPixmap>
#include <QPushButton>
#include <QTableWidget>
#include <QTableWidgetItem>
#include <QTime>
#include <QUuid>
#include <QVBoxLayout>

namespace {
QIcon colorIcon(const QColor &color)
{
    QPixmap pixmap(12, 12);
    pixmap.fill(color.isValid() ? color : QColor(120, 120, 120));
    return QIcon(pixmap);
}

QString formatHours(double hours)
{
    return QLocale().toString(hours, 'f', 2);
}

QString formatTime(const QTime &time)
{
    return time.isValid() ? time.toString(QStringLiteral("HH:mm")) : QStringLiteral("—");
}
} // namespace

DayPackagesDialog::DayPackagesDialog(const QDate &date, QWidget *parent)
    : QDialog(parent)
    , m_date(date)
{
    setModal(true);
    setMinimumSize(640, 380);
    resize(720, 440);
    setWindowTitle(QStringLiteral("Arbeitspakete – %1")
                       .arg(QLocale().toString(m_date, QStringLiteral("ddd, d. MMM yyyy"))));

    setupUi();
    refresh();

    connect(&JournalStore::instance(), &JournalStore::changed, this, &DayPackagesDialog::refresh);
    connect(&TitleCatalog::instance(), &TitleCatalog::changed, this, &DayPackagesDialog::refresh);
}

void DayPackagesDialog::setupUi()
{
    auto *root = new QVBoxLayout(this);

    m_summaryLabel = new QLabel(this);
    root->addWidget(m_summaryLabel);

    m_table = new QTableWidget(0, 5, this);
    m_table->setHorizontalHeaderLabels({
        QStringLiteral("Titel"),
        QStringLiteral("Von"),
        QStringLiteral("Bis"),
        QStringLiteral("Dauer"),
        QStringLiteral("Details"),
    });
    m_table->verticalHeader()->setVisible(false);
    m_table->setEditTriggers(QAbstractItemView::NoEditTriggers);
    m_table->setSelectionBehavior(QAbstractItemView::SelectRows);
    m_table->setSelectionMode(QAbstractItemView::SingleSelection);
    m_table->setAlternatingRowColors(false);
    m_table->setShowGrid(true);
    m_table->setWordWrap(false);

    QFont mono = m_table->font();
    mono.setStyleHint(QFont::Monospace);
    mono.setFamily(QStringLiteral("Consolas"));
    m_table->setFont(mono);

    auto *header = m_table->horizontalHeader();
    header->setSectionResizeMode(0, QHeaderView::Stretch);
    header->setSectionResizeMode(1, QHeaderView::ResizeToContents);
    header->setSectionResizeMode(2, QHeaderView::ResizeToContents);
    header->setSectionResizeMode(3, QHeaderView::ResizeToContents);
    header->setSectionResizeMode(4, QHeaderView::Stretch);
    m_table->setColumnWidth(0, 180);

    root->addWidget(m_table, 1);

    auto *row = new QHBoxLayout();
    m_addButton = new QPushButton(QStringLiteral("Hinzufügen…"), this);
    m_pauseButton = new QPushButton(QStringLiteral("Pause…"), this);
    m_editButton = new QPushButton(QStringLiteral("Bearbeiten…"), this);
    m_deleteButton = new QPushButton(QStringLiteral("Löschen"), this);
    m_addButton->setAutoDefault(false);
    m_pauseButton->setAutoDefault(false);
    m_editButton->setAutoDefault(false);
    m_deleteButton->setAutoDefault(false);
    row->addWidget(m_addButton);
    row->addWidget(m_pauseButton);
    row->addWidget(m_editButton);
    row->addWidget(m_deleteButton);
    row->addStretch();
    root->addLayout(row);

    auto *buttons = new QDialogButtonBox(QDialogButtonBox::Close, this);
    if (auto *close = buttons->button(QDialogButtonBox::Close)) {
        close->setText(QStringLiteral("Schließen"));
        close->setAutoDefault(false);
        close->setDefault(false);
    }
    root->addWidget(buttons);

    connect(m_addButton, &QPushButton::clicked, this, &DayPackagesDialog::addPackage);
    connect(m_pauseButton, &QPushButton::clicked, this, &DayPackagesDialog::addPause);
    connect(m_editButton, &QPushButton::clicked, this, &DayPackagesDialog::editSelected);
    connect(m_deleteButton, &QPushButton::clicked, this, &DayPackagesDialog::deleteSelected);
    connect(m_table, &QTableWidget::itemSelectionChanged, this, &DayPackagesDialog::updateButtons);
    connect(m_table, &QTableWidget::cellDoubleClicked, this, [this]() { editSelected(); });
    connect(buttons, &QDialogButtonBox::rejected, this, &QDialog::reject);
}

void DayPackagesDialog::refresh()
{
    const QString previousId = selectedId();
    int previousPauseStart = -1;
    int previousPauseEnd = -1;
    selectedPause(&previousPauseStart, &previousPauseEnd);

    auto &store = JournalStore::instance();
    auto packages = store.packagesForDate(m_date);
    const auto pauses = store.pausesForDate(m_date);
    auto &catalog = TitleCatalog::instance();

    struct Row {
        bool pause = false;
        WorkPackage package;
        PauseInterval interval;
        int startMinute = 0;
    };
    QVector<Row> rows;
    rows.reserve(packages.size() + pauses.size());
    for (const auto &pkg : packages) {
        rows.append({false, pkg, {}, pkg.startMinute()});
    }
    for (const auto &pause : pauses) {
        rows.append({true, {}, pause, pause.startMinute});
    }
    std::sort(rows.begin(), rows.end(), [](const Row &a, const Row &b) {
        return a.startMinute < b.startMinute;
    });

    m_table->setRowCount(rows.size());
    const QColor pauseBg(236, 236, 228);
    for (int row = 0; row < rows.size(); ++row) {
        const Row &entry = rows[row];
        auto makeText = [row, this, &pauseBg, isPause = entry.pause](int column, const QString &text,
                                                                     bool alignRight) {
            auto *item = new QTableWidgetItem(text);
            item->setFlags(item->flags() & ~Qt::ItemIsEditable);
            if (alignRight) {
                item->setTextAlignment(Qt::AlignRight | Qt::AlignVCenter);
            }
            if (isPause) {
                item->setBackground(pauseBg);
            }
            m_table->setItem(row, column, item);
        };

        if (entry.pause) {
            auto *titleItem = new QTableWidgetItem(QStringLiteral("Pause"));
            for (const auto &preset : AppSettings::instance().pausePresets()) {
                if (entry.interval.startMinute <= preset.startMinute
                    && entry.interval.endMinute >= preset.endMinute) {
                    titleItem->setText(preset.label());
                    break;
                }
            }
            titleItem->setData(Qt::UserRole, QStringLiteral("pause"));
            titleItem->setData(Qt::UserRole + 1, entry.interval.startMinute);
            titleItem->setData(Qt::UserRole + 2, entry.interval.endMinute);
            titleItem->setFlags(titleItem->flags() & ~Qt::ItemIsEditable);
            titleItem->setBackground(pauseBg);
            m_table->setItem(row, 0, titleItem);
            makeText(1, formatTime(minuteToTime(entry.interval.startMinute)), true);
            makeText(2, formatTime(minuteToTime(entry.interval.endMinute)), true);
            makeText(3, formatHours((entry.interval.endMinute - entry.interval.startMinute) / 60.0),
                      true);
            makeText(4, QString(), false);
            continue;
        }

        const WorkPackage &pkg = entry.package;
        const int start = pkg.startMinute();
        const int end = pkg.endMinute(m_date);
        auto *titleItem = new QTableWidgetItem(colorIcon(catalog.colorFor(pkg.title)), pkg.title);
        titleItem->setData(Qt::UserRole, pkg.id);
        titleItem->setFlags(titleItem->flags() & ~Qt::ItemIsEditable);
        if (pkg.active) {
            titleItem->setText(QStringLiteral("▶ %1").arg(pkg.title));
        }
        m_table->setItem(row, 0, titleItem);
        makeText(1, formatTime(pkg.start), true);
        QString endText = formatTime(minuteToTime(end));
        if (pkg.active) {
            endText += QStringLiteral("  Aktiv");
        }
        makeText(2, endText, true);
        makeText(3, formatHours(qMax(0, end - start) / 60.0), true);
        makeText(4, pkg.details, false);
    }

    if (packages.isEmpty()) {
        m_summaryLabel->setText(QStringLiteral("Keine Arbeitspakete an diesem Tag."));
    } else {
        QString text = packages.size() == 1
                           ? QStringLiteral("1 Arbeitspaket")
                           : QStringLiteral("%1 Arbeitspakete").arg(packages.size());
        if (!pauses.isEmpty()) {
            text += pauses.size() == 1
                        ? QStringLiteral(" · 1 Pause")
                        : QStringLiteral(" · %1 Pausen").arg(pauses.size());
        }
        m_summaryLabel->setText(text);
    }

    int selectRow = -1;
    for (int row = 0; row < m_table->rowCount(); ++row) {
        const auto *item = m_table->item(row, 0);
        if (!item) {
            continue;
        }
        if (!previousId.isEmpty() && item->data(Qt::UserRole).toString() == previousId) {
            selectRow = row;
            break;
        }
        if (previousPauseStart >= 0
            && item->data(Qt::UserRole).toString() == QLatin1String("pause")
            && item->data(Qt::UserRole + 1).toInt() == previousPauseStart
            && item->data(Qt::UserRole + 2).toInt() == previousPauseEnd) {
            selectRow = row;
            break;
        }
    }
    if (selectRow < 0 && m_table->rowCount() > 0) {
        selectRow = 0;
    }
    if (selectRow >= 0) {
        m_table->selectRow(selectRow);
    } else {
        m_table->clearSelection();
    }
    updateButtons();
}

void DayPackagesDialog::updateButtons()
{
    int pauseStart = -1;
    int pauseEnd = -1;
    const bool hasSelection = !selectedId().isEmpty() || selectedPause(&pauseStart, &pauseEnd);
    m_editButton->setEnabled(hasSelection);
    m_deleteButton->setEnabled(hasSelection);
}

QString DayPackagesDialog::selectedId() const
{
    const int row = m_table->currentRow();
    if (row < 0) {
        return {};
    }
    const auto *item = m_table->item(row, 0);
    if (!item) {
        return {};
    }
    const QString id = item->data(Qt::UserRole).toString();
    return id == QLatin1String("pause") ? QString() : id;
}

bool DayPackagesDialog::selectedPause(int *startMinute, int *endMinute) const
{
    const int row = m_table->currentRow();
    if (row < 0) {
        return false;
    }
    const auto *item = m_table->item(row, 0);
    if (!item || item->data(Qt::UserRole).toString() != QLatin1String("pause")) {
        return false;
    }
    if (startMinute) {
        *startMinute = item->data(Qt::UserRole + 1).toInt();
    }
    if (endMinute) {
        *endMinute = item->data(Qt::UserRole + 2).toInt();
    }
    return true;
}

void DayPackagesDialog::addPause()
{
    int atMinute = 12 * 60;
    const QString id = selectedId();
    if (!id.isEmpty()) {
        const WorkPackage pkg = JournalStore::instance().packageById(m_date, id);
        if (!pkg.id.isEmpty()) {
            atMinute = (pkg.startMinute() + pkg.endMinute(m_date)) / 2;
        }
    } else {
        int pauseStart = -1;
        int pauseEnd = -1;
        if (selectedPause(&pauseStart, &pauseEnd)) {
            PauseDialog::runRange(m_date, pauseStart, pauseEnd, true, this);
            return;
        }
    }
    PauseDialog::runAt(m_date, atMinute, this);
}

void DayPackagesDialog::addPackage()
{
    auto &store = JournalStore::instance();
    int startMinute = 8 * 60;
    int endMinute = 8 * 60 + 30;
    bool active = false;
    if (m_date == QDate::currentDate()) {
        startMinute = timeToMinute(QTime::currentTime());
        endMinute = startMinute + 30;
        active = true;
    }

    startMinute = qBound(0, startMinute, 23 * 60 + 58);
    endMinute = qBound(startMinute + 1, endMinute, 23 * 60 + 59);
    while (store.startMinuteTaken(m_date, startMinute) && startMinute < 23 * 60 + 58) {
        ++startMinute;
        if (endMinute <= startMinute) {
            endMinute = startMinute + 1;
        }
    }

    WorkPackage pkg;
    pkg.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    pkg.start = minuteToTime(startMinute);
    pkg.end = minuteToTime(endMinute);
    pkg.active = active;
    openEditor(pkg);
}

void DayPackagesDialog::editSelected()
{
    int pauseStart = -1;
    int pauseEnd = -1;
    if (selectedPause(&pauseStart, &pauseEnd)) {
        PauseDialog::runRange(m_date, pauseStart, pauseEnd, true, this);
        return;
    }
    const QString id = selectedId();
    if (id.isEmpty()) {
        return;
    }
    const WorkPackage pkg = JournalStore::instance().packageById(m_date, id);
    if (pkg.id.isEmpty()) {
        return;
    }
    openEditor(pkg);
}

void DayPackagesDialog::deleteSelected()
{
    int pauseStart = -1;
    int pauseEnd = -1;
    if (selectedPause(&pauseStart, &pauseEnd)) {
        QMessageBox box(this);
        box.setIcon(QMessageBox::Question);
        box.setWindowTitle(QStringLiteral("Pause löschen"));
        box.setText(QStringLiteral("Die Pause schließen und die Arbeitszeit wieder verbinden?"));
        box.setStandardButtons(QMessageBox::Yes | QMessageBox::No);
        box.setDefaultButton(QMessageBox::No);
        box.button(QMessageBox::Yes)->setText(QStringLiteral("Ja"));
        box.button(QMessageBox::No)->setText(QStringLiteral("Nein"));
        if (box.exec() != QMessageBox::Yes) {
            return;
        }
        QString error;
        if (!JournalStore::instance().closePause(m_date, pauseStart, pauseEnd, &error)) {
            QMessageBox::warning(this, QStringLiteral("Pause"), error);
        }
        return;
    }
    const QString id = selectedId();
    if (id.isEmpty()) {
        return;
    }
    const WorkPackage pkg = JournalStore::instance().packageById(m_date, id);
    if (pkg.id.isEmpty()) {
        return;
    }

    QMessageBox box(this);
    box.setIcon(QMessageBox::Question);
    box.setWindowTitle(QStringLiteral("Arbeitspaket löschen"));
    box.setText(QStringLiteral("Arbeitspaket „%1“ wirklich löschen?").arg(pkg.title));
    box.setStandardButtons(QMessageBox::Yes | QMessageBox::No);
    box.setDefaultButton(QMessageBox::No);
    box.button(QMessageBox::Yes)->setText(QStringLiteral("Ja"));
    box.button(QMessageBox::No)->setText(QStringLiteral("Nein"));
    if (box.exec() != QMessageBox::Yes) {
        return;
    }
    JournalStore::instance().removePackage(m_date, id);
}

void DayPackagesDialog::openEditor(const WorkPackage &package)
{
    WorkPackageDialog dialog(m_date, package, this);
    if (dialog.exec() != QDialog::Accepted) {
        return;
    }
    if (dialog.wasDeleted()) {
        JournalStore::instance().removePackage(m_date, package.id);
        return;
    }
    QString error;
    if (!JournalStore::instance().savePackage(m_date, dialog.package(), &error)) {
        QMessageBox::warning(this, QStringLiteral("Arbeitspaket"), error);
    }
}

void DayPackagesDialog::keyPressEvent(QKeyEvent *event)
{
    if (event->key() == Qt::Key_Delete) {
        deleteSelected();
        return;
    }
    if (event->key() == Qt::Key_Return || event->key() == Qt::Key_Enter) {
        if (m_table->hasFocus() && !selectedId().isEmpty()) {
            editSelected();
            return;
        }
    }
    QDialog::keyPressEvent(event);
}
