#include "MainWindow.h"

#include "core/AppSettings.h"
#include "core/ArbzgRules.h"
#include "core/CalendarService.h"
#include "core/JournalStore.h"
#include "core/TimeTotals.h"
#include "dialogs/ArbzgDialog.h"
#include "dialogs/RetirementDialog.h"
#include "dialogs/SettingsDialog.h"
#include "dialogs/TermineDialog.h"
#include "dialogs/TitlesDialog.h"
#include "views/AccountTrendView.h"
#include "views/DayView.h"
#include "views/MonthView.h"
#include "views/PackageChartView.h"
#include "views/YearView.h"

#include <QApplication>
#include <QAction>
#include <QDate>
#include <QDialog>
#include <QDialogButtonBox>
#include <QFileDialog>
#include <QFormLayout>
#include <QGroupBox>
#include <QKeySequence>
#include <QLabel>
#include <QLocale>
#include <QMenuBar>
#include <QMessageBox>
#include <QPushButton>
#include <QSizePolicy>
#include <QSpinBox>
#include <QSplitter>
#include <QStatusBar>
#include <QVBoxLayout>
#include <QWidget>

namespace {
QGroupBox *wrapInGroup(const QString &title, QWidget *inner, QWidget *parent)
{
    auto *box = new QGroupBox(title, parent);
    auto *layout = new QVBoxLayout(box);
    layout->setContentsMargins(8, 6, 8, 8);
    layout->setSpacing(4);
    layout->addWidget(inner);
    return box;
}

QString packageChartTitle(int year, int month)
{
    const QDate monthDate(year, month, 1);
    if (!monthDate.isValid()) {
        return QStringLiteral("Arbeitspaketübersicht");
    }
    return QStringLiteral("Arbeitspaketübersicht – %1")
        .arg(QLocale().toString(monthDate, QStringLiteral("MMMM yyyy")));
}
} // namespace

MainWindow::MainWindow(QWidget *parent)
    : QMainWindow(parent)
{
    setWindowTitle(QStringLiteral("Journal – Arbeitszeiterfassung"));
    resize(1280, 800);

    TimeTotals::instance();

    setupUi();
    setupMenus();
    updateStatusBar();

    connect(&CalendarService::instance(), &CalendarService::downloadFinished,
            this, &MainWindow::onCalendarDownloadFinished);
    connect(&AppSettings::instance(), &AppSettings::changed,
            this, &MainWindow::updateStatusBar);
    connect(&JournalStore::instance(), &JournalStore::changed,
            this, &MainWindow::updateStatusBar);
    connect(&JournalStore::instance(), &JournalStore::activeDayTicked,
            this, &MainWindow::updateStatusBar);
}

void MainWindow::setupUi()
{
    auto *central = new QWidget(this);
    auto *rootLayout = new QVBoxLayout(central);
    rootLayout->setContentsMargins(8, 8, 8, 8);
    rootLayout->setSpacing(8);

    auto *topSplitter = new QSplitter(Qt::Horizontal, central);

    m_monthView = new MonthView(topSplitter);
    auto *monthGroup = wrapInGroup(QStringLiteral("Monatsübersicht"), m_monthView, topSplitter);

    auto *rightSplitter = new QSplitter(Qt::Vertical, topSplitter);
    m_yearView = new YearView(rightSplitter);
    m_packageChartView = new PackageChartView(rightSplitter);
    m_accountTrendView = new AccountTrendView(rightSplitter);

    auto *yearGroup = wrapInGroup(QStringLiteral("Jahresübersicht"), m_yearView, rightSplitter);
    auto *packageGroup = wrapInGroup(
        packageChartTitle(m_monthView->displayedMonth().year(),
                          m_monthView->displayedMonth().month()),
        m_packageChartView, rightSplitter);
    auto *trendGroup = wrapInGroup(m_accountTrendView->caption(),
                                   m_accountTrendView, rightSplitter);

    rightSplitter->addWidget(yearGroup);
    rightSplitter->addWidget(packageGroup);
    rightSplitter->addWidget(trendGroup);
    rightSplitter->setStretchFactor(0, 3);
    rightSplitter->setStretchFactor(1, 2);
    rightSplitter->setStretchFactor(2, 2);
    rightSplitter->setSizes({280, 180, 160});

    topSplitter->addWidget(monthGroup);
    topSplitter->addWidget(rightSplitter);
    topSplitter->setStretchFactor(0, 3);
    topSplitter->setStretchFactor(1, 2);
    topSplitter->setSizes({720, 480});

    m_dayView = new DayView(central);
    m_dayView->setFixedHeight(100);
    auto *dayGroup = wrapInGroup(QStringLiteral("Tagesübersicht"), m_dayView, central);
    dayGroup->setSizePolicy(QSizePolicy::Expanding, QSizePolicy::Fixed);

    rootLayout->addWidget(topSplitter, 1);
    rootLayout->addWidget(dayGroup, 0);

    setCentralWidget(central);

    connect(m_yearView, &YearView::monthActivated,
            m_monthView, &MonthView::setMonth);

    connect(m_yearView, &YearView::monthActivated, this,
            [this, packageGroup](int year, int month) {
        m_packageChartView->setMonth(year, month);
        packageGroup->setTitle(packageChartTitle(year, month));
        const QDate current = m_dayView->date();
        const QDate today = QDate::currentDate();
        if (current.year() != year || current.month() != month) {
            if (today.year() == year && today.month() == month) {
                m_dayView->setDate(today);
            } else {
                m_dayView->setDate(QDate(year, month, 1));
            }
        }
        m_monthView->selectDate(m_dayView->date());
    });

    connect(m_yearView, &YearView::yearChanged, this, [this, packageGroup](int year) {
        const int month = m_monthView->displayedMonth().month();
        CalendarService::instance().ensureYearLoaded(year);
        m_monthView->setMonth(year, month);
        m_yearView->selectMonth(month);
        m_packageChartView->setMonth(year, month);
        packageGroup->setTitle(packageChartTitle(year, month));
        const QDate today = QDate::currentDate();
        if (today.year() == year && today.month() == month) {
            m_dayView->setDate(today);
        } else {
            m_dayView->setDate(QDate(year, month, 1));
        }
        m_monthView->selectDate(m_dayView->date());
    });

    connect(m_monthView, &MonthView::dayActivated, m_dayView, &DayView::setDate);
    connect(m_dayView, &DayView::dateChanged, m_monthView, &MonthView::selectDate);

    m_yearView->selectMonth(m_monthView->displayedMonth().month());
    m_packageChartView->setMonth(m_monthView->displayedMonth().year(),
                                m_monthView->displayedMonth().month());
    m_monthView->selectDate(m_dayView->date());

    const auto updateTrendTitle = [trendGroup, this]() {
        trendGroup->setTitle(m_accountTrendView->caption());
    };
    connect(&JournalStore::instance(), &JournalStore::changed, this, updateTrendTitle);
    connect(&AppSettings::instance(), &AppSettings::changed, this, updateTrendTitle);
    connect(&CalendarService::instance(), &CalendarService::yearDataChanged,
            this, updateTrendTitle);
}

