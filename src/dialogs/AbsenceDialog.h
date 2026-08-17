#pragma once

#include "core/Absence.h"

#include <QDate>
#include <QDialog>

class QDateEdit;
class QRadioButton;

class AbsenceDialog : public QDialog
{
    Q_OBJECT

public:
    AbsenceDialog(const QDate &from, const QDate &to, QWidget *parent = nullptr);

    QDate fromDate() const;
    QDate toDate() const;
    Absence absence() const;
    bool isClear() const;

    void accept() override;

private:
    void setupUi();
    void updateExtentEnabled();

    QDateEdit *m_fromEdit = nullptr;
    QDateEdit *m_toEdit = nullptr;
    QRadioButton *m_vacationRadio = nullptr;
    QRadioButton *m_sickRadio = nullptr;
    QRadioButton *m_clearRadio = nullptr;
    QRadioButton *m_fullRadio = nullptr;
    QRadioButton *m_halfRadio = nullptr;
};
