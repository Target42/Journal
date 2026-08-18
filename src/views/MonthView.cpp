#include "MonthView.h"

#include "core/Absence.h"
#include "core/AppSettings.h"
#include "core/ArbzgRules.h"
#include "core/CalendarService.h"
#include "core/JournalStore.h"
#include "core/TimeTotals.h"
#include "core/WorkPackage.h"
#include "dialogs/AbsenceDialog.h"
#include "dialogs/DayBoundsDialog.h"
#include "dialogs/DayPackagesDialog.h"

#include <QAbstractItemView>
#include <QAction>
#include <QBrush>
#include <QColor>
#include <QContextMenuEvent>
#include <QEvent>
#include <QFont>
#include <QFontMetrics>
#include <QHBoxLayout>
#include <QHeaderView>
#include <QLabel>
#include <QLocale>
#include <QMenu>
#include <QMessageBox>
#include <QModelIndex>
#include <QPalette>
#include <QPoint>
#include <QPushButton>
#include <QStringList>
#include <QTableWidget>
#include <QTableWidgetItem>
#include <QTimer>
#include <QVBoxLayout>

namespace {
enum MonthColumn {
    ColDay = 0,
    ColStart,
    ColEnd,
    ColActual,
    ColTarget,
    ColSaldo,
    ColHint,
    ColCount
};

QColor weekendColor()
{
    return QColor(232, 232, 240);
}

QColor schoolHolidayColor()
{
    return QColor(255, 243, 196);
}

QColor publicHolidayColor()
{
    return QColor(250, 212, 212);
}

QColor weekendAndSchoolColor()
{
    return QColor(232, 228, 200);
}

QColor vacationColor()
{
    return QColor(210, 232, 255);
}

QColor sickColor()
{
    return QColor(255, 228, 196);
}

QString formatHours(double hours)
{
    return QLocale().toString(hours, 'f', 2);
}

QString formatClock(int minute)
{
    if (minute < 0) {
        return {};
    }
    if (minute >= 24 * 60) {
        return QStringLiteral("24:00");
    }
    return minuteToTime(minute).toString(QStringLiteral("HH:mm"));
}

void workSpan(const QDate &date, int *startMinute, int *endMinute)
{
    *startMinute = -1;
    *endMinute = -1;
    const auto packages = JournalStore::instance().packagesForDate(date);
    for (const auto &pkg : packages) {
        const int start = pkg.startMinute();
        const int end = pkg.endMinute(date);
        if (*startMinute < 0 || start < *startMinute) {
            *startMinute = start;
        }
        if (*endMinute < 0 || end > *endMinute) {
            *endMinute = end;
        }
    }
}

bool isCountableAbsenceDay(const QDate &date)
{
    if (!date.isValid() || CalendarService::instance().isPublicHoliday(date)) {
        return false;
    }
    return AppSettings::instance().targetHoursForDate(date) > 0.0;
}

QVector<QDate> datesInRange(const QDate &from, const QDate &to, bool onlyCountable)
{
    QVector<QDate> dates;
    if (!from.isValid() || !to.isValid()) {
        return dates;
    }
    QDate start = from <= to ? from : to;
    const QDate end = from <= to ? to : from;
    for (; start <= end; start = start.addDays(1)) {
        if (!onlyCountable || isCountableAbsenceDay(start)) {
            dates.append(start);
        }
    }
    return dates;
}
} // namespace

MonthView::MonthView(QWidget *parent)
    : QWidget(parent)
    , m_month(QDate::currentDate().year(), QDate::currentDate().month(), 1)
{
    setupUi();

    connect(&CalendarService::instance(), &CalendarService::yearDataChanged,
            this, [this](int year) {
                if (year == m_month.year()) {
                    refresh();
                }
            });

    connect(&AppSettings::instance(), &AppSettings::changed,
            this, &MonthView::refresh);

    connect(&JournalStore::instance(), &JournalStore::dataReloaded,
            this, &MonthView::refresh);

    auto &totals = TimeTotals::instance();
    connect(&totals, &TimeTotals::dayRecalculated, this, [this](const QDate &date) {
        if (date.year() == m_month.year() && date.month() == m_month.month()) {
            fillDayRow(date.day());
            updateSummary();
        }
    });
    connect(&totals, &TimeTotals::monthRecalculated, this, [this](int year, int month) {
        if (year == m_month.year() && month == m_month.month()) {
            const int days = m_month.daysInMonth();
            for (int day = 1; day <= days; ++day) {
                fillDayRow(day);
            }
            updateSummary();
        }
    });

    connect(m_dayTable, &QTableWidget::cellClicked, this, &MonthView::onRowClicked);
    connect(m_dayTable, &QTableWidget::cellDoubleClicked, this, &MonthView::onRowDoubleClicked);
    m_dayTable->viewport()->installEventFilter(this);
    connect(m_absenceButton, &QPushButton::clicked, this, &MonthView::openAbsenceDialog);

    CalendarService::instance().ensureYearLoaded(m_month.year());
    refresh();
}