void MainWindow::setupMenus()
{
    auto *fileMenu = menuBar()->addMenu(QStringLiteral("&Datei"));

    auto *dataPathAction = fileMenu->addAction(QStringLiteral("Datenordner wählen…"));
    connect(dataPathAction, &QAction::triggered, this, &MainWindow::chooseDataPath);

    auto *settingsAction = fileMenu->addAction(QStringLiteral("Einstellungen…"));
    settingsAction->setShortcut(QKeySequence::Preferences);
    connect(settingsAction, &QAction::triggered, this, &MainWindow::openSettings);

    auto *titlesAction = fileMenu->addAction(QStringLiteral("Titel…"));
    connect(titlesAction, &QAction::triggered, this, &MainWindow::openTitles);

    auto *termineAction = fileMenu->addAction(QStringLiteral("Termine…"));
    connect(termineAction, &QAction::triggered, this, &MainWindow::openTermine);

    auto *absenceAction = fileMenu->addAction(QStringLiteral("Abwesenheit…"));
    connect(absenceAction, &QAction::triggered, m_monthView, &MonthView::openAbsenceDialog);

    fileMenu->addSeparator();

    auto *retirementAction = fileMenu->addAction(QStringLiteral("Rentenrechner…"));
    connect(retirementAction, &QAction::triggered, this, &MainWindow::openRetirementCalculator);

    auto *arbzgAction = fileMenu->addAction(QStringLiteral("ArbZG…"));
    connect(arbzgAction, &QAction::triggered, this, &MainWindow::openArbzg);

    fileMenu->addSeparator();

    auto *downloadHolidaysAction =
        fileMenu->addAction(QStringLiteral("Feiertage herunterladen…"));
    connect(downloadHolidaysAction, &QAction::triggered,
            this, &MainWindow::downloadPublicHolidays);

    auto *downloadSchoolAction =
        fileMenu->addAction(QStringLiteral("Ferien herunterladen…"));
    connect(downloadSchoolAction, &QAction::triggered,
            this, &MainWindow::downloadSchoolHolidays);

    fileMenu->addSeparator();

    auto *quitAction = fileMenu->addAction(QStringLiteral("Beenden"));
    quitAction->setShortcut(QKeySequence::Quit);
    connect(quitAction, &QAction::triggered, this, &QWidget::close);

    auto *helpMenu = menuBar()->addMenu(QStringLiteral("&Hilfe"));
    auto *aboutAction = helpMenu->addAction(QStringLiteral("Über Journal"));
    connect(aboutAction, &QAction::triggered, this, &MainWindow::showAbout);
}

int MainWindow::activeYear() const
{
    if (m_yearView) {
        return m_yearView->displayedYear();
    }
    return m_monthView ? m_monthView->displayedMonth().year() : QDate::currentDate().year();
}

