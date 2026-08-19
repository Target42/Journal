#pragma once

#include "core/AppointmentCatalog.h"

#include <QDate>
#include <QDialog>

class QCheckBox;
class QDateEdit;
class QLabel;
class QLineEdit;
class QListWidget;
class QPushButton;
class QRadioButton;
class QTimeEdit;

class TerminEditDialog : public QDialog
{
    Q_OBJECT

public:
    TerminEditDialog(Appointment appointment, bool existing, QWidget *parent = nullptr);

    Appointment appointment() const;
    bool wasDeleted() const { return m_deleted; }

    static bool runNew(QWidget *parent);
    static bool runNewOnce(const QDate &date, int startMinute, QWidget *parent);
    static bool runEdit(const Appointment &appointment, QWidget *parent);

    void accept() override;

private:
    void setupUi();
    void updateKindUi();
    void confirmDelete();
    Appointment collect() const;

    Appointment m_appointment;
    bool m_existing = false;
    bool m_deleted = false;

    QLineEdit *m_titleEdit = nullptr;
    QTimeEdit *m_startEdit = nullptr;
    QTimeEdit *m_endEdit = nullptr;
    QRadioButton *m_onceRadio = nullptr;
    QRadioButton *m_weeklyRadio = nullptr;
    QDateEdit *m_dateEdit = nullptr;
    QCheckBox *m_dayChecks[7] {};
    QLabel *m_dateLabel = nullptr;
};

class TermineDialog : public QDialog
{
    Q_OBJECT

public:
    explicit TermineDialog(QWidget *parent = nullptr);

private:
    void setupUi();
    void refreshList();
    void updateButtons();
    QString selectedId() const;
    void addAppointment();
    void editAppointment();
    void deleteAppointment();

    QListWidget *m_list = nullptr;
    QPushButton *m_addButton = nullptr;
    QPushButton *m_editButton = nullptr;
    QPushButton *m_deleteButton = nullptr;
};