void MonthView::setupUi()
{
    auto *layout = new QVBoxLayout(this);
    layout->setContentsMargins(0, 0, 0, 0);
    layout->setSpacing(4);

    auto *headerRow = new QHBoxLayout();
    headerRow->setContentsMargins(0, 0, 0, 0);
    headerRow->setSpacing(8);
    m_summaryLabel = new QLabel(this);
    m_summaryLabel->setWordWrap(true);
    headerRow->addWidget(m_summaryLabel, 1);
    m_absenceButton = new QPushButton(QStringLiteral("Urlaub / Krankheit…"), this);
    m_absenceButton->setAutoDefault(false);
    m_absenceButton->setDefault(false);
    headerRow->addWidget(m_absenceButton, 0, Qt::AlignTop);
    layout->addLayout(headerRow);

    m_dayTable = new QTableWidget(0, ColCount, this);
    m_dayTable->setHorizontalHeaderLabels({
        QStringLiteral("Tag"),
        QStringLiteral("Anfang"),
        QStringLiteral("Ende"),
        QStringLiteral("Ist"),
        QStringLiteral("Soll"),
        QStringLiteral("Saldo"),
        QStringLiteral("Titel"),
    });
    m_dayTable->verticalHeader()->setVisible(false);
    m_dayTable->setEditTriggers(QAbstractItemView::NoEditTriggers);
    m_dayTable->setSelectionBehavior(QAbstractItemView::SelectRows);
    m_dayTable->setAlternatingRowColors(false);
    m_dayTable->setShowGrid(true);

    QFont mono = m_dayTable->font();
    mono.setStyleHint(QFont::Monospace);
    mono.setFamily(QStringLiteral("Consolas"));
    m_dayTable->setFont(mono);

    const QFontMetrics fm(mono);
    const int clockColumnWidth =
        qMax(fm.horizontalAdvance(QStringLiteral("Anfang")),
             fm.horizontalAdvance(QStringLiteral("00:00")))
        + 28;
    const int hoursColumnWidth =
        qMax(fm.horizontalAdvance(QStringLiteral("Saldo")),
             fm.horizontalAdvance(QStringLiteral("00:00")))
        + 28;

    auto *header = m_dayTable->horizontalHeader();
    header->setStretchLastSection(true);
    header->setSectionResizeMode(ColDay, QHeaderView::ResizeToContents);
    header->setSectionResizeMode(ColStart, QHeaderView::Fixed);
    header->setSectionResizeMode(ColEnd, QHeaderView::Fixed);
    header->setSectionResizeMode(ColActual, QHeaderView::Fixed);
    header->setSectionResizeMode(ColTarget, QHeaderView::Fixed);
    header->setSectionResizeMode(ColSaldo, QHeaderView::Fixed);
    header->setSectionResizeMode(ColHint, QHeaderView::Stretch);
    m_dayTable->setColumnWidth(ColStart, clockColumnWidth);
    m_dayTable->setColumnWidth(ColEnd, clockColumnWidth);
    m_dayTable->setColumnWidth(ColActual, hoursColumnWidth);
    m_dayTable->setColumnWidth(ColTarget, hoursColumnWidth);
    m_dayTable->setColumnWidth(ColSaldo, hoursColumnWidth);

    layout->addWidget(m_dayTable);
}

bool MonthView::eventFilter(QObject *watched, QEvent *event)
{
    if (watched == m_dayTable->viewport() && event->type() == QEvent::ContextMenu) {
        const auto *contextEvent = static_cast<QContextMenuEvent *>(event);
        const QPoint pos = contextEvent->pos();
        QTimer::singleShot(0, this, [this, pos]() { popupDayMenu(pos); });
        return true;
    }
    return QWidget::eventFilter(watched, event);
}

void MonthView::setMonth(int year, int month)
{
    if (month < 1 || month > 12) {
        return;
    }

    const QDate next(year, month, 1);
    if (!next.isValid()) {
        return;
    }

    m_month = next;
    CalendarService::instance().ensureYearLoaded(m_month.year());
    refresh();
}

