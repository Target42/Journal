#include "AbsenceDialog.h"

#include <QDialogButtonBox>
#include <QFormLayout>
#include <QGroupBox>
#include <QHBoxLayout>
#include <QLabel>
#include <QMessageBox>
#include <QPushButton>
#include <QRadioButton>
#include <QDateEdit>
#include <QVBoxLayout>

AbsenceDialog::AbsenceDialog(const QDate &from, const QDate &to, QWidget *parent)
    : QDialog(parent)
{
    setWindowTitle(QStringLiteral("Urlaub / Krankheit"));
    setModal(true);
    setMinimumWidth(420);
    setupUi();

    const QDate start = from.isValid() ? from : QDate::currentDate();
    const QDate end = to.isValid() ? to : start;
    m_fromEdit->setDate(start);
    m_toEdit->setDate(end);
}

void AbsenceDialog::setupUi()
{
    auto *root = new QVBoxLayout(this);

    auto *form = new QFormLayout();
    m_fromEdit = new QDateEdit(this);
    m_fromEdit->setCalendarPopup(true);
    m_fromEdit->setDisplayFormat(QStringLiteral("dd.MM.yyyy"));
    m_fromEdit->setDateRange(QDate(1970, 1, 1), QDate(2100, 12, 31));

    m_toEdit = new QDateEdit(this);
    m_toEdit->setCalendarPopup(true);
    m_toEdit->setDisplayFormat(QStringLiteral("dd.MM.yyyy"));
    m_toEdit->setDateRange(QDate(1970, 1, 1), QDate(2100, 12, 31));

    form->addRow(QStringLiteral("Von:"), m_fromEdit);
    form->addRow(QStringLiteral("Bis:"), m_toEdit);
    root->addLayout(form);

    auto *typeGroup = new QGroupBox(QStringLiteral("Art"), this);
    auto *typeLayout = new QHBoxLayout(typeGroup);
    m_vacationRadio = new QRadioButton(QStringLiteral("Urlaub"), typeGroup);
    m_sickRadio = new QRadioButton(QStringLiteral("Krankheit"), typeGroup);
    m_clearRadio = new QRadioButton(QStringLiteral("Status entfernen"), typeGroup);
    m_vacationRadio->setChecked(true);
    typeLayout->addWidget(m_vacationRadio);
    typeLayout->addWidget(m_sickRadio);
    typeLayout->addWidget(m_clearRadio);
    typeLayout->addStretch();
    root->addWidget(typeGroup);

    auto *extentGroup = new QGroupBox(QStringLiteral("Umfang"), this);
    auto *extentLayout = new QHBoxLayout(extentGroup);
    m_fullRadio = new QRadioButton(QStringLiteral("Ganzer Tag"), extentGroup);
    m_halfRadio = new QRadioButton(QStringLiteral("Halber Tag"), extentGroup);
    m_fullRadio->setChecked(true);
    extentLayout->addWidget(m_fullRadio);
    extentLayout->addWidget(m_halfRadio);
    extentLayout->addStretch();
    root->addWidget(extentGroup);

    auto *hint = new QLabel(
        QStringLiteral("Beim Setzen werden nur Arbeitstage ohne Feiertag berücksichtigt. "
                       "An diesen Tagen gilt die Soll-Arbeitszeit (keine Mehr- oder Minderzeit)."),
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

    connect(m_clearRadio, &QRadioButton::toggled, this, &AbsenceDialog::updateExtentEnabled);
    connect(buttons, &QDialogButtonBox::accepted, this, &QDialog::accept);
    connect(buttons, &QDialogButtonBox::rejected, this, &QDialog::reject);
}

void AbsenceDialog::updateExtentEnabled()
{
    const bool enabled = !m_clearRadio->isChecked();
    m_fullRadio->setEnabled(enabled);
    m_halfRadio->setEnabled(enabled);
}

QDate AbsenceDialog::fromDate() const
{
    return m_fromEdit->date();
}

QDate AbsenceDialog::toDate() const
{
    return m_toEdit->date();
}

Absence AbsenceDialog::absence() const
{
    if (isClear()) {
        return {};
    }
    Absence absence;
    absence.type = m_sickRadio->isChecked() ? AbsenceType::Sick : AbsenceType::Vacation;
    absence.fraction = m_halfRadio->isChecked() ? 0.5 : 1.0;
    return absence;
}

bool AbsenceDialog::isClear() const
{
    return m_clearRadio->isChecked();
}

void AbsenceDialog::accept()
{
    if (!fromDate().isValid() || !toDate().isValid()) {
        QMessageBox::warning(this, windowTitle(),
                             QStringLiteral("Bitte einen gültigen Zeitraum angeben."));
        return;
    }
    QDialog::accept();
}
