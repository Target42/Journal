#include "AbsenceDialog.h"

#include <QDialogButtonBox>
#include <QFormLayout>
#include <QGridLayout>
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
    setWindowTitle(QStringLiteral("Abwesenheit"));
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
    auto *typeLayout = new QGridLayout(typeGroup);
    m_vacationRadio = new QRadioButton(QStringLiteral("Urlaub"), typeGroup);
    m_sickRadio = new QRadioButton(QStringLiteral("Krankheit"), typeGroup);
    m_paidRadio = new QRadioButton(QStringLiteral("Bezahlt frei"), typeGroup);
    m_compensatoryRadio = new QRadioButton(QStringLiteral("Zeitausgleich"), typeGroup);
    m_clearRadio = new QRadioButton(QStringLiteral("Status entfernen"), typeGroup);
    m_vacationRadio->setChecked(true);
    typeLayout->addWidget(m_vacationRadio, 0, 0);
    typeLayout->addWidget(m_sickRadio, 0, 1);
    typeLayout->addWidget(m_paidRadio, 0, 2);
    typeLayout->addWidget(m_compensatoryRadio, 1, 0);
    typeLayout->addWidget(m_clearRadio, 1, 1);
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
                       "Urlaub, Krankheit und bezahlt frei setzen Ist = Soll (keine Mehr- oder "
                       "Minderzeit). Zeitausgleich lässt das Soll bestehen und geht vom "
                       "Stundenkonto ab."),
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
    if (m_sickRadio->isChecked()) {
        absence.type = AbsenceType::Sick;
    } else if (m_paidRadio->isChecked()) {
        absence.type = AbsenceType::PaidLeave;
    } else if (m_compensatoryRadio->isChecked()) {
        absence.type = AbsenceType::Compensatory;
    } else {
        absence.type = AbsenceType::Vacation;
    }
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