void MonthView::selectDate(const QDate &date)
{
    if (!date.isValid() || date.year() != m_month.year() || date.month() != m_month.month()) {
        return;
    }
    m_dayTable->selectRow(date.day() - 1);
}

void MonthView::onRowClicked(int row, int /*column*/)
{
    if (row < 0 || row >= m_dayTable->rowCount()) {
        return;
    }
    emit dayActivated(QDate(m_month.year(), m_month.month(), row + 1));
}

void MonthView::onRowDoubleClicked(int row, int /*column*/)
{
    openDayPackagesDialog(dateFromRow(row));
}

void MonthView::openDayPackagesDialog(const QDate &date)
{
    if (!date.isValid()) {
        return;
    }
    emit dayActivated(date);
    DayPackagesDialog dialog(date, this);
    dialog.exec();
}

void MonthView::setTextItem(int row, int column, const QString &text, bool rightAlign)
{
    auto *item = m_dayTable->item(row, column);
    if (!item) {
        item = new QTableWidgetItem();
        item->setFlags(item->flags() & ~Qt::ItemIsEditable);
        m_dayTable->setItem(row, column, item);
    }
    if (rightAlign) {
        item->setTextAlignment(Qt::AlignRight | Qt::AlignVCenter);
    }
    item->setText(text);
}

void MonthView::setHoursItem(int row, int column, double hours, bool saldo)
{
    auto *item = m_dayTable->item(row, column);
    if (!item) {
        item = new QTableWidgetItem();
        item->setFlags(item->flags() & ~Qt::ItemIsEditable);
        item->setTextAlignment(Qt::AlignRight | Qt::AlignVCenter);
        m_dayTable->setItem(row, column, item);
    } else {
        item->setTextAlignment(Qt::AlignRight | Qt::AlignVCenter);
    }

    if (saldo) {
        if (hours > 0.005) {
            item->setForeground(QColor(0, 128, 0));
            item->setText(formatHours(hours));
        } else if (hours < -0.005) {
            item->setForeground(QColor(180, 0, 0));
            item->setText(formatHours(-hours));
        } else {
            item->setForeground(m_dayTable->palette().color(QPalette::Text));
            item->setText(formatHours(0.0));
        }
    } else {
        item->setForeground(m_dayTable->palette().color(QPalette::Text));
        item->setText(formatHours(hours));
    }
}

void MonthView::fillDayRow(int day)
{
    const int days = m_month.daysInMonth();
    if (day < 1 || day > days) {
        return;
    }

    const QLocale locale;
    const QDate date(m_month.year(), m_month.month(), day);
    const int row = day - 1;
    const QDate today = QDate::currentDate();

    auto &calendar = CalendarService::instance();
    auto &settings = AppSettings::instance();

    const QString dayText = QStringLiteral("%1  %2")
                                .arg(locale.toString(date, QStringLiteral("ddd")), 2)
                                .arg(day, 2, 10, QLatin1Char('0'));

    QStringList hints;
    if (calendar.isPublicHoliday(date)) {
        hints << calendar.publicHolidayName(date);
    } else {
        const QString eve = eveDayName(date);
        if (!eve.isEmpty()) {
            if (settings.isCompanyFreeEveDate(date)) {
                hints << QStringLiteral("%1 (frei)").arg(eve);
            } else {
                hints << eve;
            }
        }
    }
    if (calendar.isSchoolHoliday(date)) {
        hints << calendar.schoolHolidayName(date);
    }
    const Absence absence = TimeTotals::instance().effectiveAbsenceForDate(date);
    if (absence.isSet()) {
        hints << absence.label();
    }
    ArbzgDay arbzg;
    if (date <= today) {
        arbzg = ArbzgCompliance::assessDay(date);
        if (arbzg.hasIssue() || !arbzg.notes.isEmpty()) {
            hints << QStringLiteral("ArbZG");
        }
    }
    const QString hint = hints.join(QStringLiteral(" · "));

    const double target = calendar.isPublicHoliday(date)
                              ? 0.0
                              : settings.targetHoursForDate(date);
    const double actual = TimeTotals::instance().creditedHoursForDate(date);
    const double saldo = actual - target;
    int startMinute = -1;
    int endMinute = -1;
    workSpan(date, &startMinute, &endMinute);

    setTextItem(row, ColDay, dayText);
    setTextItem(row, ColStart, formatClock(startMinute), true);
    setTextItem(row, ColEnd, formatClock(endMinute), true);
    setHoursItem(row, ColActual, actual, false);
    setHoursItem(row, ColTarget, target, false);
    if (date > today) {
        setTextItem(row, ColSaldo, QString(), true);
        if (auto *item = m_dayTable->item(row, ColSaldo)) {
            item->setForeground(m_dayTable->palette().color(QPalette::Text));
        }
    } else {
        setHoursItem(row, ColSaldo, saldo, true);
    }
    setTextItem(row, ColHint, hint);
    applyRowColors(row, date, hint);
    if (auto *hintItem = m_dayTable->item(row, ColHint)) {
        if (arbzg.hasIssue()) {
            hintItem->setForeground(QColor(180, 0, 0));
            hintItem->setToolTip((arbzg.issues + arbzg.notes).join(QLatin1Char('\n')));
        } else if (!arbzg.notes.isEmpty()) {
            hintItem->setForeground(QColor(179, 92, 0));
            hintItem->setToolTip(arbzg.notes.join(QLatin1Char('\n')));
        } else {
            hintItem->setToolTip(QString());
        }
    }
}

