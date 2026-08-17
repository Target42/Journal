#include "DayBoundsDialog.h"

#include "core/AppSettings.h"
#include "core/JournalStore.h"
#include "core/WorkPackage.h"

#include <QDialogButtonBox>
#include <QHBoxLayout>
#include <QLabel>
#include <QLocale>
#include <QMessageBox>
#include <QPushButton>
#include <QRadioButton>
#include <QTimeEdit>
#include <QVBoxLayout>

DayBoundsDialog::DayBoundsDialog(const QDate &date, QWidget *parent)
    : QDialog(parent)
    , m_date(date)
{
    const QString dayText = QLocale().toString(m_date, QStringLiteral("ddd, d. MMM yyyy"));
    setWindowTitle(QStringLiteral("Tagesgrenzen – %1").arg(dayText));
    setModal(true);
    setMinimumWidth(420);
    setupUi();
    load();
}

void DayBoundsDialog::setupUi()
{
    auto *root = new QVBoxLayout(this);

    m_globalRadio = new QRadioButton(QStringLiteral("Globale Grenzen verwenden"), this);
    m_globalLabel = new QLabel(this);
    m_globalLabel->setIndent(24);
    root->addWidget(m_globalRadio);
    root->addWidget(m_globalLabel);

    m_customRadio = new QRadioButton(QStringLiteral("Abweichend für diesen Tag"), this);
    root->addWidget(m_customRadio);

    auto *customRow = new QWidget(this);
    auto *customLayout = new QHBoxLayout(customRow);
    customLayout->setContentsMargins(24, 0, 0, 0);
    customLayout->setSpacing(8);
    customLayout->addWidget(new QLabel(QStringLiteral("Von:"), customRow));
    m_startEdit = new QTimeEdit(customRow);
    m_startEdit->setDisplayFormat(QStringLiteral("HH:mm"));
    m_startEdit->setWrapping(false);
    customLayout->addWidget(m_startEdit);
    customLayout->addSpacing(12);
    customLayout->addWidget(new QLabel(QStringLiteral("Bis:"), customRow));
    m_endEdit = new QTimeEdit(customRow);
    m_endEdit->setDisplayFormat(QStringLiteral("HH:mm"));
    m_endEdit->setWrapping(false);
    customLayout->addWidget(m_endEdit);
    customLayout->addStretch();
    root->addWidget(customRow);

    auto *hint = new QLabel(
        QStringLiteral("Nur Zeiten innerhalb der Grenzen zählen für Ist und Saldo. "
                       "Erfasste Arbeitspakete außerhalb bleiben erhalten."),
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
    root->addWidget(buttons);

    connect(m_globalRadio, &QRadioButton::toggled, this, &DayBoundsDialog::updateUi);
    connect(m_customRadio, &QRadioButton::toggled, this, &DayBoundsDialog::updateUi);
    connect(buttons, &QDialogButtonBox::accepted, this, &QDialog::accept);
    connect(buttons, &QDialogButtonBox::rejected, this, &QDialog::reject);
}

void DayBoundsDialog::load()
{
    const DayBounds global =
        sanitizedDayBounds(AppSettings::instance().dayStartMinute(),
                           AppSettings::instance().dayEndMinute());
    m_globalLabel->setText(QStringLiteral("Aktuell %1").arg(global.label()));

    const DayBounds current = JournalStore::instance().boundsForDate(m_date);
    m_startEdit->setTime(minuteToTime(current.startMinute));
    m_endEdit->setTime(minuteToTime(current.endMinute));

    if (current.custom) {
        m_customRadio->setChecked(true);
    } else {
        m_globalRadio->setChecked(true);
    }
    updateUi();
}

void DayBoundsDialog::updateUi()
{
    const bool custom = m_customRadio->isChecked();
    m_startEdit->setEnabled(custom);
    m_endEdit->setEnabled(custom);
}

void DayBoundsDialog::accept()
{
    DayBounds bounds;
    if (m_customRadio->isChecked()) {
        bounds.custom = true;
        bounds.startMinute = timeToMinute(m_startEdit->time());
        bounds.endMinute = timeToMinute(m_endEdit->time());
        if (bounds.startMinute >= bounds.endMinute) {
            QMessageBox::warning(
                this,
                windowTitle(),
                QStringLiteral("Die Tagesgrenze „Von“ muss vor „Bis“ liegen."));
            return;
        }
    }

    QString error;
    if (!JournalStore::instance().setBoundsForDate(m_date, bounds, &error)) {
        QMessageBox::warning(
            this,
            windowTitle(),
            error.isEmpty() ? QStringLiteral("Die Tagesgrenzen konnten nicht gespeichert werden.")
                            : error);
        return;
    }
    QDialog::accept();
}
