#include "YearView.h"

#include "core/AppSettings.h"
#include "core/CalendarService.h"
#include "core/JournalStore.h"
#include "core/TimeTotals.h"

#include <QAbstractItemView>
#include <QColor>
#include <QDate>
#include <QFont>
#include <QHBoxLayout>
#include <QHeaderView>
#include <QLabel>
#include <QLocale>
#include <QPalette>
#include <QPushButton>
#include <QTableWidget>
#include <QTableWidgetItem>
#include <QVBoxLayout>

YearView::YearView(QWidget *parent)
    : QWidget(parent)
    , m_year(QDate::currentDate().year())
    , m_selectedMonth(QDate::currentDate().month())
{
    setupUi();

    connect(&CalendarService::instance(), &CalendarService::yearDataChanged,
            this, [this](int year) {
                if (year == m_year) {
                    refresh();
                }
            });
    connect(&AppSettings::instance(), &AppSettings::changed, this, [this]() { refresh(); });
    connect(&JournalStore::instance(), &JournalStore::dataReloaded, this, [this]() { refresh(); });

    auto &totals = TimeTotals::instance();
    connect(&totals, &TimeTotals::monthRecalculated, this, [this](int year, int month) {
        if (year == m_year) {
            fillMonthRow(month);
        }
    });
    connect(&totals, &TimeTotals::yearRecalculated, this, [this](int year) {
        if (year == m_year) {
            updateYearHeader();
        }
    });

    CalendarService::instance().ensureYearLoaded(m_year);
    refresh();
}

void YearView::setupUi()
{
    auto *layout = new QVBoxLayout(this);
    layout->setContentsMargins(0, 0, 0, 0);
    layout->setSpacing(4);

    auto *navRow = new QHBoxLayout();
    m_prevButton = new QPushButton(QStringLiteral("◀"), this);
    m_prevButton->setFixedWidth(36);
    m_prevButton->setToolTip(QStringLiteral("Vorheriges Jahr"));

    m_headerLabel = new QLabel(this);
    m_headerLabel->setAlignment(Qt::AlignCenter);
    m_headerLabel->setWordWrap(true);

    m_nextButton = new QPushButton(QStringLiteral("▶"), this);
    m_nextButton->setFixedWidth(36);
    m_nextButton->setToolTip(QStringLiteral("Nächstes Jahr"));

    navRow->addWidget(m_prevButton);
    navRow->addWidget(m_headerLabel, 1);
    navRow->addWidget(m_nextButton);
    layout->addLayout(navRow);

    m_vacationLabel = new QLabel(this);
    m_vacationLabel->setAlignment(Qt::AlignCenter);
    m_vacationLabel->setWordWrap(true);
    m_vacationLabel->setTextFormat(Qt::RichText);
    layout->addWidget(m_vacationLabel);

    m_monthTable = new QTableWidget(12, 7, this);
    m_monthTable->setHorizontalHeaderLabels({
        QStringLiteral("Monat"),
        QStringLiteral("Soll (h)"),
        QStringLiteral("Ist (h)"),
        QStringLiteral("Saldo (h)"),
        QStringLiteral("Konto (h)"),
        QStringLiteral("genommen"),
        QStringLiteral("geplant"),
    });
    m_monthTable->horizontalHeaderItem(5)->setToolTip(QStringLiteral("Genommene Urlaubstage"));
    m_monthTable->horizontalHeaderItem(6)->setToolTip(QStringLiteral("Geplante Urlaubstage"));
    m_monthTable->horizontalHeader()->setSectionResizeMode(QHeaderView::Stretch);
    m_monthTable->horizontalHeader()->setSectionResizeMode(0, QHeaderView::ResizeToContents);
    m_monthTable->verticalHeader()->setVisible(false);
    m_monthTable->setEditTriggers(QAbstractItemView::NoEditTriggers);
    m_monthTable->setSelectionBehavior(QAbstractItemView::SelectRows);
    m_monthTable->setSelectionMode(QAbstractItemView::SingleSelection);
    m_monthTable->setAlternatingRowColors(true);

    QFont mono = m_monthTable->font();
    mono.setStyleHint(QFont::Monospace);
    mono.setFamily(QStringLiteral("Consolas"));
    m_monthTable->setFont(mono);

    layout->addWidget(m_monthTable);

    connect(m_prevButton, &QPushButton::clicked, this, &YearView::goPreviousYear);
    connect(m_nextButton, &QPushButton::clicked, this, &YearView::goNextYear);
    connect(m_monthTable, &QTableWidget::cellClicked, this, &YearView::onRowClicked);
}

void YearView::setYear(int year)
{
    if (year < 1970 || year > 2100 || year == m_year) {
        return;
    }
    m_year = year;
    CalendarService::instance().ensureYearLoaded(m_year);
    refresh();
    emit yearChanged(m_year);
}

void YearView::selectMonth(int month)
{
    if (month < 1 || month > 12) {
        return;
    }
    m_selectedMonth = month;
    m_monthTable->selectRow(month - 1);
}

void YearView::goPreviousYear()
{
    setYear(m_year - 1);
}

void YearView::goNextYear()
{
    setYear(m_year + 1);
}

void YearView::onRowClicked(int row, int /*column*/)
{
    if (row < 0 || row > 11) {
        return;
    }
    m_selectedMonth = row + 1;
    emit monthActivated(m_year, m_selectedMonth);
}

