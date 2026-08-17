#include "DayView.h"

#include "core/Absence.h"
#include "core/AppSettings.h"
#include "core/ArbzgRules.h"
#include "core/JournalStore.h"
#include "core/TimeTotals.h"
#include "core/TitleCatalog.h"
#include "core/WorkPackage.h"
#include "dialogs/DayBoundsDialog.h"
#include "dialogs/PauseDialog.h"
#include "dialogs/WorkPackageDialog.h"

#include <QAbstractButton>
#include <QAction>
#include <QBrush>
#include <QCheckBox>
#include <QContextMenuEvent>
#include <QDate>
#include <QFontMetrics>
#include <QHash>
#include <QHBoxLayout>
#include <QLabel>
#include <QLocale>
#include <QMenu>
#include <QMessageBox>
#include <QMouseEvent>
#include <QPainter>
#include <QPaintEvent>
#include <QSignalBlocker>
#include <QToolButton>
#include <QUuid>
#include <QVector>
#include <QVBoxLayout>
#include <algorithm>

namespace {
constexpr int kHeaderBottom = 22;
constexpr int kHourTickLength = 12;
constexpr int kHalfHourTickLength = 8;
constexpr int kQuarterTickLength = 5;
constexpr int kAxisLabelGap = 1;
constexpr int kBottomPadding = 2;

QColor textColorFor(const QColor &background)
{
    const double luminance =
        (0.299 * background.red() + 0.587 * background.green() + 0.114 * background.blue()) / 255.0;
    return luminance > 0.62 ? QColor(30, 30, 30) : QColor(255, 255, 255);
}

int tickLengthBelowBox(int minute)
{
    const int ofHour = minute % 60;
    if (ofHour == 0) {
        return kHourTickLength;
    }
    if (ofHour == 30) {
        return kHalfHourTickLength;
    }
    return kQuarterTickLength;
}

QString labelForPause(const PauseInterval &pause)
{
    for (const auto &preset : AppSettings::instance().pausePresets()) {
        if (pause.startMinute <= preset.startMinute && pause.endMinute >= preset.endMinute) {
            return preset.label();
        }
    }
    return QStringLiteral("Pause");
}
} // namespace

DayView::DayView(QWidget *parent)
    : QWidget(parent)
    , m_date(QDate::currentDate())
{
    setupUi();
    setSizePolicy(QSizePolicy::Expanding, QSizePolicy::Fixed);
    setMouseTracking(false);

    connect(&JournalStore::instance(), &JournalStore::changed, this, [this]() {
        refreshHeader();
        update();
    });
    connect(&AppSettings::instance(), &AppSettings::changed, this, [this]() {
        refreshHeader();
        update();
    });
    connect(&TimeTotals::instance(), &TimeTotals::dayRecalculated, this,
            [this](const QDate &date) {
                if (!date.isValid() || date == m_date) {
                    refreshHeader();
                    update();
                }
            });
    connect(&TitleCatalog::instance(), &TitleCatalog::changed, this, [this]() { update(); });
}

