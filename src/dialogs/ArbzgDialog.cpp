#include "ArbzgDialog.h"

#include "core/ArbzgRules.h"

#include <QAbstractItemView>
#include <QColor>
#include <QComboBox>
#include <algorithm>

#include <QComboBox>
#include <QDialogButtonBox>
#include <QFile>
#include <QFileDialog>
#include <QFormLayout>
#include <QGroupBox>
#include <QHBoxLayout>
#include <QHeaderView>
#include <QLabel>
#include <QLocale>
#include <QMessageBox>
#include <QPushButton>
#include <QSpinBox>
#include <QTableWidget>
#include <QTableWidgetItem>
#include <QVBoxLayout>

namespace {
QTableWidgetItem *makeItem(const QString &text, bool numeric = false)
{
    auto *item = new QTableWidgetItem(text);
    item->setFlags(item->flags() & ~Qt::ItemIsEditable);
    if (numeric) {
        item->setTextAlignment(Qt::AlignRight | Qt::AlignVCenter);
    }
    return item;
}

QString periodLine(const QString &title, const ArbzgPeriod &period)
{
    const QLocale locale;
    const QString color = period.averageExceeded ? QStringLiteral("#b40000")
                                                 : QStringLiteral("#008000");
    return QStringLiteral("%1 (%2–%3): <span style=\"color:%4;\">%5 h</span> je Werktag")
        .arg(title,
             locale.toString(period.from, QStringLiteral("dd.MM.yyyy")),
             locale.toString(period.to, QStringLiteral("dd.MM.yyyy")),
             color,
             locale.toString(period.averageWeekdayHours, 'f', 2));
}
} // namespace

ArbzgDialog::ArbzgDialog(int year, int month, QWidget *parent)
    : QDialog(parent)
    , m_year(year)
    , m_month(month)
{
    setWindowTitle(QStringLiteral("ArbZG"));
    setModal(true);
    setMinimumSize(920, 620);
    setupUi();
    refresh();
}

void ArbzgDialog::setupUi()
{
    auto *root = new QVBoxLayout(this);
    root->setSpacing(10);

    auto *nav = new QHBoxLayout();
    nav->addWidget(new QLabel(QStringLiteral("Jahr:"), this));
    m_yearSpin = new QSpinBox(this);
    m_yearSpin->setRange(1970, 2100);
    m_yearSpin->setValue(m_year);
    nav->addWidget(m_yearSpin);
    nav->addSpacing(16);
    nav->addWidget(new QLabel(QStringLiteral("Nachweis-Monat:"), this));
    m_monthCombo = new QComboBox(this);
    const QLocale locale;
    for (int month = 1; month <= 12; ++month) {
        m_monthCombo->addItem(locale.monthName(month), month);
    }
    m_monthCombo->setCurrentIndex(qBound(1, m_month, 12) - 1);
    nav->addWidget(m_monthCombo);
    nav->addStretch();
    auto *saveButton = new QPushButton(QStringLiteral("Nachweis als HTML speichern…"), this);
    nav->addWidget(saveButton);
    root->addLayout(nav);

    auto *averageGroup = new QGroupBox(QStringLiteral("Höchstarbeitszeit §3 (rollierend bis heute)"), this);
    auto *averageLayout = new QVBoxLayout(averageGroup);
    m_averageLabel = new QLabel(averageGroup);
    m_averageLabel->setWordWrap(true);
    m_averageLabel->setTextFormat(Qt::RichText);
    averageLayout->addWidget(m_averageLabel);
    root->addWidget(averageGroup);

    auto *yearGroup = new QGroupBox(QStringLiteral("Jahr"), this);
    auto *yearLayout = new QVBoxLayout(yearGroup);
    m_yearLabel = new QLabel(yearGroup);
    m_yearLabel->setWordWrap(true);
    m_yearLabel->setTextFormat(Qt::RichText);
    yearLayout->addWidget(m_yearLabel);
    root->addWidget(yearGroup);

    m_table = new QTableWidget(0, 4, this);
    m_table->setHorizontalHeaderLabels({
        QStringLiteral("Tag"),
        QStringLiteral("Arbeitszeit"),
        QStringLiteral("Pause"),
        QStringLiteral("Hinweise"),
    });
    m_table->verticalHeader()->setVisible(false);
    m_table->setEditTriggers(QAbstractItemView::NoEditTriggers);
    m_table->setSelectionBehavior(QAbstractItemView::SelectRows);
    m_table->setWordWrap(true);
    m_table->horizontalHeader()->setStretchLastSection(true);
    m_table->horizontalHeader()->setSectionResizeMode(0, QHeaderView::ResizeToContents);
    m_table->horizontalHeader()->setSectionResizeMode(1, QHeaderView::ResizeToContents);
    m_table->horizontalHeader()->setSectionResizeMode(2, QHeaderView::ResizeToContents);
    root->addWidget(m_table, 1);

    auto *hint = new QLabel(
        QStringLiteral("Hinweise, keine Sperre. Das Stundenkonto bleibt unverändert "
                       "(Netto inkl. automatischem Pausenabzug). ArbZG rechnet mit der "
                       "erfassten Rohzeit ohne Tagesgrenzen."),
        this);
    hint->setWordWrap(true);
    root->addWidget(hint);

    auto *buttons = new QDialogButtonBox(QDialogButtonBox::Close, this);
    if (auto *close = buttons->button(QDialogButtonBox::Close)) {
        close->setText(QStringLiteral("Schließen"));
    }
    root->addWidget(buttons);

    connect(m_yearSpin, &QSpinBox::valueChanged, this, [this](int year) {
        m_year = year;
        refresh();
    });
    connect(saveButton, &QPushButton::clicked, this, &ArbzgDialog::saveNachweis);
    connect(buttons, &QDialogButtonBox::rejected, this, &QDialog::reject);
    connect(buttons, &QDialogButtonBox::accepted, this, &QDialog::accept);
}

