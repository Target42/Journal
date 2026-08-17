#include "RetirementDialog.h"

#include "core/AppSettings.h"
#include "core/CalendarService.h"
#include "core/RetirementCalculator.h"

#include <QAbstractItemView>
#include <QCheckBox>
#include <QDateEdit>
#include <QDialogButtonBox>
#include <QFont>
#include <QFormLayout>
#include <QGroupBox>
#include <QHBoxLayout>
#include <QHeaderView>
#include <QLabel>
#include <QLocale>
#include <QMessageBox>
#include <QPushButton>
#include <QStringList>
#include <QTableWidget>
#include <QTableWidgetItem>
#include <QVBoxLayout>

namespace {
QTableWidgetItem *makeItem(const QString &text, bool numeric)
{
    auto *item = new QTableWidgetItem(text);
    item->setFlags(item->flags() & ~Qt::ItemIsEditable);
    if (numeric) {
        item->setTextAlignment(Qt::AlignRight | Qt::AlignVCenter);
    }
    return item;
}

QString workDaysLabel()
{
    const QLocale locale;
    const WorkSettings ws = AppSettings::instance().workSettings();
    QStringList names;
    for (int i = 0; i < 7; ++i) {
        if (ws.workDays[i]) {
            names.append(locale.dayName(i + 1, QLocale::ShortFormat));
        }
    }
    return names.isEmpty() ? QStringLiteral("keine") : names.join(QStringLiteral(", "));
}
} // namespace

RetirementDialog::RetirementDialog(QWidget *parent)
    : QDialog(parent)
{
    setWindowTitle(QStringLiteral("Rentenrechner"));
    setModal(true);
    setMinimumSize(860, 560);
    setupUi();
    loadFromSettings();

    connect(&CalendarService::instance(), &CalendarService::downloadProgress,
            this, &RetirementDialog::onDownloadProgress);
    connect(&CalendarService::instance(), &CalendarService::downloadFinished,
            this, &RetirementDialog::onDownloadFinished);
    connect(&AppSettings::instance(), &AppSettings::changed, this, [this]() {
        if (!m_busy) {
            recalculate();
        }
    });

    recalculate();
}