void DayView::setupUi()
{
    auto *layout = new QVBoxLayout(this);
    layout->setContentsMargins(0, 0, 0, 0);
    layout->setSpacing(2);

    auto *headerRow = new QHBoxLayout();
    headerRow->setContentsMargins(0, 0, 0, 0);
    headerRow->setSpacing(6);

    m_headerLabel = new QLabel(this);
    m_headerLabel->setFixedHeight(18);

    m_boundsButton = new QToolButton(this);
    m_boundsButton->setAutoRaise(true);
    m_boundsButton->setToolButtonStyle(Qt::ToolButtonTextOnly);
    m_boundsButton->setFixedHeight(18);
    m_boundsButton->setToolTip(
        QStringLiteral("Tagesgrenzen für Ist und Saldo. Klicken zum Ändern."));
    connect(m_boundsButton, &QToolButton::clicked, this, &DayView::openBoundsDialog);

    m_addButton = new QToolButton(this);
    m_addButton->setText(QStringLiteral("+"));
    m_addButton->setToolTip(QStringLiteral("Arbeitspaket hinzufügen"));
    m_addButton->setAutoRaise(true);
    m_addButton->setFixedSize(22, 18);
    connect(m_addButton, &QToolButton::clicked, this, [this]() {
        if (m_date == QDate::currentDate()) {
            const int now = timeToMinute(QTime::currentTime());
            addPackageAt(now, now + 30, true);
        } else {
            addPackageAt(8 * 60, 8 * 60 + 30, false);
        }
    });

    m_pauseButton = new QToolButton(this);
    m_pauseButton->setText(QStringLiteral("Pause"));
    m_pauseButton->setToolTip(QStringLiteral("Pause einfügen oder bearbeiten"));
    m_pauseButton->setAutoRaise(true);
    m_pauseButton->setToolButtonStyle(Qt::ToolButtonTextOnly);
    m_pauseButton->setFixedHeight(18);
    connect(m_pauseButton, &QToolButton::clicked, this, [this]() {
        const auto pauses = JournalStore::instance().pausesForDate(m_date);
        const auto presets = AppSettings::instance().pausePresets();
        if (!pauses.isEmpty()) {
            const int anchor = presets.isEmpty() ? kUsualPauseStartDefault
                                                 : presets.first().startMinute;
            PauseInterval best = pauses.first();
            int bestDist = qAbs(best.startMinute - anchor);
            for (const auto &pause : pauses) {
                int dist = qAbs(pause.startMinute - anchor);
                for (const auto &preset : presets) {
                    dist = qMin(dist, qAbs(pause.startMinute - preset.startMinute));
                }
                if (dist < bestDist) {
                    best = pause;
                    bestDist = dist;
                }
            }
            PauseDialog::runRange(m_date, best.startMinute, best.endMinute, true, this);
            return;
        }
        if (!presets.isEmpty()) {
            openPauseAt((presets.first().startMinute + presets.first().endMinute) / 2);
            return;
        }
        openPauseAt((kUsualPauseStartDefault + kUsualPauseEndDefault) / 2);
    });

    for (int i = 0; i < kPausePresetCount; ++i) {
        m_pauseChecks[i] = new QCheckBox(this);
        m_pauseChecks[i]->setFixedHeight(18);
        m_pauseChecks[i]->hide();
        connect(m_pauseChecks[i], &QCheckBox::toggled, this, &DayView::onPausePresetToggled);
    }

    headerRow->addWidget(m_headerLabel, 1);
    headerRow->addWidget(m_boundsButton);
    for (auto *check : m_pauseChecks) {
        headerRow->addWidget(check);
    }
    headerRow->addWidget(m_pauseButton);
    headerRow->addWidget(m_addButton);
    layout->addLayout(headerRow);
    layout->addStretch();

    refreshHeader();
}

void DayView::setDate(const QDate &date)
{
    if (!date.isValid() || date == m_date) {
        return;
    }
    m_date = date;
    refreshHeader();
    update();
    emit dateChanged(m_date);
}