void ArbzgDialog::refresh()
{
    const ArbzgSummary summary = ArbzgCompliance::summarizeYear(m_year);
    const QLocale locale;

    QString average = periodLine(QStringLiteral("6 Kalendermonate"), summary.sixMonths);
    average += QStringLiteral("<br>") + periodLine(QStringLiteral("24 Wochen"), summary.twentyFourWeeks);
    if (summary.compensationFailed) {
        average += QStringLiteral(
            "<br><span style=\"color:#b40000;\">Ausgleich verfehlt: in beiden Zeiträumen "
            "liegen mehr als 8 Stunden je Werktag (Mo–Sa).</span>");
    } else {
        average += QStringLiteral(
            "<br>Ausgleich erfüllt, wenn mindestens ein Zeitraum ≤ 8,00 h bleibt. "
            "Tage über 10 Stunden sind unabhängig davon unzulässig.");
    }
    m_averageLabel->setText(average);

    QString yearText =
        QStringLiteral("Tage &gt; 8 h: %1  ·  Tage &gt; 10 h: %2  ·  Pausenverstöße: %3  ·  "
                       "Ruhezeit &lt; 11 h: %4")
            .arg(locale.toString(summary.daysOverEight),
                 locale.toString(summary.daysOverTen),
                 locale.toString(summary.pauseViolations),
                 locale.toString(summary.restViolations));
    yearText += QStringLiteral("<br>Sonntagsarbeit: %1  ·  Feiertagsarbeit: %2  ·  "
                               "freie Sonntage: %3 von %4 (mindestens 15)")
                    .arg(locale.toString(summary.sundayWorkDays),
                         locale.toString(summary.holidayWorkDays),
                         locale.toString(summary.freeSundays),
                         locale.toString(summary.sundaysInYear));
    if (summary.tooFewFreeSundays) {
        yearText += QStringLiteral(
            "  <span style=\"color:#b40000;\">zu wenige freie Sonntage (§11)</span>");
    }
    if (summary.ersatzruheMissing > 0) {
        yearText += QStringLiteral(
            "  ·  <span style=\"color:#b40000;\">Ersatzruhe fehlt: %1</span>")
                        .arg(locale.toString(summary.ersatzruheMissing));
    }
    yearText += QStringLiteral("<br>Nachtarbeitstage: %1 (Nachtarbeitnehmer ab 48)")
                    .arg(locale.toString(summary.nightWorkDays));
    if (summary.nightWorker) {
        yearText += QStringLiteral(
            "  <span style=\"color:#b35c00;\">Nachtarbeitnehmer: engerer 8-Stunden-Ausgleich "
            "in 4 Wochen / 1 Monat (§6)</span>");
    }
    if (summary.usualPauseHints > 0) {
        yearText += QStringLiteral("<br>Übliche Pause verpasst: %1 Tag(e)")
                        .arg(locale.toString(summary.usualPauseHints));
    }
    m_yearLabel->setText(yearText);

    QVector<ArbzgDay> rows = summary.issueDays;
    rows.append(summary.noteDays);
    std::sort(rows.begin(), rows.end(), [](const ArbzgDay &a, const ArbzgDay &b) {
        return a.date < b.date;
    });

    m_table->setRowCount(rows.size());
    for (int i = 0; i < rows.size(); ++i) {
        const ArbzgDay &day = rows.at(i);
        m_table->setItem(i, 0, makeItem(locale.toString(day.date, QStringLiteral("ddd, dd.MM.yyyy"))));
        m_table->setItem(i, 1, makeItem(ArbzgCompliance::formatDuration(day.rawWorkMinutes), true));
        m_table->setItem(i, 2, makeItem(ArbzgCompliance::formatDuration(day.actualPauseMinutes), true));
        const QStringList all = day.issues + day.notes;
        auto *hintItem = makeItem(all.join(QStringLiteral(" · ")));
        if (day.hasIssue()) {
            hintItem->setForeground(QColor(180, 0, 0));
        } else {
            hintItem->setForeground(QColor(179, 92, 0));
        }
        m_table->setItem(i, 3, hintItem);
    }
    m_table->resizeRowsToContents();
}

void ArbzgDialog::saveNachweis()
{
    const int month = m_monthCombo->currentData().toInt();
    const QString suggested =
        QStringLiteral("Arbeitszeitnachweis-%1-%2.html")
            .arg(m_year, 4, 10, QLatin1Char('0'))
            .arg(month, 2, 10, QLatin1Char('0'));
    const QString path = QFileDialog::getSaveFileName(
        this,
        QStringLiteral("Arbeitszeitnachweis speichern"),
        suggested,
        QStringLiteral("HTML (*.html)"));
    if (path.isEmpty()) {
        return;
    }

    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        QMessageBox::warning(this, QStringLiteral("Nachweis"),
                             QStringLiteral("Die Datei konnte nicht geschrieben werden."));
        return;
    }
    file.write(ArbzgCompliance::nachweisHtml(m_year, month).toUtf8());
    QMessageBox::information(this, QStringLiteral("Nachweis"),
                             QStringLiteral("Nachweis gespeichert."));
}
