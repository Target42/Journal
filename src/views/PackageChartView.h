#pragma once

#include <QWidget>

class PackageChartView : public QWidget
{
    Q_OBJECT

public:
    explicit PackageChartView(QWidget *parent = nullptr);

public slots:
    void setMonth(int year, int month);
    void refresh();

protected:
    void paintEvent(QPaintEvent *event) override;

private:
    int m_year = 0;
    int m_month = 0;
};