void DayView::refreshHeader()
{
    const DayBounds dayBounds = bounds();
    QString text = QLocale().toString(m_date, QStringLiteral("ddd, d. MMM yyyy"));
    if (m_date == QDate::currentDate()) {
        text += QStringLiteral("  ·  heute");
    }
    const Absence absence = JournalStore::instance().absenceForDate(m_date);
    if (absence.isSet()) {
        text += QStringLiteral("  ·  %1").arg(absence.label());
    }

    const double actual = TimeTotals::instance().creditedHoursForDate(m_date);
    text += QStringLiteral("  ·  Ist %1").arg(QLocale().toString(actual, 'f', 2));
    const BreakAdjustment breaks = JournalStore::instance().breakAdjustmentForDate(m_date);
    if (breaks.autoPauseMinutes > 0) {
        text += QStringLiteral("  ·  Pause %1")
                    .arg(QLocale().toString(breaks.autoPauseMinutes / 60.0, 'f', 2));
    }

    const ArbzgDay arbzg = ArbzgCompliance::assessDay(m_date);
    if (arbzg.hasWork) {
        text += QStringLiteral("  ·  ArbZG %1")
                    .arg(ArbzgCompliance::formatDuration(arbzg.rawWorkMinutes));
    }
    if (arbzg.hasIssue()) {
        text += QStringLiteral("  ·  %1").arg(arbzg.issues.first());
        m_headerLabel->setStyleSheet(QStringLiteral("color: #b40000;"));
    } else if (!arbzg.notes.isEmpty()) {
        text += QStringLiteral("  ·  %1").arg(arbzg.notes.first());
        m_headerLabel->setStyleSheet(QStringLiteral("color: #b35c00;"));
    } else {
        m_headerLabel->setStyleSheet(QString());
    }
    const QStringList allHints = arbzg.issues + arbzg.notes;
    m_headerLabel->setToolTip(allHints.join(QLatin1Char('\n')));

    bool outside = false;
    for (const auto &pkg : JournalStore::instance().packagesForDate(m_date)) {
        if (pkg.startMinute() < dayBounds.startMinute
            || pkg.endMinute(m_date) > dayBounds.endMinute) {
            outside = true;
            break;
        }
    }
    if (outside) {
        text += QStringLiteral("  ·  erfasst außerhalb");
    }
    m_headerLabel->setText(text);

    QString boundsText = dayBounds.label();
    if (dayBounds.custom) {
        boundsText += QStringLiteral(" *");
        m_boundsButton->setToolTip(
            QStringLiteral("Abweichende Tagesgrenzen für diesen Tag. Klicken zum Ändern."));
    } else {
        m_boundsButton->setToolTip(
            QStringLiteral("Tagesgrenzen für Ist und Saldo. Klicken zum Ändern."));
    }
    m_boundsButton->setText(boundsText);
    refreshPausePresetChecks();
}

void DayView::refreshPausePresetChecks()
{
    const auto presets = AppSettings::instance().pausePresets();
    auto &store = JournalStore::instance();
    for (int i = 0; i < kPausePresetCount; ++i) {
        QCheckBox *box = m_pauseChecks[i];
        if (i >= presets.size()) {
            QSignalBlocker blocker(box);
            box->setChecked(false);
            box->hide();
            continue;
        }

        const PausePreset &preset = presets[i];
        box->show();
        box->setText(preset.label());
        box->setToolTip(QStringLiteral("%1 %2 einfügen oder entfernen")
                            .arg(preset.label(), preset.timeLabel()));
        box->setProperty("startMinute", preset.startMinute);
        box->setProperty("endMinute", preset.endMinute);
        QSignalBlocker blocker(box);
        box->setChecked(store.pauseCoveringRange(m_date, preset.startMinute, preset.endMinute)
                            .isValid());
    }
}

void DayView::onPausePresetToggled(bool checked)
{
    auto *box = qobject_cast<QCheckBox *>(sender());
    if (!box) {
        return;
    }

    const int startMinute = box->property("startMinute").toInt();
    const int endMinute = box->property("endMinute").toInt();
    auto &store = JournalStore::instance();
    QString error;

    if (checked) {
        if (!store.applyPause(m_date, startMinute, endMinute, &error)) {
            QMessageBox::warning(this, QStringLiteral("Pause"), error);
            QSignalBlocker blocker(box);
            box->setChecked(false);
        }
        return;
    }

    const PauseInterval covering = store.pauseCoveringRange(m_date, startMinute, endMinute);
    if (!covering.isValid()) {
        return;
    }
    if (!store.closePause(m_date, covering.startMinute, covering.endMinute, &error)) {
        QMessageBox::warning(this, QStringLiteral("Pause"), error);
        QSignalBlocker blocker(box);
        box->setChecked(true);
    }
}

DayBounds DayView::bounds() const
{
    return JournalStore::instance().boundsForDate(m_date);
}

