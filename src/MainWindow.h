#pragma once

#include <QMainWindow>

class MonthView;
class DayView;
class YearView;
class PackageChartView;
class AccountTrendView;

class MainWindow : public QMainWindow
{
    Q_OBJECT

public:
    explicit MainWindow(QWidget *parent = nullptr);

private slots:
    void chooseDataPath();
    void openSettings();
    void openTitles();
    void openRetirementCalculator();
    void openArbzg();
    void downloadPublicHolidays();
    void downloadSchoolHolidays();
    void onCalendarDownloadFinished(const QString &kind, int year, bool ok, const QString &message);
    void showAbout();

private:
    void setupUi();
    void setupMenus();
    void updateStatusBar();
    int activeYear() const;
    int askDownloadYear(const QString &title);

    MonthView *m_monthView = nullptr;
    DayView *m_dayView = nullptr;
    YearView *m_yearView = nullptr;
    PackageChartView *m_packageChartView = nullptr;
    AccountTrendView *m_accountTrendView = nullptr;
};
