#include "TermineDialog.h"

#include "core/WorkPackage.h"

#include <QAbstractButton>
#include <QAbstractItemView>
#include <QCheckBox>
#include <QDateEdit>
#include <QDialogButtonBox>
#include <QFormLayout>
#include <QGroupBox>
#include <QHBoxLayout>
#include <QLabel>
#include <QLineEdit>
#include <QListWidget>
#include <QMessageBox>
#include <QPushButton>
#include <QRadioButton>
#include <QSignalBlocker>
#include <QTimeEdit>
#include <QVBoxLayout>

namespace {
const QString kDayCaptions[] = {
    QStringLiteral("Mo"), QStringLiteral("Di"), QStringLiteral("Mi"), QStringLiteral("Do"),
    QStringLiteral("Fr"), QStringLiteral("Sa"), QStringLiteral("So"),
};
} // namespace

TerminEditDialog::TerminEditDialog(Appointment appointment, bool existing, QWidget *parent)
    : QDialog(parent)
    , m_appointment(appointment)
    , m_existing(existing)
{
    setModal(true);
    setMinimumWidth(460);
    setWindowTitle(existing ? QStringLiteral("Termin bearbeiten") : QStringLiteral("Termin anlegen"));
    setupUi();
}

void TerminEditDialog::setupUi()
{
    auto *root = new QVBoxLayout(this);

    auto *form = new QFormLayout();
    m_titleEdit = new QLineEdit(this);
    m_titleEdit->setText(m_appointment.title);
    form->addRow(QStringLiteral("Titel:"), m_titleEdit);

    auto *timeRow = new QHBoxLayout();
    m_startEdit = new QTimeEdit(this);
    m_startEdit->setDisplayFormat(QStringLiteral("HH:mm"));
    m_startEdit->setTime(minuteToTime(m_appointment.startMinute));
    m_endEdit = new QTimeEdit(this);
    m_endEdit->setDisplayFormat(QStringLiteral("HH:mm"));
    m_endEdit->setTime(minuteToTime(m_appointment.endMinute));
    timeRow->addWidget(new QLabel(QStringLiteral("Von:"), this));
    timeRow->addWidget(m_startEdit);
    timeRow->addSpacing(12);
    timeRow->addWidget(new QLabel(QStringLiteral("Bis:"), this));
    timeRow->addWidget(m_endEdit);
    timeRow->addStretch();
    form->addRow(QString(), timeRow);
    root->addLayout(form);

    auto *kindBox = new QGroupBox(QStringLiteral("Wiederholung"), this);
    auto *kindLayout = new QVBoxLayout(kindBox);
    m_onceRadio = new QRadioButton(QStringLiteral("Einmalig"), kindBox);
    m_weeklyRadio = new QRadioButton(QStringLiteral("Wöchentlich"), kindBox);
    kindLayout->addWidget(m_onceRadio);

    auto *dateRow = new QHBoxLayout();
    m_dateLabel = new QLabel(QStringLiteral("Datum:"), kindBox);
    m_dateEdit = new QDateEdit(kindBox);
    m_dateEdit->setDisplayFormat(QStringLiteral("dd.MM.yyyy"));
    m_dateEdit->setCalendarPopup(true);
    m_dateEdit->setDate(m_appointment.date.isValid() ? m_appointment.date : QDate::currentDate());
    dateRow->addWidget(m_dateLabel);
    dateRow->addWidget(m_dateEdit);
    dateRow->addStretch();
    kindLayout->addLayout(dateRow);

    kindLayout->addWidget(m_weeklyRadio);
    auto *daysRow = new QHBoxLayout();
    for (int i = 0; i < 7; ++i) {
        m_dayChecks[i] = new QCheckBox(kDayCaptions[i], kindBox);
        m_dayChecks[i]->setChecked(m_appointment.weekdays.contains(i + 1));
        daysRow->addWidget(m_dayChecks[i]);
    }
    daysRow->addStretch();
    kindLayout->addLayout(daysRow);
    root->addWidget(kindBox);

    if (m_appointment.kind == AppointmentKind::Weekly) {
        m_weeklyRadio->setChecked(true);
    } else {
        m_onceRadio->setChecked(true);
    }

    auto *hint = new QLabel(
        QStringLiteral("Termine dienen nur der Orientierung. Sie zählen nicht zur Arbeitszeit."),
        this);
    hint->setWordWrap(true);
    root->addWidget(hint);

    auto *buttons = new QDialogButtonBox(QDialogButtonBox::Ok | QDialogButtonBox::Cancel, this);
    if (auto *ok = buttons->button(QDialogButtonBox::Ok)) {
        ok->setText(QStringLiteral("Übernehmen"));
        ok->setDefault(true);
    }
    if (auto *cancel = buttons->button(QDialogButtonBox::Cancel)) {
        cancel->setText(QStringLiteral("Abbrechen"));
    }
    if (m_existing) {
        auto *remove = buttons->addButton(QStringLiteral("Termin löschen"),
                                          QDialogButtonBox::DestructiveRole);
        remove->setAutoDefault(false);
        connect(remove, &QPushButton::clicked, this, &TerminEditDialog::confirmDelete);
    }
    root->addWidget(buttons);

    connect(m_onceRadio, &QRadioButton::toggled, this, &TerminEditDialog::updateKindUi);
    connect(m_weeklyRadio, &QRadioButton::toggled, this, &TerminEditDialog::updateKindUi);
    connect(buttons, &QDialogButtonBox::accepted, this, &QDialog::accept);
    connect(buttons, &QDialogButtonBox::rejected, this, &QDialog::reject);
    updateKindUi();
    m_titleEdit->setFocus();
}

