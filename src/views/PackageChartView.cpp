#include "PackageChartView.h"

#include "core/AppSettings.h"
#include "core/JournalStore.h"
#include "core/TitleCatalog.h"

#include <QDate>
#include <QLocale>
#include <QPainter>
#include <QPaintEvent>

PackageChartView::PackageChartView(QWidget *parent)
    : QWidget(parent)
    , m_year(QDate::currentDate().year())
    , m_month(QDate::currentDate().month())
{
    connect(&JournalStore::instance(), &JournalStore::changed, this, &PackageChartView::refresh);
    connect(&AppSettings::instance(), &AppSettings::changed, this, &PackageChartView::refresh);
    connect(&TitleCatalog::instance(), &TitleCatalog::changed, this, &PackageChartView::refresh);
}

void PackageChartView::setMonth(int year, int month)
{
    if (month < 1 || month > 12) {
        return;
    }
    if (m_year == year && m_month == month) {
        return;
    }
    m_year = year;
    m_month = month;
    update();
}

void PackageChartView::refresh()
{
    update();
}

void PackageChartView::paintEvent(QPaintEvent *event)
{
    QWidget::paintEvent(event);

    QPainter painter(this);
    painter.setRenderHint(QPainter::Antialiasing, true);

    const QRect inner = rect().adjusted(4, 4, -4, -4);
    const QLocale locale;

    const auto rows = JournalStore::instance().titleHoursForMonth(m_year, m_month);
    if (rows.isEmpty()) {
        painter.setPen(palette().placeholderText().color());
        painter.drawText(inner,
                         Qt::AlignCenter,
                         QStringLiteral("Noch keine Arbeitspakete in diesem Monat.\n"
                                        "In der Tagesübersicht per Ziehen oder Doppelklick anlegen."));
        return;
    }

    double maxHours = 0.0;
    for (const auto &row : rows) {
        maxHours = qMax(maxHours, row.second);
    }
    if (maxHours <= 0.0) {
        maxHours = 1.0;
    }

    auto &catalog = TitleCatalog::instance();
    const int top = inner.top();
    const int rowHeight = qMax(22, qMin(32, inner.height() / qMax(1, rows.size())));
    const int labelWidth = 130;
    const int hoursWidth = 56;
    const int barLeft = inner.left() + labelWidth;
    const int barMaxWidth = qMax(20, inner.width() - labelWidth - hoursWidth - 8);

    for (int i = 0; i < rows.size(); ++i) {
        const int y = top + i * rowHeight;
        if (y + 16 > inner.bottom()) {
            break;
        }

        const QColor color = catalog.colorFor(rows[i].first);
        painter.setPen(palette().windowText().color());
        painter.drawText(QRect(inner.left(), y, labelWidth - 8, rowHeight - 4),
                         Qt::AlignVCenter | Qt::AlignLeft,
                         painter.fontMetrics().elidedText(rows[i].first, Qt::ElideRight,
                                                          labelWidth - 8));

        const int barWidth = qMax(2, qRound(barMaxWidth * (rows[i].second / maxHours)));
        const QRect bar(barLeft, y + 4, barWidth, rowHeight - 10);
        painter.setPen(Qt::NoPen);
        painter.setBrush(color);
        painter.drawRoundedRect(bar, 3, 3);

        painter.setPen(palette().windowText().color());
        painter.drawText(QRect(barLeft + barMaxWidth + 8, y, hoursWidth, rowHeight - 4),
                         Qt::AlignVCenter | Qt::AlignRight,
                         locale.toString(rows[i].second, 'f', 2));
    }
}