int DayView::windowStart() const
{
    return bounds().startMinute;
}

int DayView::windowEnd() const
{
    return bounds().endMinute;
}

QRect DayView::chartRect() const
{
    const QFontMetrics fm(font());
    const int colonHalf = qMax(1, fm.horizontalAdvance(QLatin1Char(':'))) / 2;
    const int side = fm.horizontalAdvance(QStringLiteral("00")) + colonHalf + 6;
    const int bottomReserve = kHourTickLength + kAxisLabelGap + fm.height() + kBottomPadding;
    return QRect(side, kHeaderBottom, qMax(0, width() - 2 * side),
                 qMax(0, height() - kHeaderBottom - bottomReserve));
}

QRect DayView::barsRect() const
{
    return chartRect().adjusted(1, 2, -1, -2);
}

int DayView::minuteAtX(int x) const
{
    const QRect chart = chartRect();
    const int start = windowStart();
    if (chart.width() <= 1) {
        return start;
    }
    const qreal t = qBound(0.0, (x - chart.left()) / static_cast<qreal>(chart.width() - 1), 1.0);
    const int span = windowEnd() - start;
    return start + qRound(t * qMax(1, span));
}

int DayView::xAtMinute(int minute) const
{
    const QRect chart = chartRect();
    const int start = windowStart();
    const int span = qMax(1, windowEnd() - start);
    const qreal t = (minute - start) / static_cast<qreal>(span);
    return chart.left() + qRound(qBound(0.0, t, 1.0) * (chart.width() - 1));
}

QVector<DayView::PackageLayout> DayView::layoutPackages() const
{
    const int startBound = windowStart();
    const int endBound = windowEnd();
    auto packages = JournalStore::instance().packagesForDate(m_date);
    packages.erase(std::remove_if(packages.begin(), packages.end(),
                                  [this, startBound, endBound](const WorkPackage &pkg) {
                                      return pkg.endMinute(m_date) <= startBound
                                          || pkg.startMinute() >= endBound;
                                  }),
                   packages.end());
    std::sort(packages.begin(), packages.end(), [](const WorkPackage &a, const WorkPackage &b) {
        return a.startMinute() < b.startMinute();
    });

    QVector<int> laneEnds;
    QVector<int> lanes;
    lanes.reserve(packages.size());
    for (const auto &pkg : packages) {
        int lane = -1;
        for (int i = 0; i < laneEnds.size(); ++i) {
            if (laneEnds[i] <= pkg.startMinute()) {
                lane = i;
                break;
            }
        }
        if (lane < 0) {
            lane = laneEnds.size();
            laneEnds.append(0);
        }
        laneEnds[lane] = pkg.endMinute(m_date);
        lanes.append(lane);
    }

    const QRect bars = barsRect();
    const int laneCount = qMax(1, laneEnds.size());
    const int laneHeight = bars.height() / laneCount;

    QVector<PackageLayout> layouts;
    layouts.reserve(packages.size());
    for (int i = 0; i < packages.size(); ++i) {
        const auto &pkg = packages[i];
        int x1 = xAtMinute(qBound(startBound, pkg.startMinute(), endBound));
        int x2 = xAtMinute(qBound(startBound, pkg.endMinute(m_date), endBound));
        if (x2 <= x1) {
            x2 = x1 + 2;
        }
        PackageLayout item;
        item.id = pkg.id;
        item.startMinute = pkg.startMinute();
        const int top = bars.top() + lanes[i] * laneHeight + 1;
        const int available = qMax(1, bars.bottom() - top);
        const int height = qMin(available, qMax(1, laneHeight - 2));
        item.rect = QRect(x1, top, x2 - x1, height);
        layouts.append(item);
    }
    return layouts;
}

QString DayView::packageIdAt(const QPoint &pos) const
{
    const auto layouts = layoutPackages();
    for (int i = layouts.size() - 1; i >= 0; --i) {
        if (layouts[i].rect.contains(pos)) {
            return layouts[i].id;
        }
    }
    return {};
}

