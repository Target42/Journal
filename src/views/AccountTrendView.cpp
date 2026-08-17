#include "AccountTrendView.h"

#include "core/AppSettings.h"
#include "core/CalendarService.h"
#include "core/JournalStore.h"

#include <QColor>
#include <QLocale>
#include <QPainter>
#include <QPaintEvent>
#include <QPen>
#include <QPolygonF>
#include <QSizePolicy>

namespace {
QColor positiveColor()
{
    return QColor(0, 128, 0);
}

QColor negativeColor()
{
    return QColor(180, 0, 0);
}

QColor hoursColor(double hours)
{
    if (hours > 0.005) {
        return positiveColor();
    }
    if (hours < -0.005) {
        return negativeColor();
    }
    return {};
}

QString formatHours(double hours)
{
    return QLocale().toString(qAbs(hours), 'f', 2);
}
} // namespace

AccountTrendView::AccountTrendView(QWidget *parent)
    : QWidget(parent)
{
    setMinimumHeight(140);
    setSizePolicy(QSizePolicy::Expanding, QSizePolicy::Expanding);
    setToolTip(QStringLiteral(
        "Mittelwert der Mehr-/Minderstunden der letzten 30 Tage mit erfasster Arbeitszeit "
        "(ohne volle Urlaubs- oder Krankheitstage). Die Hochrechnung nimmt an, dass an allen "
        "konfigurierten Arbeitstagen so weitergearbeitet wird. Periodenkappung ist nicht "
        "eingerechnet."));

    connect(&JournalStore::instance(), &JournalStore::changed, this, &AccountTrendView::refresh);
    connect(&AppSettings::instance(), &AppSettings::changed, this, &AccountTrendView::refresh);
    connect(&CalendarService::instance(), &CalendarService::yearDataChanged,
            this, &AccountTrendView::refresh);

    refresh();
}

QString AccountTrendView::caption() const
{
    const int n = m_trend.points.size();
    if (n <= 0) {
        return QStringLiteral("Trendübersicht");
    }
    const QLocale locale;
    return QStringLiteral("Trendübersicht – letzte %1 Arbeitstage (%2–%3)")
        .arg(n)
        .arg(locale.toString(m_trend.from, QStringLiteral("dd.MM.")),
             locale.toString(m_trend.to, QStringLiteral("dd.MM.yyyy")));
}

void AccountTrendView::refresh()
{
    m_trend = TimeTotals::instance().accountTrend(30);
    update();
}

