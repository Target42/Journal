#pragma once

#include "core/BreakRules.h"
#include "core/WorkPackage.h"

#include <QDate>
#include <QRect>
#include <QString>
#include <QVector>
#include <QWidget>
#include <array>

class QCheckBox;
class QLabel;
class QToolButton;
struct Appointment;

class DayView : public QWidget
{
    Q_OBJECT

public:
    explicit DayView(QWidget *parent = nullptr);

    QDate date() const { return m_date; }

public slots:
    void setDate(const QDate &date);

signals:
    void dateChanged(const QDate &date);

protected:
    void paintEvent(QPaintEvent *event) override;
    void mousePressEvent(QMouseEvent *event) override;
    void mouseMoveEvent(QMouseEvent *event) override;
    void mouseReleaseEvent(QMouseEvent *event) override;
    void mouseDoubleClickEvent(QMouseEvent *event) override;
    void contextMenuEvent(QContextMenuEvent *event) override;

private:
    struct PackageLayout {
        QString id;
        QRect rect;
        int startMinute = 0;
    };

    void setupUi();
    void refreshHeader();
    QRect chartRect() const;
    QRect barsRect() const;
    int minuteAtX(int x) const;
    int xAtMinute(int minute) const;
    QVector<PackageLayout> layoutPackages() const;
    QString packageIdAt(const QPoint &pos) const;
    QRect pauseRect(const PauseInterval &pause) const;
    PauseInterval pauseAt(const QPoint &pos) const;
    QRect appointmentRect(const Appointment &appointment) const;
    QString appointmentIdAt(const QPoint &pos) const;
    void addAppointmentAt(int startMinute);
    void addPackageAt(int startMinute, int endMinute, bool active);
    void editPackage(const QString &id);
    void deletePackage(const QString &id);
    void openEditor(const WorkPackage &package);
    void openBoundsDialog();
    void openPauseAt(int minute);
    void refreshPausePresetChecks();
    void onPausePresetToggled(bool checked);
    DayBounds bounds() const;
    int windowStart() const;
    int windowEnd() const;

    QDate m_date;
    QLabel *m_headerLabel = nullptr;
    QToolButton *m_boundsButton = nullptr;
    QToolButton *m_addButton = nullptr;
    QToolButton *m_pauseButton = nullptr;
    std::array<QCheckBox *, kPausePresetCount> m_pauseChecks {};

    bool m_dragging = false;
    int m_dragStartMinute = 0;
    int m_dragCurrentMinute = 0;
    QString m_pressedPackageId;
};