QRect DayView::pauseRect(const PauseInterval &pause) const
{
    const QRect bars = barsRect();
    const int startBound = windowStart();
    const int endBound = windowEnd();
    const int x1 = xAtMinute(qBound(startBound, pause.startMinute, endBound));
    const int x2 = xAtMinute(qBound(startBound, pause.endMinute, endBound));
    return QRect(x1, bars.top(), qMax(2, x2 - x1), bars.height());
}

PauseInterval DayView::pauseAt(const QPoint &pos) const
{
    for (const auto &pause : JournalStore::instance().pausesForDate(m_date)) {
        if (pauseRect(pause).contains(pos)) {
            return pause;
        }
    }
    return {};
}

void DayView::openPauseAt(int minute)
{
    PauseDialog::runAt(m_date, minute, this);
}

void DayView::addPackageAt(int startMinute, int endMinute, bool active)
{
    startMinute = qBound(0, startMinute, 23 * 60 + 58);
    endMinute = qBound(startMinute + 1, endMinute, 23 * 60 + 59);

    auto &store = JournalStore::instance();
    while (store.startMinuteTaken(m_date, startMinute) && startMinute < 23 * 60 + 58) {
        ++startMinute;
        if (endMinute <= startMinute) {
            endMinute = startMinute + 1;
        }
    }

    WorkPackage pkg;
    pkg.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    pkg.start = minuteToTime(startMinute);
    pkg.end = minuteToTime(endMinute);
    pkg.active = active && m_date == QDate::currentDate();
    openEditor(pkg);
}

void DayView::editPackage(const QString &id)
{
    const WorkPackage pkg = JournalStore::instance().packageById(m_date, id);
    if (pkg.id.isEmpty()) {
        return;
    }
    openEditor(pkg);
}

void DayView::deletePackage(const QString &id)
{
    const WorkPackage pkg = JournalStore::instance().packageById(m_date, id);
    if (pkg.id.isEmpty()) {
        return;
    }
    QMessageBox box(this);
    box.setIcon(QMessageBox::Question);
    box.setWindowTitle(QStringLiteral("Arbeitspaket löschen"));
    box.setText(QStringLiteral("Arbeitspaket „%1“ wirklich löschen?").arg(pkg.title));
    box.setStandardButtons(QMessageBox::Yes | QMessageBox::No);
    box.setDefaultButton(QMessageBox::No);
    box.button(QMessageBox::Yes)->setText(QStringLiteral("Ja"));
    box.button(QMessageBox::No)->setText(QStringLiteral("Nein"));
    if (box.exec() != QMessageBox::Yes) {
        return;
    }
    JournalStore::instance().removePackage(m_date, id);
}

void DayView::openEditor(const WorkPackage &package)
{
    WorkPackageDialog dialog(m_date, package, this);
    if (dialog.exec() != QDialog::Accepted) {
        return;
    }
    if (dialog.wasDeleted()) {
        JournalStore::instance().removePackage(m_date, package.id);
        return;
    }
    QString error;
    if (!JournalStore::instance().savePackage(m_date, dialog.package(), &error)) {
        QMessageBox::warning(this, QStringLiteral("Arbeitspaket"), error);
    }
}

void DayView::openBoundsDialog()
{
    DayBoundsDialog dialog(m_date, this);
    dialog.exec();
}

