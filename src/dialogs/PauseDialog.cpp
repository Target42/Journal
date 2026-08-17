#include "PauseDialog.h"

#include "core/JournalStore.h"
#include "core/WorkPackage.h"

#include <QAbstractButton>
#include <QDialogButtonBox>
#include <QHBoxLayout>
#include <QLabel>
#include <QLocale>
#include <QMessageBox>
#include <QPushButton>
#include <QTimeEdit>
#include <QVBoxLayout>

PauseDialog::PauseDialog(const QDate &date, int startMinute, int endMinute, bool existing,
                         QWidget *parent)
    : QDialog(parent)
    , m_date(date)
    , m_existing(existing)
{
    setModal(true);
    setMinimumWidth(420);
    const QString dayText = QLocale().toString(m_date, QStringLiteral("ddd, d. MMM yyyy"));
    setWindowTitle(existing ? QStringLiteral("Pause bearbeiten – %1").arg(dayText)
                            : QStringLiteral("Pause einfügen – %1").arg(dayText));
    setupUi();
    m_startEdit->setTime(minuteToTime(startMinute));
    m_endEdit->setTime(minuteToTime(endMinute));
    updateDuration();
}

void PauseDialog::setupUi()
{
    auto *root = new QVBoxLayout(this);

    auto *row = new QHBoxLayout();
    row->addWidget(new QLabel(QStringLiteral("Von:"), this));
    m_startEdit = new QTimeEdit(this);
    m_startEdit->setDisplayFormat(QStringLiteral("HH:mm"));
    m_startEdit->setWrapping(false);
    row->addWidget(m_startEdit);
    row->addSpacing(12);
    row->addWidget(new QLabel(QStringLiteral("Bis:"), this));
    m_endEdit = new QTimeEdit(this);
    m_endEdit->setDisplayFormat(QStringLiteral("HH:mm"));
    m_endEdit->setWrapping(false);
    row->addWidget(m_endEdit);
    row->addSpacing(16);
    m_durationLabel = new QLabel(this);
    row->addWidget(m_durationLabel, 1);
    root->addLayout(row);

    auto *hint = new QLabel(
        QStringLiteral("Die Pause wird als Lücke zwischen Arbeitspaketen gespeichert. "
                       "Ab 15 Minuten zählt sie für ArbZG und ersetzt den automatischen Abzug."),
        this);
    hint->setWordWrap(true);
    root->addWidget(hint);

    auto *buttons = new QDialogButtonBox(QDialogButtonBox::Ok | QDialogButtonBox::Cancel, this);
    if (auto *ok = buttons->button(QDialogButtonBox::Ok)) {
        ok->setText(QStringLiteral("Übernehmen"));
        ok->setDefault(true);
    }
    if (auto *cancel = buttons->button(QDialogButtonBox::Cancel)) {
        cancel->setText(QStringLiteral("Abbrechen"));
    }
    if (m_existing) {
        auto *remove = buttons->addButton(QStringLiteral("Pause löschen"),
                                          QDialogButtonBox::DestructiveRole);
        remove->setAutoDefault(false);
        connect(remove, &QPushButton::clicked, this, &PauseDialog::confirmDelete);
    }
    root->addWidget(buttons);

    connect(m_startEdit, &QTimeEdit::timeChanged, this, &PauseDialog::updateDuration);
    connect(m_endEdit, &QTimeEdit::timeChanged, this, &PauseDialog::updateDuration);
    connect(buttons, &QDialogButtonBox::accepted, this, &QDialog::accept);
    connect(buttons, &QDialogButtonBox::rejected, this, &QDialog::reject);
}

int PauseDialog::startMinute() const
{
    return timeToMinute(m_startEdit->time());
}

int PauseDialog::endMinute() const
{
    return timeToMinute(m_endEdit->time());
}

void PauseDialog::updateDuration()
{
    const int minutes = endMinute() - startMinute();
    if (minutes <= 0) {
        m_durationLabel->setText(QStringLiteral("Dauer: –"));
        return;
    }
    m_durationLabel->setText(
        QStringLiteral("Dauer: %1 h").arg(QLocale().toString(minutes / 60.0, 'f', 2)));
}

void PauseDialog::confirmDelete()
{
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
    m_deleted = true;
    QDialog::accept();
}

void PauseDialog::accept()
{
    if (m_deleted) {
        QDialog::accept();
        return;
    }
    if (endMinute() <= startMinute()) {
        QMessageBox::warning(this, windowTitle(),
                             QStringLiteral("Das Ende muss nach dem Beginn liegen."));
        return;
    }
    QDialog::accept();
}

bool PauseDialog::runRange(const QDate &date, int startMinute, int endMinute, bool existing,
                           QWidget *parent)
{
    PauseDialog dialog(date, startMinute, endMinute, existing, parent);
    if (dialog.exec() != QDialog::Accepted) {
        return false;
    }

    auto &store = JournalStore::instance();
    QString error;
    if (dialog.wasDeleted()) {
        if (!store.closePause(date, startMinute, endMinute, &error)) {
            QMessageBox::warning(parent, QStringLiteral("Pause"), error);
            return false;
        }
        return true;
    }

    const int nextStart = dialog.startMinute();
    const int nextEnd = dialog.endMinute();
    if (existing && (nextStart != startMinute || nextEnd != endMinute)) {
        if (!store.closePause(date, startMinute, endMinute, &error)) {
            QMessageBox::warning(parent, QStringLiteral("Pause"), error);
            return false;
        }
    }
    if (existing && nextStart == startMinute && nextEnd == endMinute) {
        return true;
    }
    if (!store.applyPause(date, nextStart, nextEnd, &error)) {
        QMessageBox::warning(parent, QStringLiteral("Pause"), error);
        return false;
    }
    return true;
}

bool PauseDialog::runAt(const QDate &date, int atMinute, QWidget *parent)
{
    int start = atMinute;
    int end = atMinute + 30;
    bool existing = false;
    JournalStore::instance().suggestPause(date, atMinute, &start, &end, &existing);
    return runRange(date, start, end, existing, parent);
}
