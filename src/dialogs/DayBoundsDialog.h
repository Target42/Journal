#pragma once

#include <QDate>
#include <QDialog>

class QLabel;
class QRadioButton;
class QTimeEdit;

class DayBoundsDialog : public QDialog
{
    Q_OBJECT

public:
    explicit DayBoundsDialog(const QDate &date, QWidget *parent = nullptr);

    void accept() override;

private:
    void setupUi();
    void load();
    void updateUi();

    QDate m_date;
    QRadioButton *m_globalRadio = nullptr;
    QRadioButton *m_customRadio = nullptr;
    QLabel *m_globalLabel = nullptr;
    QTimeEdit *m_startEdit = nullptr;
    QTimeEdit *m_endEdit = nullptr;
};
