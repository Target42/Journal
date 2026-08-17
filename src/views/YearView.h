#pragma once

#include <QWidget>

class QLabel;
class QPushButton;
class QTableWidget;

class YearView : public QWidget
{
    Q_OBJECT

public:
    explicit YearView(QWidget *parent = nullptr);

    int displayedYear() const { return m_year; }

public slots:
    void setYear(int year);
    void selectMonth(int month);

signals:
    void monthActivated(int year, int month);
    void yearChanged(int year);

private slots:
    void goPreviousYear();
    void goNextYear();
    void onRowClicked(int row, int column);

private:
    void setupUi();
    void refresh();
    void fillMonthRow(int month);
    void updateYearHeader();
    void setHoursItem(int row, int column, double hours, bool saldo);
    void setDaysItem(int row, int column, double days);

    int m_year = 0;
    int m_selectedMonth = 0;

    QLabel *m_headerLabel = nullptr;
    QLabel *m_vacationLabel = nullptr;
    QPushButton *m_prevButton = nullptr;
    QPushButton *m_nextButton = nullptr;
    QTableWidget *m_monthTable = nullptr;
};
