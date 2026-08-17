#pragma once

#include <QDate>
#include <QDialog>

class QLabel;
class QTimeEdit;

class PauseDialog : public QDialog
{
    Q_OBJECT

public:
    PauseDialog(const QDate &date, int startMinute, int endMinute, bool existing,
                QWidget *parent = nullptr);

    int startMinute() const;
    int endMinute() const;
    bool wasDeleted() const { return m_deleted; }

    static bool runAt(const QDate &date, int atMinute, QWidget *parent);
    static bool runRange(const QDate &date, int startMinute, int endMinute, bool existing,
                         QWidget *parent);

    void accept() override;

private:
    void setupUi();
    void updateDuration();
    void confirmDelete();

    QDate m_date;
    bool m_existing = false;
    bool m_deleted = false;

    QTimeEdit *m_startEdit = nullptr;
    QTimeEdit *m_endEdit = nullptr;
    QLabel *m_durationLabel = nullptr;
};