void DayView::paintEvent(QPaintEvent *event)
{
    QWidget::paintEvent(event);

    QPainter painter(this);
    painter.setRenderHint(QPainter::Antialiasing, false);

    const QRect chart = chartRect();
    if (chart.width() <= 0 || chart.height() <= 0) {
        return;
    }

    painter.fillRect(chart, palette().base());
    painter.setPen(QPen(palette().mid().color(), 1));
    painter.drawRect(chart);

    const QColor hourColor = palette().mid().color();
    QColor halfHourColor = hourColor.lighter(125);
    QColor quarterColor = hourColor.lighter(150);

    const int startBound = windowStart();
    const int endBound = windowEnd();

    auto drawTickAt = [&](int minute) {
        const int x = xAtMinute(minute);
        const int ofHour = minute % 60;
        const int extra = tickLengthBelowBox(minute);
        if (ofHour == 0) {
            painter.setPen(QPen(hourColor, 1));
        } else if (ofHour == 30) {
            painter.setPen(QPen(halfHourColor, 1));
        } else {
            painter.setPen(QPen(quarterColor, 1));
        }

        const bool atBoxEdge = minute == startBound || minute == endBound;
        const int yTop = atBoxEdge ? chart.bottom() : chart.top();
        painter.drawLine(QPoint(x, yTop), QPoint(x, chart.bottom() + extra));
    };

    drawTickAt(startBound);
    int tick = ((startBound / 15) + (startBound % 15 == 0 ? 0 : 1)) * 15;
    if (tick == startBound) {
        tick += 15;
    }
    for (; tick < endBound; tick += 15) {
        drawTickAt(tick);
    }
    if (endBound != startBound) {
        drawTickAt(endBound);
    }

    const QFontMetrics fm(painter.font());
    const int colonWidth = fm.horizontalAdvance(QLatin1Char(':'));
    painter.setPen(palette().windowText().color());
    for (int minute = 0; minute <= 24 * 60; minute += 60) {
        if (minute < startBound || minute > endBound) {
            continue;
        }
        const int x = xAtMinute(minute);
        const QString text =
            QStringLiteral("%1:00").arg(minute / 60, 2, 10, QLatin1Char('0'));
        const int leftWidth = fm.horizontalAdvance(text.section(QLatin1Char(':'), 0, 0));
        const int textX = x - leftWidth - colonWidth / 2;
        const int textY = chart.bottom() + kHourTickLength + kAxisLabelGap;
        painter.drawText(QRect(textX, textY, fm.horizontalAdvance(text), fm.height()),
                         Qt::AlignLeft | Qt::AlignTop, text);
    }

    const auto packages = JournalStore::instance().packagesForDate(m_date);
    if (!packages.isEmpty()) {
        int workStart = packages.first().startMinute();
        for (const auto &pkg : packages) {
            workStart = qMin(workStart, pkg.startMinute());
        }

        auto drawLimit = [&](int hours, const QColor &color) {
            const int mark = workStart + hours * 60;
            if (mark < startBound || mark > endBound) {
                return;
            }
            const int x = xAtMinute(mark);
            painter.setPen(QPen(color, 1.5, Qt::DashLine));
            painter.drawLine(QPoint(x, chart.top()), QPoint(x, chart.bottom()));
        };

        drawLimit(6, QColor(180, 120, 0));
        drawLimit(8, QColor(180, 90, 0));
        drawLimit(10, QColor(180, 60, 0));
        drawLimit(12, QColor(160, 0, 0));
    }

    if (m_date == QDate::currentDate()) {
        const int now = timeToMinute(QTime::currentTime());
        if (now >= startBound && now <= endBound) {
            const int x = xAtMinute(now);
            painter.setPen(QPen(QColor(30, 90, 180), 1.5));
            painter.drawLine(QPoint(x, chart.top()), QPoint(x, chart.bottom()));
        }
    }

    painter.save();
    painter.setClipRect(chart);

    const auto pausePresets = AppSettings::instance().pausePresets();
    QVector<QRect> pauseWindowBands;
    for (const auto &preset : pausePresets) {
        if (preset.endMinute <= startBound || preset.startMinute >= endBound) {
            continue;
        }
        const int x1 = xAtMinute(qMax(preset.startMinute, startBound));
        const int x2 = xAtMinute(qMin(preset.endMinute, endBound));
        const QRect band(x1, chart.top() + 1, qMax(1, x2 - x1), qMax(1, chart.height() - 2));
        painter.fillRect(band, QColor(255, 243, 180));
        pauseWindowBands.append(band);
    }

    painter.setRenderHint(QPainter::Antialiasing, true);
    auto &catalog = TitleCatalog::instance();
    const auto layouts = layoutPackages();
    const QColor pauseFill(210, 210, 200);
    const QColor pauseEdge(120, 120, 110);
    for (const auto &pause : JournalStore::instance().pausesForDate(m_date)) {
        const QRect rect = pauseRect(pause).intersected(chart);
        if (rect.width() < 2) {
            continue;
        }
        painter.setPen(QPen(pauseEdge, 1));
        painter.setBrush(pauseFill);
        painter.drawRoundedRect(rect, 3, 3);
        if (rect.width() > 28) {
            painter.setPen(QColor(50, 50, 45));
            painter.drawText(rect.adjusted(4, 0, -4, 0), Qt::AlignVCenter | Qt::AlignLeft,
                             painter.fontMetrics().elidedText(labelForPause(pause),
                                                              Qt::ElideRight, rect.width() - 8));
        }
    }
    QHash<QString, WorkPackage> byId;
    for (const auto &pkg : packages) {
        byId.insert(pkg.id, pkg);
    }

    for (const auto &item : layouts) {
        const WorkPackage pkg = byId.value(item.id);
        const QColor color = catalog.colorFor(pkg.title);
        painter.setPen(QPen(color.darker(130), 1));
        painter.setBrush(color);
        painter.drawRoundedRect(item.rect, 3, 3);

        QString label = pkg.title;
        if (pkg.active) {
            label = QStringLiteral("▶ %1").arg(pkg.title);
        }
        if (item.rect.width() > 24) {
            painter.setPen(textColorFor(color));
            painter.drawText(item.rect.adjusted(4, 0, -4, 0),
                             Qt::AlignVCenter | Qt::AlignLeft,
                             painter.fontMetrics().elidedText(label, Qt::ElideRight,
                                                              item.rect.width() - 8));
        }
    }

    auto overlayOnPackages = [&](const QRect &band, const auto &draw) {
        for (const auto &item : layouts) {
            const QRect hit = item.rect.intersected(band);
            if (!hit.isEmpty()) {
                draw(hit);
            }
        }
    };

    painter.setRenderHint(QPainter::Antialiasing, false);
    const BreakAdjustment breaks = JournalStore::instance().breakAdjustmentForDate(m_date);
    if (breaks.autoPauseMinutes > 0) {
        int runStart = -1;
        for (int i = 0; i <= breaks.autoPause.size(); ++i) {
            const bool inPause = i < breaks.autoPause.size() && breaks.autoPause[i];
            if (inPause && runStart < 0) {
                runStart = i;
            } else if (!inPause && runStart >= 0) {
                const int x1 = xAtMinute(startBound + runStart);
                const int x2 = xAtMinute(startBound + i);
                const QRect band(x1, chart.top() + 1, qMax(1, x2 - x1),
                                 qMax(1, chart.height() - 2));
                overlayOnPackages(band, [&](const QRect &rect) {
                    painter.fillRect(rect, QColor(160, 110, 20, 80));
                    painter.setPen(Qt::NoPen);
                    painter.setBrush(QBrush(QColor(110, 70, 0), Qt::BDiagPattern));
                    painter.drawRect(rect);
                });
                runStart = -1;
            }
        }
    }

    for (const QRect &pauseWindowBand : pauseWindowBands) {
        overlayOnPackages(pauseWindowBand, [&](const QRect &rect) {
            painter.fillRect(rect, QColor(40, 25, 0, 50));
            painter.setPen(QPen(QColor(160, 110, 0), 1));
            painter.setBrush(Qt::NoBrush);
            painter.drawRect(rect.adjusted(0, 0, -1, -1));
        });
    }

    if (m_dragging) {
        const int start = qMin(m_dragStartMinute, m_dragCurrentMinute);
        const int end = qMax(m_dragStartMinute, m_dragCurrentMinute);
        const QRect bars = barsRect();
        const int x1 = xAtMinute(start);
        const int x2 = qMax(x1 + 2, xAtMinute(end));
        painter.setPen(QPen(QColor(40, 40, 40, 180), 1, Qt::DashLine));
        painter.setBrush(QColor(40, 90, 180, 70));
        painter.drawRect(QRect(x1, bars.top(), x2 - x1, bars.height()));
    }
    painter.restore();
}

