#pragma once

#include <QDialog>

class QCheckBox;
class QDateEdit;
class QLabel;
class QPushButton;
class QTableWidget;

class RetirementDialog : public QDialog
{
    Q_OBJECT

public:
    explicit RetirementDialog(QWidget *parent = nullptr);

private slots:
    void recalculate();
    void downloadMissingHolidays();
    void persistInputs();
    void onDownloadProgress(const QString &kind, int year, int current, int total);
    void onDownloadFinished(const QString &kind, int year, bool ok, const QString &message);

private:
    void setupUi();
    void loadFromSettings();
    void setBusy(bool busy);
    void fillTable();

    QDateEdit *m_fromEdit = nullptr;
    QDateEdit *m_retirementEdit = nullptr;
    QCheckBox *m_prorateCheck = nullptr;
    QLabel *m_metaLabel = nullptr;
    QLabel *m_lastWorkLabel = nullptr;
    QLabel *m_summaryLabel = nullptr;
    QLabel *m_statusLabel = nullptr;
    QTableWidget *m_table = nullptr;
    QPushButton *m_calculateButton = nullptr;
    QPushButton *m_downloadButton = nullptr;

    bool m_busy = false;
};
