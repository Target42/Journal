#include "WorkPackageDialog.h"

#include "core/JournalStore.h"
#include "core/TitleCatalog.h"

#include <QAbstractButton>
#include <QCheckBox>
#include <QColorDialog>
#include <QComboBox>
#include <QDialogButtonBox>
#include <QFormLayout>
#include <QHBoxLayout>
#include <QIcon>
#include <QLineEdit>
#include <QLocale>
#include <QMessageBox>
#include <QPixmap>
#include <QPlainTextEdit>
#include <QPushButton>
#include <QTimeEdit>
#include <QVBoxLayout>

WorkPackageDialog::WorkPackageDialog(const QDate &date, const WorkPackage &package, QWidget *parent)
    : QDialog(parent)
    , m_date(date)
    , m_package(package)
    , m_isNew(package.title.trimmed().isEmpty())
    , m_color(TitleCatalog::instance().nextUnusedColor())
{
    setModal(true);
    setMinimumWidth(460);
    const QString dayText = QLocale().toString(m_date, QStringLiteral("ddd, d. MMM yyyy"));
    setWindowTitle(m_isNew ? QStringLiteral("Neues Arbeitspaket – %1").arg(dayText)
                           : QStringLiteral("Arbeitspaket bearbeiten – %1").arg(dayText));

    if (!m_isNew) {
        m_color = TitleCatalog::instance().colorFor(m_package.title);
    }

    setupUi();
    populateTitles();
    updateColorButton();
    updateActiveUi();
}

void WorkPackageDialog::setupUi()
{
    auto *root = new QVBoxLayout(this);

    auto *form = new QFormLayout();
    form->setFieldGrowthPolicy(QFormLayout::AllNonFixedFieldsGrow);

    auto *titleRow = new QWidget(this);
    auto *titleLayout = new QHBoxLayout(titleRow);
    titleLayout->setContentsMargins(0, 0, 0, 0);
    titleLayout->setSpacing(8);

    m_titleCombo = new QComboBox(titleRow);
    m_titleCombo->setEditable(true);
    m_titleCombo->setInsertPolicy(QComboBox::NoInsert);
    m_titleCombo->setSizePolicy(QSizePolicy::Expanding, QSizePolicy::Fixed);
    m_titleCombo->lineEdit()->setPlaceholderText(
        QStringLiteral("Titel wählen oder neu eingeben"));

    m_colorButton = new QPushButton(titleRow);
    m_colorButton->setFixedSize(40, 24);
    m_colorButton->setToolTip(QStringLiteral("Farbe für diesen Titel"));
    m_colorButton->setFocusPolicy(Qt::NoFocus);

    titleLayout->addWidget(m_titleCombo, 1);
    titleLayout->addWidget(m_colorButton);
    form->addRow(QStringLiteral("Titel:"), titleRow);

    m_detailsEdit = new QPlainTextEdit(this);
    m_detailsEdit->setPlaceholderText(QStringLiteral("Optionale Details"));
    m_detailsEdit->setFixedHeight(64);
    m_detailsEdit->setPlainText(m_package.details);
    form->addRow(QStringLiteral("Details:"), m_detailsEdit);

    m_startEdit = new QTimeEdit(this);
    m_startEdit->setDisplayFormat(QStringLiteral("HH:mm"));
    m_startEdit->setTime(m_package.start.isValid() ? m_package.start : QTime(8, 0));
    form->addRow(QStringLiteral("Von:"), m_startEdit);

    auto *endRow = new QWidget(this);
    auto *endLayout = new QHBoxLayout(endRow);
    endLayout->setContentsMargins(0, 0, 0, 0);
    endLayout->setSpacing(8);

    m_endEdit = new QTimeEdit(endRow);
    m_endEdit->setDisplayFormat(QStringLiteral("HH:mm"));
    m_endEdit->setTime(m_package.end.isValid() ? m_package.end : QTime(8, 30));

    m_activeCheck = new QCheckBox(QStringLiteral("Aktiv (Ende = aktuelle Uhrzeit)"), endRow);
    const bool today = m_date == QDate::currentDate();
    m_activeCheck->setEnabled(today);
    m_activeCheck->setChecked(m_package.active && today);
    m_activeCheck->setToolTip(
        today ? QStringLiteral("Solange das Paket aktiv ist, läuft das Ende mit der Uhrzeit mit.")
              : QStringLiteral("Aktiv kann nur am heutigen Tag gesetzt werden."));

    endLayout->addWidget(m_endEdit);
    endLayout->addWidget(m_activeCheck, 1);
    form->addRow(QStringLiteral("Bis:"), endRow);

    root->addLayout(form);

    auto *buttons = new QDialogButtonBox(QDialogButtonBox::Ok | QDialogButtonBox::Cancel, this);
    if (auto *ok = buttons->button(QDialogButtonBox::Ok)) {
        ok->setAutoDefault(false);
        ok->setDefault(true);
    }
    if (auto *cancel = buttons->button(QDialogButtonBox::Cancel)) {
        cancel->setText(QStringLiteral("Abbrechen"));
        cancel->setAutoDefault(false);
    }

    if (!m_isNew) {
        m_deleteButton = buttons->addButton(QStringLiteral("Löschen"),
                                            QDialogButtonBox::DestructiveRole);
        m_deleteButton->setAutoDefault(false);
        connect(m_deleteButton, &QPushButton::clicked, this, &WorkPackageDialog::confirmDelete);
    }

    root->addWidget(buttons);

    connect(m_titleCombo, &QComboBox::currentTextChanged,
            this, &WorkPackageDialog::applyTitleColor);
    connect(m_colorButton, &QPushButton::clicked, this, &WorkPackageDialog::chooseColor);
    connect(m_activeCheck, &QCheckBox::toggled, this, &WorkPackageDialog::updateActiveUi);
    connect(buttons, &QDialogButtonBox::accepted, this, &QDialog::accept);
    connect(buttons, &QDialogButtonBox::rejected, this, &QDialog::reject);
}

