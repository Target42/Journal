#pragma once

#include "core/WorkPackage.h"

#include <QColor>
#include <QDate>
#include <QDialog>

class QCheckBox;
class QComboBox;
class QPlainTextEdit;
class QPushButton;
class QTimeEdit;

class WorkPackageDialog : public QDialog
{
    Q_OBJECT

public:
    WorkPackageDialog(const QDate &date, const WorkPackage &package, QWidget *parent = nullptr);

    WorkPackage package() const { return m_package; }
    bool wasDeleted() const { return m_deleted; }

    void accept() override;

private:
    void setupUi();
    void populateTitles();
    void applyTitleColor(const QString &title);
    void chooseColor();
    void updateColorButton();
    void updateActiveUi();
    void confirmDelete();

    QDate m_date;
    WorkPackage m_package;
    bool m_isNew = false;
    bool m_deleted = false;
    QColor m_color;

    QComboBox *m_titleCombo = nullptr;
    QPushButton *m_colorButton = nullptr;
    QPlainTextEdit *m_detailsEdit = nullptr;
    QTimeEdit *m_startEdit = nullptr;
    QTimeEdit *m_endEdit = nullptr;
    QCheckBox *m_activeCheck = nullptr;
    QPushButton *m_deleteButton = nullptr;
};
