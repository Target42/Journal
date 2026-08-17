#pragma once

#include "core/TimeTotals.h"

#include <QString>
#include <QWidget>

class AccountTrendView : public QWidget
{
    Q_OBJECT

public:
    explicit AccountTrendView(QWidget *parent = nullptr);

    QString caption() const;

public slots:
    void refresh();

protected:
    void paintEvent(QPaintEvent *event) override;

private:
    AccountTrend m_trend;
};