void WorkPackageDialog::populateTitles()
{
    const QString current = m_package.title;
    QSignalBlocker blocker(m_titleCombo);
    m_titleCombo->clear();

    const auto titles = TitleCatalog::instance().titles();
    for (const auto &entry : titles) {
        QPixmap pixmap(12, 12);
        pixmap.fill(entry.color);
        m_titleCombo->addItem(QIcon(pixmap), entry.title);
    }

    if (!current.isEmpty()) {
        const int index = m_titleCombo->findText(current, Qt::MatchFixedString);
        if (index >= 0) {
            m_titleCombo->setCurrentIndex(index);
        } else {
            m_titleCombo->setEditText(current);
        }
    } else {
        m_titleCombo->setCurrentIndex(-1);
        m_titleCombo->setEditText(QString());
    }
}

void WorkPackageDialog::applyTitleColor(const QString &title)
{
    if (TitleCatalog::instance().contains(title)) {
        m_color = TitleCatalog::instance().colorFor(title);
        updateColorButton();
    }
}

void WorkPackageDialog::chooseColor()
{
    const QColor chosen = QColorDialog::getColor(
        m_color, this, QStringLiteral("Farbe für den Titel"));
    if (!chosen.isValid()) {
        return;
    }
    m_color = chosen;
    updateColorButton();
}

void WorkPackageDialog::updateColorButton()
{
    m_colorButton->setStyleSheet(
        QStringLiteral("QPushButton { background-color: %1; border: 1px solid #666; }")
            .arg(m_color.name(QColor::HexRgb)));
}

void WorkPackageDialog::updateActiveUi()
{
    m_endEdit->setEnabled(!m_activeCheck->isChecked());
    if (m_activeCheck->isChecked()) {
        m_endEdit->setTime(minuteToTime(timeToMinute(QTime::currentTime())));
    }
}

void WorkPackageDialog::confirmDelete()
{
    const QString title = m_titleCombo->currentText().trimmed();
    QMessageBox box(this);
    box.setIcon(QMessageBox::Question);
    box.setWindowTitle(QStringLiteral("Arbeitspaket löschen"));
    box.setText(QStringLiteral("Arbeitspaket „%1“ wirklich löschen?")
                    .arg(title.isEmpty() ? QStringLiteral("(ohne Titel)") : title));
    box.setStandardButtons(QMessageBox::Yes | QMessageBox::No);
    box.setDefaultButton(QMessageBox::No);
    box.button(QMessageBox::Yes)->setText(QStringLiteral("Ja"));
    box.button(QMessageBox::No)->setText(QStringLiteral("Nein"));
    if (box.exec() != QMessageBox::Yes) {
        return;
    }
    m_deleted = true;
    QDialog::accept();
}

void WorkPackageDialog::accept()
{
    if (m_deleted) {
        QDialog::accept();
        return;
    }

    const QString title = m_titleCombo->currentText().trimmed();
    if (title.isEmpty()) {
        QMessageBox::warning(this, windowTitle(),
                             QStringLiteral("Bitte einen Titel eingeben oder auswählen."));
        return;
    }

    const QTime start = m_startEdit->time();
    const bool active = m_activeCheck->isChecked();
    const QTime end = active ? minuteToTime(timeToMinute(QTime::currentTime()))
                             : m_endEdit->time();

    if (!active && (!end.isValid() || timeToMinute(end) <= timeToMinute(start))) {
        QMessageBox::warning(this, windowTitle(),
                             QStringLiteral("Das Ende muss nach dem Start liegen."));
        return;
    }

    if (active && timeToMinute(QTime::currentTime()) < timeToMinute(start)) {
        QMessageBox::warning(this, windowTitle(),
                             QStringLiteral("Ein aktives Arbeitspaket darf nicht in der Zukunft beginnen."));
        return;
    }

    if (JournalStore::instance().startMinuteTaken(m_date, timeToMinute(start), m_package.id)) {
        QMessageBox::warning(
            this, windowTitle(),
            QStringLiteral("Ein anderes Arbeitspaket beginnt bereits in derselben Minute."));
        return;
    }

    TitleCatalog::instance().upsert(title, m_color);

    m_package.title = TitleCatalog::instance().canonicalTitle(title);
    m_package.details = m_detailsEdit->toPlainText().trimmed();
    m_package.start = start;
    m_package.end = end;
    m_package.active = active;
    QDialog::accept();
}