void RetirementDialog::setupUi()
{
    auto *root = new QVBoxLayout(this);
    root->setSpacing(12);

    auto *inputGroup = new QGroupBox(QStringLiteral("Zeitraum"), this);
    auto *form = new QFormLayout(inputGroup);

    m_fromEdit = new QDateEdit(inputGroup);
    m_fromEdit->setCalendarPopup(true);
    m_fromEdit->setDisplayFormat(QStringLiteral("dd.MM.yyyy"));
    m_fromEdit->setDateRange(QDate(1970, 1, 1), QDate(2100, 12, 31));
    form->addRow(QStringLiteral("Ab Datum:"), m_fromEdit);

    m_retirementEdit = new QDateEdit(inputGroup);
    m_retirementEdit->setCalendarPopup(true);
    m_retirementEdit->setDisplayFormat(QStringLiteral("dd.MM.yyyy"));
    m_retirementEdit->setDateRange(QDate(1970, 1, 1), QDate(2100, 12, 31));
    form->addRow(QStringLiteral("Renteneintritt:"), m_retirementEdit);

    m_lastWorkLabel = new QLabel(inputGroup);
    m_lastWorkLabel->setWordWrap(true);
    form->addRow(QString(), m_lastWorkLabel);

    m_prorateCheck = new QCheckBox(
        QStringLiteral("Urlaub im Austrittsjahr anteilig (1/12 je vollem Monat)"),
        inputGroup);
    form->addRow(QString(), m_prorateCheck);

    m_metaLabel = new QLabel(inputGroup);
    m_metaLabel->setWordWrap(true);
    form->addRow(QString(), m_metaLabel);
    root->addWidget(inputGroup);

    auto *buttonRow = new QHBoxLayout();
    m_calculateButton = new QPushButton(QStringLiteral("Berechnen"), this);
    m_downloadButton = new QPushButton(QStringLiteral("Feiertage herunterladen"), this);
    buttonRow->addWidget(m_calculateButton);
    buttonRow->addWidget(m_downloadButton);
    buttonRow->addStretch();
    root->addLayout(buttonRow);

    m_summaryLabel = new QLabel(this);
    m_summaryLabel->setWordWrap(true);
    m_summaryLabel->setTextFormat(Qt::RichText);
    root->addWidget(m_summaryLabel);

    m_table = new QTableWidget(0, 7, this);
    m_table->setHorizontalHeaderLabels({
        QStringLiteral("Jahr"),
        QStringLiteral("Zeitraum"),
        QStringLiteral("Arbeitstage"),
        QStringLiteral("Feiertage"),
        QStringLiteral("Urlaub"),
        QStringLiteral("Resttage"),
        QStringLiteral("Stunden"),
    });
    m_table->horizontalHeader()->setSectionResizeMode(QHeaderView::Stretch);
    m_table->horizontalHeader()->setSectionResizeMode(0, QHeaderView::ResizeToContents);
    m_table->horizontalHeader()->setSectionResizeMode(1, QHeaderView::ResizeToContents);
    m_table->verticalHeader()->setVisible(false);
    m_table->setEditTriggers(QAbstractItemView::NoEditTriggers);
    m_table->setSelectionBehavior(QAbstractItemView::SelectRows);
    m_table->setSelectionMode(QAbstractItemView::SingleSelection);
    m_table->setAlternatingRowColors(true);

    QFont mono = m_table->font();
    mono.setStyleHint(QFont::Monospace);
    mono.setFamily(QStringLiteral("Consolas"));
    m_table->setFont(mono);
    root->addWidget(m_table, 1);

    m_statusLabel = new QLabel(this);
    m_statusLabel->setWordWrap(true);
    root->addWidget(m_statusLabel);

    auto *hint = new QLabel(
        QStringLiteral("Gezählt werden die konfigurierten Arbeitstage. Feiertage, die auf "
                       "einen Arbeitstag fallen, und der Urlaub gehen ab. Übrig bleiben die "
                       "restlichen Arbeitstage bis zum Vortag des Renteneintritts. "
                       "Im laufenden Jahr wird bereits genommener Urlaub abgezogen."),
        this);
    hint->setWordWrap(true);
    root->addWidget(hint);

    auto *buttons = new QDialogButtonBox(QDialogButtonBox::Close, this);
    if (auto *close = buttons->button(QDialogButtonBox::Close)) {
        close->setText(QStringLiteral("Schließen"));
        close->setAutoDefault(false);
        close->setDefault(false);
    }
    root->addWidget(buttons);

    connect(m_fromEdit, &QDateEdit::dateChanged, this, &RetirementDialog::persistInputs);
    connect(m_fromEdit, &QDateEdit::dateChanged, this, &RetirementDialog::recalculate);
    connect(m_retirementEdit, &QDateEdit::dateChanged, this, &RetirementDialog::persistInputs);
    connect(m_retirementEdit, &QDateEdit::dateChanged, this, &RetirementDialog::recalculate);
    connect(m_prorateCheck, &QCheckBox::toggled, this, &RetirementDialog::persistInputs);
    connect(m_prorateCheck, &QCheckBox::toggled, this, &RetirementDialog::recalculate);
    connect(m_calculateButton, &QPushButton::clicked, this, &RetirementDialog::recalculate);
    connect(m_downloadButton, &QPushButton::clicked, this, &RetirementDialog::downloadMissingHolidays);
    connect(buttons, &QDialogButtonBox::rejected, this, &QDialog::reject);
}

void RetirementDialog::loadFromSettings()
{
    QSignalBlocker fromBlocker(m_fromEdit);
    QSignalBlocker retirementBlocker(m_retirementEdit);
    QSignalBlocker prorateBlocker(m_prorateCheck);

    m_fromEdit->setDate(QDate::currentDate());
    m_retirementEdit->setDate(AppSettings::instance().retirementDate());
    m_prorateCheck->setChecked(AppSettings::instance().prorateVacationInExitYear());
}

void RetirementDialog::persistInputs()
{
    AppSettings::instance().setRetirementDate(m_retirementEdit->date());
    AppSettings::instance().setProrateVacationInExitYear(m_prorateCheck->isChecked());
}

void RetirementDialog::setBusy(bool busy)
{
    m_busy = busy;
    m_fromEdit->setEnabled(!busy);
    m_retirementEdit->setEnabled(!busy);
    m_prorateCheck->setEnabled(!busy);
    m_calculateButton->setEnabled(!busy);
    m_downloadButton->setEnabled(!busy);
}

void RetirementDialog::recalculate()
{
    if (m_busy) {
        return;
    }

    const QLocale locale;
    const QDate lastWork = m_retirementEdit->date().addDays(-1);
    m_lastWorkLabel->setText(
        lastWork.isValid()
            ? QStringLiteral("Letzter Arbeitstag: %1")
                  .arg(locale.toString(lastWork, QStringLiteral("dd.MM.yyyy")))
            : QString());

    const WorkSettings ws = AppSettings::instance().workSettings();
    m_metaLabel->setText(
        QStringLiteral("Bundesland: %1  |  Jahresurlaub: %2 Tage  |  Arbeitstage: %3")
            .arg(AppSettings::instance().stateDisplayName(),
                 locale.toString(ws.annualVacationDays, 'f', 1),
                 workDaysLabel()));

    fillTable();
}