void MonthView::updateSummary()
{
    const QLocale locale;
    const MonthTotals totals =
        TimeTotals::instance().monthTotals(m_month.year(), m_month.month());

    auto coloredHours = [](double hours) {
        QString html = formatHours(qAbs(hours));
        if (hours > 0.005) {
            return QStringLiteral("<span style=\"color:#008000;\">%1</span>").arg(html);
        }
        if (hours < -0.005) {
            return QStringLiteral("<span style=\"color:#b40000;\">%1</span>").arg(html);
        }
        return html;
    };

    m_summaryLabel->setTextFormat(Qt::RichText);
    QString text =
        QStringLiteral("Monat %1 – Soll: %2  |  Ist: %3  |  Vormonat: %4  |  Saldo: %5"
                       "  |  Konto: %6")
            .arg(locale.toString(m_month, QStringLiteral("MMMM yyyy")),
                 formatHours(totals.targetHours),
                 formatHours(totals.actualHours),
                 coloredHours(totals.carryIn),
                 coloredHours(totals.monthSaldo),
                 coloredHours(totals.closingSaldo));
    if (qAbs(totals.clippedHours) > 0.005) {
        text += QStringLiteral("  |  Abgeschnitten: <span style=\"color:#b35c00;\">%1</span>")
                    .arg(formatHours(qAbs(totals.clippedHours)));
    }
    text += QStringLiteral("  |  Urlaub genommen: %1  |  geplant: %2")
                .arg(locale.toString(totals.vacationTaken, 'f', 1),
                     locale.toString(totals.vacationPlanned, 'f', 1));
    m_summaryLabel->setText(text);
}

void MonthView::refresh()
{
    const int days = m_month.daysInMonth();
    const int selectedRow = m_dayTable->currentRow();
    m_dayTable->setRowCount(days);

    TimeTotals::instance().ensureYear(m_month.year());
    CalendarService::instance().ensureYearLoaded(m_month.year());

    for (int day = 1; day <= days; ++day) {
        fillDayRow(day);
    }
    updateSummary();

    if (selectedRow >= 0 && selectedRow < days) {
        m_dayTable->selectRow(selectedRow);
    }
}

void MonthView::applyRowColors(int row, const QDate &date, const QString & /*hint*/)
{
    const bool weekend = date.dayOfWeek() >= 6;
    const bool holiday = CalendarService::instance().isPublicHoliday(date);
    const bool school = CalendarService::instance().isSchoolHoliday(date);
    const bool companyFree = AppSettings::instance().isCompanyFreeEveDate(date);
    const Absence absence = TimeTotals::instance().effectiveAbsenceForDate(date);

    QColor background;
    if (holiday || companyFree) {
        background = publicHolidayColor();
    } else if (weekend && school) {
        background = weekendAndSchoolColor();
    } else if (weekend) {
        background = weekendColor();
    } else if (school) {
        background = schoolHolidayColor();
    } else if (absence.type == AbsenceType::Vacation) {
        background = vacationColor();
    } else if (absence.type == AbsenceType::Sick) {
        background = sickColor();
    }

    for (int col = 0; col < m_dayTable->columnCount(); ++col) {
        auto *item = m_dayTable->item(row, col);
        if (!item) {
            continue;
        }
        if (background.isValid()) {
            item->setBackground(background);
        } else {
            item->setBackground(QBrush());
        }
    }
}

QDate MonthView::dateFromRow(int row) const
{
    if (row < 0 || row >= m_month.daysInMonth()) {
        return {};
    }
    return QDate(m_month.year(), m_month.month(), row + 1);
}