void AccountTrendView::paintEvent(QPaintEvent *event)
{
    QWidget::paintEvent(event);

    QPainter painter(this);
    painter.setRenderHint(QPainter::Antialiasing, true);

    const QRect inner = rect().adjusted(4, 4, -4, -4);
    const int n = m_trend.points.size();

    if (n <= 0) {
        painter.setPen(palette().placeholderText().color());
        painter.drawText(inner,
                         Qt::AlignCenter,
                         QStringLiteral("Noch keine Arbeitstage für einen Trend.\n"
                                        "Es zählen Tage mit erfasster Arbeitszeit."));
        return;
    }

    const QFontMetrics fm(painter.font());
    const int footerHeight = fm.height() * 2 + 8;
    const QRect chartRect = inner.adjusted(4, 4, -4, -footerHeight);
    const QRect footerRect(inner.left(), chartRect.bottom() + 4, inner.width(), footerHeight);

    QVector<double> cumulative;
    cumulative.reserve(n);
    double running = 0.0;
    double yMin = 0.0;
    double yMax = 0.0;
    for (const auto &point : m_trend.points) {
        running += point.saldo;
        cumulative.append(running);
        yMin = qMin(yMin, running);
        yMax = qMax(yMax, running);
    }

    if (qAbs(yMax - yMin) < 0.05) {
        yMax += 0.5;
        yMin -= 0.5;
    } else {
        const double pad = (yMax - yMin) * 0.12;
        yMax += pad;
        yMin -= pad;
    }

    const auto yToPx = [&](double hours) {
        const double t = (hours - yMin) / (yMax - yMin);
        return chartRect.bottom() - t * chartRect.height();
    };

    const QColor zeroPen = palette().mid().color();
    painter.setPen(QPen(zeroPen, 1, Qt::DashLine));
    const qreal zeroY = yToPx(0.0);
    painter.drawLine(QPointF(chartRect.left(), zeroY), QPointF(chartRect.right(), zeroY));

    QPolygonF line;
    line.reserve(n);
    for (int i = 0; i < n; ++i) {
        const double x = n == 1
                             ? chartRect.center().x()
                             : chartRect.left() + (chartRect.width() * i / double(n - 1));
        line.append(QPointF(x, yToPx(cumulative[i])));
    }

    QPolygonF fill = line;
    fill.prepend(QPointF(line.first().x(), zeroY));
    fill.append(QPointF(line.last().x(), zeroY));
    QColor fillColor = hoursColor(m_trend.totalSaldo);
    if (!fillColor.isValid()) {
        fillColor = zeroPen;
    }
    fillColor.setAlpha(40);
    painter.setPen(Qt::NoPen);
    painter.setBrush(fillColor);
    painter.drawPolygon(fill);

    QColor lineColor = hoursColor(m_trend.totalSaldo);
    if (!lineColor.isValid()) {
        lineColor = palette().windowText().color();
    }
    painter.setBrush(Qt::NoBrush);
    painter.setPen(QPen(lineColor, 2));
    painter.drawPolyline(line);

    painter.setBrush(lineColor);
    painter.setPen(Qt::NoPen);
    for (const QPointF &pt : line) {
        painter.drawEllipse(pt, 2.2, 2.2);
    }

    painter.setPen(palette().windowText().color());
    const QString avgLabel = QStringLiteral("Ø je Arbeitstag: ");
    const QString weekLabel = QStringLiteral("ca. je Woche: ");
    const QString monthLabel = QStringLiteral("ca. je Monat: ");
    const QString avgValue = formatHours(m_trend.averagePerWorkedDay);
    const QString weekValue = formatHours(m_trend.projectedPerWeek);
    const QString monthValue = formatHours(m_trend.projectedPerMonth);

    const QRect line1(footerRect.left(), footerRect.top(), footerRect.width(), fm.height() + 2);
    const QRect line2(footerRect.left(), line1.bottom(), footerRect.width(), fm.height() + 2);

    painter.drawText(line1, Qt::AlignLeft | Qt::AlignVCenter, avgLabel);
    QColor avgColor = hoursColor(m_trend.averagePerWorkedDay);
    painter.setPen(avgColor.isValid() ? avgColor : palette().windowText().color());
    painter.drawText(line1.adjusted(fm.horizontalAdvance(avgLabel), 0, 0, 0),
                     Qt::AlignLeft | Qt::AlignVCenter, avgValue);

    painter.setPen(palette().windowText().color());
    const QString weekPrefix = weekLabel;
    painter.drawText(line2, Qt::AlignLeft | Qt::AlignVCenter, weekPrefix);
    QColor weekColor = hoursColor(m_trend.projectedPerWeek);
    painter.setPen(weekColor.isValid() ? weekColor : palette().windowText().color());
    const int weekValueX = fm.horizontalAdvance(weekPrefix);
    painter.drawText(line2.adjusted(weekValueX, 0, 0, 0),
                     Qt::AlignLeft | Qt::AlignVCenter, weekValue);

    const QString monthPrefix = QStringLiteral("   ·   ") + monthLabel;
    const int monthStart = weekValueX + fm.horizontalAdvance(weekValue);
    painter.setPen(palette().windowText().color());
    painter.drawText(line2.adjusted(monthStart, 0, 0, 0),
                     Qt::AlignLeft | Qt::AlignVCenter, monthPrefix);
    QColor monthColor = hoursColor(m_trend.projectedPerMonth);
    painter.setPen(monthColor.isValid() ? monthColor : palette().windowText().color());
    painter.drawText(line2.adjusted(monthStart + fm.horizontalAdvance(monthPrefix), 0, 0, 0),
                     Qt::AlignLeft | Qt::AlignVCenter, monthValue);
}