void RetirementDialog::fillTable()
{
    const RetirementPlan plan = RetirementCalculator::compute(
        m_fromEdit->date(), m_retirementEdit->date(), m_prorateCheck->isChecked());

    const QLocale locale;
    m_table->setRowCount(0);

    if (!plan.error.isEmpty()) {
        m_summaryLabel->setText(QStringLiteral("<b>%1</b>").arg(plan.error));
        m_statusLabel->setText(QString());
        m_downloadButton->setEnabled(false);
        return;
    }

    m_table->setRowCount(plan.years.size() + 1);
    int row = 0;
    for (const auto &year : plan.years) {
        m_table->setItem(row, 0, makeItem(QString::number(year.year), true));
        m_table->setItem(
            row, 1,
            makeItem(QStringLiteral("%1 – %2")
                         .arg(locale.toString(year.from, QStringLiteral("dd.MM.")),
                              locale.toString(year.to, QStringLiteral("dd.MM.yyyy"))),
                     false));
        m_table->setItem(row, 2, makeItem(locale.toString(year.workDays), true));
        m_table->setItem(
            row, 3,
            makeItem(year.holidaysAvailable ? locale.toString(year.holidaysOnWorkDays)
                                            : QStringLiteral("–"),
                     true));
        m_table->setItem(row, 4, makeItem(locale.toString(year.vacationDays, 'f', 1), true));
        m_table->setItem(row, 5, makeItem(locale.toString(year.remainingDays, 'f', 1), true));
        m_table->setItem(row, 6, makeItem(locale.toString(year.remainingHours, 'f', 2), true));
        ++row;
    }

    auto *sumLabel = makeItem(QStringLiteral("Summe"), false);
    QFont bold = sumLabel->font();
    bold.setBold(true);
    sumLabel->setFont(bold);
    m_table->setItem(row, 0, sumLabel);
    m_table->setItem(row, 1, makeItem(QString(), false));
    m_table->setItem(row, 2, makeItem(locale.toString(plan.totalWorkDays), true));
    m_table->setItem(row, 3, makeItem(locale.toString(plan.totalHolidays), true));
    m_table->setItem(row, 4, makeItem(locale.toString(plan.totalVacation, 'f', 1), true));
    m_table->setItem(row, 5, makeItem(locale.toString(plan.totalRemainingDays, 'f', 1), true));
    m_table->setItem(row, 6, makeItem(locale.toString(plan.totalRemainingHours, 'f', 2), true));
    for (int column = 2; column <= 6; ++column) {
        if (auto *item = m_table->item(row, column)) {
            item->setFont(bold);
        }
    }

    m_summaryLabel->setText(
        QStringLiteral("Noch <b>%1 Arbeitstage</b> (%2&nbsp;h) bis zur Rente.")
            .arg(locale.toString(plan.totalRemainingDays, 'f', 1),
                 locale.toString(plan.totalRemainingHours, 'f', 2)));

    m_downloadButton->setEnabled(!plan.missingHolidayYears.isEmpty());
    if (plan.missingHolidayYears.isEmpty()) {
        m_statusLabel->setText(
            QStringLiteral("Feiertage für %1 liegen lokal vor.")
                .arg(AppSettings::instance().stateDisplayName()));
    } else {
        QStringList years;
        for (int year : plan.missingHolidayYears) {
            years.append(QString::number(year));
        }
        m_statusLabel->setText(
            QStringLiteral("Feiertage fehlen für: %1. Bitte herunterladen, sonst werden "
                           "in diesen Jahren keine Feiertage abgezogen.")
                .arg(years.join(QStringLiteral(", "))));
    }
}

void RetirementDialog::downloadMissingHolidays()
{
    const RetirementPlan plan = RetirementCalculator::compute(
        m_fromEdit->date(), m_retirementEdit->date(), m_prorateCheck->isChecked());
    if (!plan.error.isEmpty()) {
        QMessageBox::warning(this, QStringLiteral("Rentenrechner"), plan.error);
        return;
    }
    if (plan.missingHolidayYears.isEmpty()) {
        m_statusLabel->setText(QStringLiteral("Feiertage liegen bereits vor."));
        return;
    }

    setBusy(true);
    m_statusLabel->setText(QStringLiteral("Lade Feiertage…"));
    CalendarService::instance().downloadPublicHolidayYears(plan.missingHolidayYears);
}

void RetirementDialog::onDownloadProgress(const QString &kind, int year, int current, int total)
{
    if (kind != QLatin1String("feiertage") || !m_busy) {
        return;
    }
    m_statusLabel->setText(
        QStringLiteral("Lade Feiertage %1 (%2 von %3)…").arg(year).arg(current).arg(total));
}

void RetirementDialog::onDownloadFinished(const QString &kind, int year, bool ok,
                                          const QString &message)
{
    Q_UNUSED(year);
    if (kind != QLatin1String("feiertage-jahre")) {
        return;
    }

    setBusy(false);
    fillTable();

    if (ok) {
        m_statusLabel->setText(message);
    } else {
        QMessageBox::warning(this, QStringLiteral("Feiertage"), message);
        m_statusLabel->setText(message);
    }
}
