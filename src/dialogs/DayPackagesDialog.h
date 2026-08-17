#pragma once

#include "core/WorkPackage.h"

#include <QDate>
#include <QDialog>
#include <QString>

class QKeyEvent;
class QLabel;
class QPushButton;
class QTableWidget;

class DayPackagesDialog : public QDialog
{
    Q_OBJECT

public:
    explicit DayPackagesDialog(const QDate &date, QWidget *parent = nullptr);

protected:
    void keyPressEvent(QKeyEvent *event) override;

private:
    void setupUi();
    void refresh();
    void updateButtons();
    QString selectedId() const;
    void addPackage();
    void addPause();
    void editSelected();
    void deleteSelected();
    void openEditor(const WorkPackage &package);
    bool selectedPause(int *startMinute, int *endMinute) const;

    QDate m_date;
    QLabel *m_summaryLabel = nullptr;
    QTableWidget *m_table = nullptr;
    QPushButton *m_addButton = nullptr;
    QPushButton *m_pauseButton = nullptr;
    QPushButton *m_editButton = nullptr;
    QPushButton *m_deleteButton = nullptr;
};