int MainWindow::askDownloadYear(const QString &title)
{
    QDialog dialog(this);
    dialog.setWindowTitle(title);
    dialog.setModal(true);

    auto *layout = new QVBoxLayout(&dialog);

    auto *yearSpin = new QSpinBox(&dialog);
    yearSpin->setRange(1970, 2100);
    yearSpin->setValue(qMax(activeYear(), QDate::currentDate().year() + 1));
    yearSpin->setMinimumWidth(120);
    yearSpin->setAlignment(Qt::AlignRight);

    auto *form = new QFormLayout();
    form->addRow(QStringLiteral("Jahr:"), yearSpin);
    layout->addLayout(form);

    auto *hint = new QLabel(
        QStringLiteral("Wähle das Jahr, für das Feiertage bzw. Ferien geladen werden sollen. "
                       "Damit kannst du z. B. schon im Vorjahr den Kalender für die Urlaubsplanung holen."),
        &dialog);
    hint->setWordWrap(true);
    layout->addWidget(hint);

    auto *buttons = new QDialogButtonBox(QDialogButtonBox::Ok | QDialogButtonBox::Cancel, &dialog);
    if (auto *ok = buttons->button(QDialogButtonBox::Ok)) {
        ok->setText(QStringLiteral("Herunterladen"));
        ok->setDefault(true);
    }
    if (auto *cancel = buttons->button(QDialogButtonBox::Cancel)) {
        cancel->setText(QStringLiteral("Abbrechen"));
    }
    layout->addWidget(buttons);

    connect(buttons, &QDialogButtonBox::accepted, &dialog, &QDialog::accept);
    connect(buttons, &QDialogButtonBox::rejected, &dialog, &QDialog::reject);

    yearSpin->setFocus();
    yearSpin->selectAll();

    if (dialog.exec() != QDialog::Accepted) {
        return 0;
    }
    return yearSpin->value();
}

void MainWindow::downloadPublicHolidays()
{
    const int year = askDownloadYear(QStringLiteral("Feiertage herunterladen"));
    if (year <= 0) {
        return;
    }
    statusBar()->showMessage(QStringLiteral("Lade Feiertage für %1…").arg(year));
    CalendarService::instance().downloadPublicHolidays(year);
}

void MainWindow::downloadSchoolHolidays()
{
    const int year = askDownloadYear(QStringLiteral("Ferien herunterladen"));
    if (year <= 0) {
        return;
    }
    statusBar()->showMessage(QStringLiteral("Lade Ferien für %1…").arg(year));
    CalendarService::instance().downloadSchoolHolidays(year);
}

void MainWindow::onCalendarDownloadFinished(const QString &kind, int /*year*/,
                                            bool ok, const QString &message)
{
    if (kind == QLatin1String("feiertage-jahre")) {
        return;
    }
    if (ok) {
        QMessageBox::information(this, QStringLiteral("Download"), message);
        updateStatusBar();
    } else {
        QMessageBox::warning(this, QStringLiteral("Download"), message);
        updateStatusBar();
    }
}

void MainWindow::openSettings()
{
    SettingsDialog dialog(this);
    dialog.exec();
}

void MainWindow::openTitles()
{
    TitlesDialog dialog(this);
    dialog.exec();
}

void MainWindow::openTermine()
{
    TermineDialog dialog(this);
    dialog.exec();
}

void MainWindow::openRetirementCalculator()
{
    RetirementDialog dialog(this);
    dialog.exec();
}

void MainWindow::openArbzg()
{
    const QDate month = m_monthView ? m_monthView->displayedMonth() : QDate::currentDate();
    ArbzgDialog dialog(month.year(), month.month(), this);
    dialog.exec();
}

void MainWindow::chooseDataPath()
{
    const QString current = AppSettings::instance().dataPath();
    const QString path = QFileDialog::getExistingDirectory(
        this,
        QStringLiteral("Datenordner wählen"),
        current);

    if (path.isEmpty()) {
        return;
    }

    AppSettings::instance().setDataPath(path);
    updateStatusBar();
    CalendarService::instance().reloadYear(activeYear());
}

void MainWindow::showAbout()
{
    QMessageBox::about(
        this,
        QStringLiteral("Über Journal"),
        QStringLiteral(
            "<h3>Journal</h3>"
            "<p>Persönliche Arbeitszeiterfassung nach deutschen Vorgaben (ArbZG).</p>"
            "<p>Version %1</p>")
            .arg(QApplication::applicationVersion()));
}

void MainWindow::updateStatusBar()
{
    statusBar()->showMessage(
        QStringLiteral("Datenordner: %1  |  Bundesland: %2")
            .arg(AppSettings::instance().dataPath(),
                 AppSettings::instance().stateDisplayName()));

    const ArbzgDay today = ArbzgCompliance::assessDay(QDate::currentDate());
    if (today.hasIssue()) {
        statusBar()->showMessage(statusBar()->currentMessage()
                                 + QStringLiteral("  |  ArbZG: %1").arg(today.issues.first()));
    } else if (today.usualPauseMissed && !today.notes.isEmpty()) {
        statusBar()->showMessage(statusBar()->currentMessage()
                                 + QStringLiteral("  |  %1").arg(today.notes.first()));
    }
}