void YearView::setHoursItem(int row, int column, double hours, bool saldo)
{
    auto *item = m_monthTable->item(row, column);
    if (!item) {
        item = new QTableWidgetItem();
        item->setFlags(item->flags() & ~Qt::ItemIsEditable);
        item->setTextAlignment(Qt::AlignRight | Qt::AlignVCenter);
        m_monthTable->setItem(row, column, item);
    }

    const QLocale locale;
    if (saldo) {
        if (hours > 0.005) {
            item->setForeground(QColor(0, 128, 0));
            item->setText(locale.toString(hours, 'f', 2));
        } else if (hours < -0.005) {
            item->setForeground(QColor(180, 0, 0));
            item->setText(locale.toString(-hours, 'f', 2));
        } else {
            item->setForeground(m_monthTable->palette().color(QPalette::Text));
            item->setText(locale.toString(0.0, 'f', 2));
        }
    } else {
        item->setForeground(m_monthTable->palette().color(QPalette::Text));
        item->setText(locale.toString(hours, 'f', 2));
    }
}

void YearView::fillMonthRow(int month)
{
    if (month < 1 || month > 12) {
        return;
    }

    const QLocale locale;
    const QDate date(m_year, month, 1);
    auto *nameItem = m_monthTable->item(month - 1, 0);
    if (!nameItem) {
        nameItem = new QTableWidgetItem();
        nameItem->setFlags(nameItem->flags() & ~Qt::ItemIsEditable);
        m_monthTable->setItem(month - 1, 0, nameItem);
    }
    nameItem->setText(locale.toString(date, QStringLiteral("MMMM")));

    const MonthTotals totals = TimeTotals::instance().monthTotals(m_year, month);
    setHoursItem(month - 1, 1, totals.targetHours, false);
    setHoursItem(month - 1, 2, totals.actualHours, false);
    setHoursItem(month - 1, 3, totals.monthSaldo, true);
    setHoursItem(month - 1, 4, totals.closingSaldo, true);
    setDaysItem(month - 1, 5, totals.vacationTaken);
    setDaysItem(month - 1, 6, totals.vacationPlanned);
}

void YearView::setDaysItem(int row, int column, double days)
{
    auto *item = m_monthTable->item(row, column);
    if (!item) {
        item = new QTableWidgetItem();
        item->setFlags(item->flags() & ~Qt::ItemIsEditable);
        item->setTextAlignment(Qt::AlignRight | Qt::AlignVCenter);
        m_monthTable->setItem(row, column, item);
    }

    item->setForeground(m_monthTable->palette().color(QPalette::Text));
    item->setText(QLocale().toString(days, 'f', 1));
}

void YearView::updateYearHeader()
{
    const QLocale locale;
    const YearTotals totals = TimeTotals::instance().yearTotals(m_year);

    auto coloredHours = [&locale](double hours) {
        const QString text = locale.toString(qAbs(hours), 'f', 2);
        if (hours > 0.005) {
            return QStringLiteral("<span style=\"color:#008000;\">%1</span>").arg(text);
        }
        if (hours < -0.005) {
            return QStringLiteral("<span style=\"color:#b40000;\">%1</span>").arg(text);
        }
        return text;
    };

    m_headerLabel->setTextFormat(Qt::RichText);
    QString header = QStringLiteral("Jahr %1 – Soll: %2  |  Ist: %3  |  Saldo: %4  |  Konto: %5")
                         .arg(QString::number(m_year),
                              locale.toString(totals.targetHours, 'f', 2),
                              locale.toString(totals.actualHours, 'f', 2),
                              coloredHours(totals.saldo),
                              coloredHours(totals.closingSaldo));
    if (qAbs(totals.clippedHours) > 0.005) {
        header += QStringLiteral("  |  Abgeschnitten: <span style=\"color:#b35c00;\">%1</span>")
                      .arg(locale.toString(qAbs(totals.clippedHours), 'f', 2));
    }
    m_headerLabel->setText(header);

    const double entitlement = AppSettings::instance().workSettings().annualVacationDays;
    const double remaining = entitlement - totals.vacationTaken;
    QString remainingText = locale.toString(remaining, 'f', 1);
    if (remaining > 0.005) {
        remainingText = QStringLiteral("<span style=\"color:#008000;\">%1</span>").arg(remainingText);
    } else if (remaining < -0.005) {
        remainingText = QStringLiteral("<span style=\"color:#b40000;\">%1</span>").arg(remainingText);
    }

    m_vacationLabel->setText(
        QStringLiteral("Urlaub: Anspruch %1  |  genommen %2  |  geplant %3  |  Rest %4")
            .arg(locale.toString(entitlement, 'f', 1),
                 locale.toString(totals.vacationTaken, 'f', 1),
                 locale.toString(totals.vacationPlanned, 'f', 1),
                 remainingText));
}

void YearView::refresh()
{
    TimeTotals::instance().ensureYear(m_year);
    CalendarService::instance().ensureYearLoaded(m_year);

    updateYearHeader();
    for (int month = 1; month <= 12; ++month) {
        fillMonthRow(month);
    }

    if (m_selectedMonth >= 1 && m_selectedMonth <= 12) {
        m_monthTable->selectRow(m_selectedMonth - 1);
    }
}
