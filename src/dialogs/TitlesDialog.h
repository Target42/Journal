#pragma once

#include <QDialog>

class QListWidget;
class QPushButton;

class TitlesDialog : public QDialog
{
    Q_OBJECT

public:
    explicit TitlesDialog(QWidget *parent = nullptr);

private:
    void setupUi();
    void refreshList();
    void updateButtons();
    QString selectedTitle() const;
    void addTitle();
    void replaceTitle();

    QListWidget *m_list = nullptr;
    QPushButton *m_addButton = nullptr;
    QPushButton *m_replaceButton = nullptr;
};