void DayView::mousePressEvent(QMouseEvent *event)
{
    if (event->button() != Qt::LeftButton) {
        return;
    }
    const QPoint pos = event->position().toPoint();
    if (!chartRect().contains(pos)) {
        return;
    }
    m_pressedPackageId = packageIdAt(pos);
    m_dragging = false;
    m_dragStartMinute = minuteAtX(pos.x());
    m_dragCurrentMinute = m_dragStartMinute;
}

void DayView::mouseMoveEvent(QMouseEvent *event)
{
    if (!(event->buttons() & Qt::LeftButton) || !m_pressedPackageId.isEmpty()) {
        return;
    }
    const QPoint pos = event->position().toPoint();
    m_dragCurrentMinute = minuteAtX(pos.x());
    if (qAbs(m_dragCurrentMinute - m_dragStartMinute) >= 1) {
        m_dragging = true;
        update();
    }
}

void DayView::mouseReleaseEvent(QMouseEvent *event)
{
    if (event->button() != Qt::LeftButton) {
        return;
    }
    if (m_dragging) {
        const int start = qMin(m_dragStartMinute, m_dragCurrentMinute);
        const int end = qMax(m_dragStartMinute, m_dragCurrentMinute);
        m_dragging = false;
        update();
        if (end > start) {
            addPackageAt(start, end, false);
        }
    }
    m_pressedPackageId.clear();
}