void TerminEditDialog::updateKindUi()
{
    const bool weekly = m_weeklyRadio->isChecked();
    m_dateLabel->setEnabled(!weekly);
    m_dateEdit->setEnabled(!weekly);
    for (auto *check : m_dayChecks) {
        check->setEnabled(weekly);
    }
}

Appointment TerminEditDialog::collect() const
{
    Appointment apt = m_appointment;
    apt.title = m_titleEdit->text().trimmed();
    apt.startMinute = timeToMinute(m_startEdit->time());
    apt.endMinute = timeToMinute(m_endEdit->time());
    if (m_weeklyRadio->isChecked()) {
        apt.kind = AppointmentKind::Weekly;
        apt.weekdays.clear();
        for (int i = 0; i < 7; ++i) {
            if (m_dayChecks[i]->isChecked()) {
                apt.weekdays.append(i + 1);
            }
        }
        apt.date = QDate();
    } else {
        apt.kind = AppointmentKind::Once;
        apt.date = m_dateEdit->date();
        apt.weekdays.clear();
    }
    return apt;
}

Appointment TerminEditDialog::appointment() const
{
    return collect();
}

void TerminEditDialog::confirmDelete()
{
    QMessageBox box(this);
    box.setIcon(QMessageBox::Question);
    box.setWindowTitle(QStringLiteral("Termin löschen"));
    box.setText(QStringLiteral("Den Termin „%1“ löschen?").arg(m_appointment.title));
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

void TerminEditDialog::accept()
{
    if (m_deleted) {
        QDialog::accept();
        return;
    }
    Appointment apt = collect();
    QString error;
    if (!AppointmentCatalog::instance().upsert(apt, &error)) {
        QMessageBox::warning(this, windowTitle(), error);
        return;
    }
    m_appointment = apt;
    QDialog::accept();
}

bool TerminEditDialog::runNew(QWidget *parent)
{
    Appointment apt;
    apt.startMinute = 9 * 60;
    apt.endMinute = 9 * 60 + 30;
    apt.kind = AppointmentKind::Once;
    apt.date = QDate::currentDate();
    TerminEditDialog dialog(apt, false, parent);
    return dialog.exec() == QDialog::Accepted;
}

bool TerminEditDialog::runNewOnce(const QDate &date, int startMinute, QWidget *parent)
{
    Appointment apt;
    apt.startMinute = qBound(0, startMinute, 23 * 60 + 30);
    apt.endMinute = qMin(24 * 60, apt.startMinute + 30);
    apt.kind = AppointmentKind::Once;
    apt.date = date.isValid() ? date : QDate::currentDate();
    TerminEditDialog dialog(apt, false, parent);
    return dialog.exec() == QDialog::Accepted;
}

bool TerminEditDialog::runEdit(const Appointment &appointment, QWidget *parent)
{
    TerminEditDialog dialog(appointment, true, parent);
    if (dialog.exec() != QDialog::Accepted) {
        return false;
    }
    if (dialog.wasDeleted()) {
        AppointmentCatalog::instance().remove(appointment.id);
        return true;
    }
    return true;
}

TermineDialog::TermineDialog(QWidget *parent)
    : QDialog(parent)
{
    setWindowTitle(QStringLiteral("Termine"));
    setModal(true);
    setMinimumWidth(520);
    setMinimumHeight(380);
    setupUi();
    refreshList();
    connect(&AppointmentCatalog::instance(), &AppointmentCatalog::changed,
            this, &TermineDialog::refreshList);
}

void TermineDialog::setupUi()
{
    auto *root = new QVBoxLayout(this);

    m_list = new QListWidget(this);
    m_list->setSelectionMode(QAbstractItemView::SingleSelection);
    root->addWidget(m_list, 1);

    auto *row = new QHBoxLayout();
    m_addButton = new QPushButton(QStringLiteral("Hinzufügen…"), this);
    m_editButton = new QPushButton(QStringLiteral("Bearbeiten…"), this);
    m_deleteButton = new QPushButton(QStringLiteral("Löschen"), this);
    row->addWidget(m_addButton);
    row->addWidget(m_editButton);
    row->addWidget(m_deleteButton);
    row->addStretch();
    root->addLayout(row);

    auto *hint = new QLabel(
        QStringLiteral("Termine erscheinen in der Tages- und Monatsübersicht. "
                       "Sie zählen nicht zur Arbeitszeit."),
        this);
    hint->setWordWrap(true);
    root->addWidget(hint);

    auto *buttons = new QDialogButtonBox(QDialogButtonBox::Close, this);
    if (auto *close = buttons->button(QDialogButtonBox::Close)) {
        close->setText(QStringLiteral("Schließen"));
        close->setAutoDefault(false);
        close->setDefault(true);
    }
    root->addWidget(buttons);

    connect(m_list, &QListWidget::itemSelectionChanged, this, &TermineDialog::updateButtons);
    connect(m_list, &QListWidget::itemDoubleClicked, this, [this]() { editAppointment(); });
    connect(m_addButton, &QPushButton::clicked, this, &TermineDialog::addAppointment);
    connect(m_editButton, &QPushButton::clicked, this, &TermineDialog::editAppointment);
    connect(m_deleteButton, &QPushButton::clicked, this, &TermineDialog::deleteAppointment);
    connect(buttons, &QDialogButtonBox::rejected, this, &QDialog::reject);
}

void TermineDialog::refreshList()
{
    const QString current = selectedId();
    QSignalBlocker blocker(m_list);
    m_list->clear();

    const auto items = AppointmentCatalog::instance().all();
    int select = -1;
    for (int i = 0; i < items.size(); ++i) {
        auto *item = new QListWidgetItem(items[i].summary(), m_list);
        item->setData(Qt::UserRole, items[i].id);
        if (items[i].id == current) {
            select = i;
        }
    }
    if (select >= 0) {
        m_list->setCurrentRow(select);
    }
    updateButtons();
}

void TermineDialog::updateButtons()
{
    const bool has = !selectedId().isEmpty();
    m_editButton->setEnabled(has);
    m_deleteButton->setEnabled(has);
}

QString TermineDialog::selectedId() const
{
    const auto *item = m_list->currentItem();
    if (!item) {
        return {};
    }
    return item->data(Qt::UserRole).toString();
}

void TermineDialog::addAppointment()
{
    TerminEditDialog::runNew(this);
}

void TermineDialog::editAppointment()
{
    const QString id = selectedId();
    if (id.isEmpty()) {
        return;
    }
    const Appointment apt = AppointmentCatalog::instance().byId(id);
    if (apt.id.isEmpty()) {
        return;
    }
    TerminEditDialog::runEdit(apt, this);
}

void TermineDialog::deleteAppointment()
{
    const QString id = selectedId();
    if (id.isEmpty()) {
        return;
    }
    const Appointment apt = AppointmentCatalog::instance().byId(id);
    QMessageBox box(this);
    box.setIcon(QMessageBox::Question);
    box.setWindowTitle(QStringLiteral("Termin löschen"));
    box.setText(QStringLiteral("Den Termin „%1“ löschen?").arg(apt.title));
    box.setStandardButtons(QMessageBox::Yes | QMessageBox::No);
    box.setDefaultButton(QMessageBox::No);
    box.button(QMessageBox::Yes)->setText(QStringLiteral("Ja"));
    box.button(QMessageBox::No)->setText(QStringLiteral("Nein"));
    if (box.exec() != QMessageBox::Yes) {
        return;
    }
    AppointmentCatalog::instance().remove(id);
}
