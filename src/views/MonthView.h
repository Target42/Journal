#pragma once

#include <QDate>
#include <QVector>
#include <QWidget>

class QLabel;
class QTableWidget;
struct Absence;

class MonthView : public QWidget
{
    Q_OBJECT

public:
    explicit MonthView(QWidget *parent = nullptr);

    QDate displayedMonth() const { return m_month; }

public slots:
    void setMonth(int year, int month);
    void selectDate(const QDate &date);
    void refresh();

signals:
    void dayActivated(const QDate &date);

private slots:
    void onRowClicked(int row, int column);
    void onRowDoubleClicked(int row, int column);
    void showDayContextMenu(const QPoint &pos);

private:
    void setupUi();
    void fillDayRow(int day);
    void updateSummary();
    void applyRowColors(int row, const QDate &date, const QString &hint);
    void setHoursItem(int row, int column, double hours, bool saldo);
    void setTextItem(int row, int column, const QString &text, bool rightAlign = false);

    QDate dateFromRow(int row) const;
    void applyAbsence(const QVector<QDate> &dates, const Absence &absence);
    void openRangeDialog(const QDate &from);
    void openDayPackagesDialog(const QDate &date);

    QDate m_month;
    QLabel *m_summaryLabel = nullptr;
    QTableWidget *m_dayTable = nullptr;
};