void DayView::mouseDoubleClickEvent(QMouseEvent *event)
{
    if (event->button() != Qt::LeftButton) {
        return;
    }
    const QPoint pos = event->position().toPoint();
    if (!chartRect().contains(pos)) {
        return;
    }
    const QString id = packageIdAt(pos);
    if (!id.isEmpty()) {
        editPackage(id);
        return;
    }
    const PauseInterval pause = pauseAt(pos);
    if (pause.isValid()) {
        PauseDialog::runRange(m_date, pause.startMinute, pause.endMinute, true, this);
        return;
    }
    const int start = minuteAtX(pos.x());
    addPackageAt(start, start + 30, false);
}

void DayView::contextMenuEvent(QContextMenuEvent *event)
{
    const QPoint pos = event->pos();
    QMenu menu(this);
    const bool inChart = chartRect().contains(pos);
    const QString id = inChart ? packageIdAt(pos) : QString();
    const PauseInterval pause = inChart && id.isEmpty() ? pauseAt(pos) : PauseInterval{};
    const int minute = inChart ? minuteAtX(pos.x()) : 12 * 60;

    auto *addAction = menu.addAction(QStringLiteral("Arbeitspaket hinzufügen…"));
    auto *pauseAction = menu.addAction(pause.isValid() ? QStringLiteral("Pause bearbeiten…")
                                                       : QStringLiteral("Pause einfügen…"));
    auto *boundsAction = menu.addAction(QStringLiteral("Tagesgrenzen…"));
    QAction *editAction = nullptr;
    QAction *deleteAction = nullptr;
    if (!id.isEmpty()) {
        editAction = menu.addAction(QStringLiteral("Bearbeiten…"));
        deleteAction = menu.addAction(QStringLiteral("Löschen"));
    }

    QAction *chosen = menu.exec(event->globalPos());
    if (chosen == addAction) {
        addPackageAt(minute, minute + 30, false);
    } else if (chosen == pauseAction) {
        if (pause.isValid()) {
            PauseDialog::runRange(m_date, pause.startMinute, pause.endMinute, true, this);
        } else {
            openPauseAt(minute);
        }
    } else if (chosen == boundsAction) {
        openBoundsDialog();
    } else if (chosen == editAction) {
        editPackage(id);
    } else if (chosen == deleteAction) {
        deletePackage(id);
    }
}
