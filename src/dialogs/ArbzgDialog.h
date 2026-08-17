#pragma once

#include <QDialog>

class QComboBox;
class QLabel;
class QSpinBox;
class QTableWidget;

class ArbzgDialog : public QDialog
{
    Q_OBJECT

public:
    explicit ArbzgDialog(int year, int month, QWidget *parent = nullptr);

private:
    void setupUi();
    void refresh();
    void saveNachweis();

    int m_year = 0;
    int m_month = 0;

    QSpinBox *m_yearSpin = nullptr;
    QComboBox *m_monthCombo = nullptr;
    QLabel *m_averageLabel = nullptr;
    QLabel *m_yearLabel = nullptr;
    QTableWidget *m_table = nullptr;
};