void MonthView::popupDayMenu(const QPoint &viewportPos)
{
    const QModelIndex index = m_dayTable->indexAt(viewportPos);
    if (index.isValid()) {
        m_dayTable->selectRow(index.row());
        emit dayActivated(dateFromRow(index.row()));
    }

    const QDate date = dateFromRow(m_dayTable->currentRow());
    if (!date.isValid()) {
        return;
    }

    const Absence current = JournalStore::instance().absenceForDate(date);
    const bool countable = isCountableAbsenceDay(date);

    QMenu menu(this);
    auto *packagesAction = menu.addAction(QStringLiteral("Arbeitspakete…"));
    menu.addSeparator();
    auto *vacationMenu = menu.addMenu(QStringLiteral("Urlaub"));
    auto *vacationFull = vacationMenu->addAction(QStringLiteral("Ganzer Tag"));
    auto *vacationHalf = vacationMenu->addAction(QStringLiteral("Halber Tag"));
    vacationFull->setCheckable(true);
    vacationHalf->setCheckable(true);
    vacationFull->setEnabled(countable);
    vacationHalf->setEnabled(countable);
    if (current.type == AbsenceType::Vacation) {
        vacationFull->setChecked(!current.isHalfDay());
        vacationHalf->setChecked(current.isHalfDay());
    }

    auto *sickMenu = menu.addMenu(QStringLiteral("Krankheit"));
    auto *sickFull = sickMenu->addAction(QStringLiteral("Ganzer Tag"));
    auto *sickHalf = sickMenu->addAction(QStringLiteral("Halber Tag"));
    sickFull->setCheckable(true);
    sickHalf->setCheckable(true);
    sickFull->setEnabled(countable);
    sickHalf->setEnabled(countable);
    if (current.type == AbsenceType::Sick) {
        sickFull->setChecked(!current.isHalfDay());
        sickHalf->setChecked(current.isHalfDay());
    }

    menu.addSeparator();
    auto *boundsAction = menu.addAction(QStringLiteral("Tagesgrenzen…"));
    auto *rangeAction = menu.addAction(QStringLiteral("Zeitraum…"));
    auto *clearAction = menu.addAction(QStringLiteral("Status entfernen"));
    clearAction->setEnabled(current.isSet());

    QAction *chosen = menu.exec(m_dayTable->viewport()->mapToGlobal(viewportPos));
    if (!chosen) {
        return;
    }

    if (chosen == packagesAction) {
        openDayPackagesDialog(date);
    } else if (chosen == vacationFull) {
        applyAbsence({date}, Absence{AbsenceType::Vacation, 1.0});
    } else if (chosen == vacationHalf) {
        applyAbsence({date}, Absence{AbsenceType::Vacation, 0.5});
    } else if (chosen == sickFull) {
        applyAbsence({date}, Absence{AbsenceType::Sick, 1.0});
    } else if (chosen == sickHalf) {
        applyAbsence({date}, Absence{AbsenceType::Sick, 0.5});
    } else if (chosen == rangeAction) {
        openRangeDialog(date);
    } else if (chosen == boundsAction) {
        DayBoundsDialog dialog(date, this);
        dialog.exec();
    } else if (chosen == clearAction) {
        applyAbsence({date}, {});
    }
}

void MonthView::openRangeDialog(const QDate &from)
{
    AbsenceDialog dialog(from, from, this);
    if (dialog.exec() != QDialog::Accepted) {
        return;
    }

    const QDate start = dialog.fromDate();
    const QDate end = dialog.toDate();
    if (dialog.isClear()) {
        applyAbsence(datesInRange(start, end, false), {});
        return;
    }
    applyAbsence(datesInRange(start, end, true), dialog.absence());
}

void MonthView::openAbsenceDialog()
{
    QDate from = dateFromRow(m_dayTable->currentRow());
    if (!from.isValid()) {
        const QDate today = QDate::currentDate();
        if (today.year() == m_month.year() && today.month() == m_month.month()) {
            from = today;
        } else {
            from = m_month;
        }
    }
    openRangeDialog(from);
}

void MonthView::applyAbsence(const QVector<QDate> &dates, const Absence &absence)
{
    if (dates.isEmpty()) {
        QMessageBox::information(
            this,
            QStringLiteral("Urlaub / Krankheit"),
            QStringLiteral("Im gewählten Zeitraum liegt kein Arbeitstag ohne Feiertag."));
        return;
    }

    QString error;
    if (!JournalStore::instance().setAbsences(dates, absence, &error)) {
        QMessageBox::warning(
            this,
            QStringLiteral("Urlaub / Krankheit"),
            error.isEmpty() ? QStringLiteral("Der Status konnte nicht gespeichert werden.")
                            : error);
    }
}
