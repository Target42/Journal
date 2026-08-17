#include "TitlesDialog.h"

#include "core/JournalStore.h"
#include "core/TitleCatalog.h"

#include <QAbstractButton>
#include <QAbstractItemView>
#include <QColorDialog>
#include <QComboBox>
#include <QDialogButtonBox>
#include <QFormLayout>
#include <QHBoxLayout>
#include <QIcon>
#include <QLabel>
#include <QLineEdit>
#include <QListWidget>
#include <QMessageBox>
#include <QPixmap>
#include <QPushButton>
#include <QVBoxLayout>

namespace {
QIcon colorIcon(const QColor &color)
{
    QPixmap pixmap(12, 12);
    pixmap.fill(color.isValid() ? color : QColor(120, 120, 120));
    return QIcon(pixmap);
}

void updateColorButton(QPushButton *button, const QColor &color)
{
    button->setStyleSheet(
        QStringLiteral("QPushButton { background-color: %1; border: 1px solid #666; }")
            .arg(color.name(QColor::HexRgb)));
}
} // namespace

TitlesDialog::TitlesDialog(QWidget *parent)
    : QDialog(parent)
{
    setWindowTitle(QStringLiteral("Titel"));
    setModal(true);
    setMinimumWidth(460);
    setMinimumHeight(360);
    setupUi();
    refreshList();
    connect(&TitleCatalog::instance(), &TitleCatalog::changed,
            this, &TitlesDialog::refreshList);
}

void TitlesDialog::setupUi()
{
    auto *root = new QVBoxLayout(this);

    m_list = new QListWidget(this);
    m_list->setSelectionMode(QAbstractItemView::SingleSelection);
    m_list->setAlternatingRowColors(false);
    root->addWidget(m_list, 1);

    auto *row = new QHBoxLayout();
    m_addButton = new QPushButton(QStringLiteral("Hinzufügen…"), this);
    m_replaceButton = new QPushButton(QStringLiteral("Ersetzen…"), this);
    row->addWidget(m_addButton);
    row->addWidget(m_replaceButton);
    row->addStretch();
    root->addLayout(row);

    auto *hint = new QLabel(
        QStringLiteral("Titel entstehen automatisch beim Anlegen eines Arbeitspakets. "
                       "Über „Hinzufügen“ kannst du Titel ohne Paket ergänzen. "
                       "„Ersetzen“ benennt alle Arbeitspakete um; der bisherige Titel "
                       "entfällt aus der Liste."),
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

    connect(m_list, &QListWidget::itemSelectionChanged,
            this, &TitlesDialog::updateButtons);
    connect(m_list, &QListWidget::itemDoubleClicked, this, [this]() { replaceTitle(); });
    connect(m_addButton, &QPushButton::clicked, this, &TitlesDialog::addTitle);
    connect(m_replaceButton, &QPushButton::clicked, this, &TitlesDialog::replaceTitle);
    connect(buttons, &QDialogButtonBox::rejected, this, &QDialog::reject);
}

void TitlesDialog::refreshList()
{
    const QString current = selectedTitle();
    QSignalBlocker blocker(m_list);
    m_list->clear();

    const auto titles = TitleCatalog::instance().titles();
    int select = -1;
    for (int i = 0; i < titles.size(); ++i) {
        auto *item = new QListWidgetItem(colorIcon(titles[i].color), titles[i].title, m_list);
        item->setData(Qt::UserRole, titles[i].title);
        if (!current.isEmpty()
            && titles[i].title.compare(current, Qt::CaseInsensitive) == 0) {
            select = i;
        }
    }

    if (select >= 0) {
        m_list->setCurrentRow(select);
    }
    updateButtons();
}

void TitlesDialog::updateButtons()
{
    m_replaceButton->setEnabled(!selectedTitle().isEmpty());
}

QString TitlesDialog::selectedTitle() const
{
    const auto *item = m_list->currentItem();
    if (!item) {
        return {};
    }
    return item->data(Qt::UserRole).toString();
}

void TitlesDialog::addTitle()
{
    QDialog dialog(this);
    dialog.setWindowTitle(QStringLiteral("Titel hinzufügen"));
    dialog.setModal(true);
    dialog.setMinimumWidth(360);

    auto *form = new QFormLayout();
    auto *titleEdit = new QLineEdit(&dialog);
    titleEdit->setPlaceholderText(QStringLiteral("Neuer Titel"));

    QColor color = TitleCatalog::instance().nextUnusedColor();
    auto *colorButton = new QPushButton(&dialog);
    colorButton->setFixedSize(40, 24);
    colorButton->setToolTip(QStringLiteral("Farbe für diesen Titel"));
    colorButton->setFocusPolicy(Qt::NoFocus);
    updateColorButton(colorButton, color);

    form->addRow(QStringLiteral("Titel:"), titleEdit);
    form->addRow(QStringLiteral("Farbe:"), colorButton);

    auto *root = new QVBoxLayout(&dialog);
    root->addLayout(form);

    auto *buttons = new QDialogButtonBox(QDialogButtonBox::Ok | QDialogButtonBox::Cancel, &dialog);
    if (auto *ok = buttons->button(QDialogButtonBox::Ok)) {
        ok->setText(QStringLiteral("Hinzufügen"));
        ok->setDefault(true);
    }
    if (auto *cancel = buttons->button(QDialogButtonBox::Cancel)) {
        cancel->setText(QStringLiteral("Abbrechen"));
    }
    root->addWidget(buttons);

    connect(colorButton, &QPushButton::clicked, &dialog, [&]() {
        const QColor chosen = QColorDialog::getColor(
            color, &dialog, QStringLiteral("Farbe für den Titel"));
        if (!chosen.isValid()) {
            return;
        }
        color = chosen;
        updateColorButton(colorButton, color);
    });
    connect(buttons, &QDialogButtonBox::accepted, &dialog, &QDialog::accept);
    connect(buttons, &QDialogButtonBox::rejected, &dialog, &QDialog::reject);

    titleEdit->setFocus();
    if (dialog.exec() != QDialog::Accepted) {
        return;
    }

    const QString title = titleEdit->text().trimmed();
    if (title.isEmpty()) {
        QMessageBox::warning(this, windowTitle(),
                             QStringLiteral("Bitte einen Titel eingeben."));
        return;
    }
    if (TitleCatalog::instance().contains(title)) {
        QMessageBox::warning(
            this, windowTitle(),
            QStringLiteral("Der Titel „%1“ ist bereits in der Liste.")
                .arg(TitleCatalog::instance().canonicalTitle(title)));
        return;
    }

    TitleCatalog::instance().upsert(title, color);
    refreshList();
    const auto matches = m_list->findItems(TitleCatalog::instance().canonicalTitle(title),
                                           Qt::MatchFixedString);
    if (!matches.isEmpty()) {
        m_list->setCurrentItem(matches.first());
    }
}

void TitlesDialog::replaceTitle()
{
    const QString from = selectedTitle();
    if (from.isEmpty()) {
        return;
    }

    QDialog dialog(this);
    dialog.setWindowTitle(QStringLiteral("Titel ersetzen"));
    dialog.setModal(true);
    dialog.setMinimumWidth(400);

    auto *form = new QFormLayout();
    auto *fromLabel = new QLabel(from, &dialog);

    auto *toCombo = new QComboBox(&dialog);
    toCombo->setEditable(true);
    toCombo->setInsertPolicy(QComboBox::NoInsert);
    toCombo->setSizePolicy(QSizePolicy::Expanding, QSizePolicy::Fixed);
    toCombo->lineEdit()->setPlaceholderText(
        QStringLiteral("Neuer Titel oder bestehenden wählen"));

    const auto titles = TitleCatalog::instance().titles();
    for (const auto &entry : titles) {
        toCombo->addItem(colorIcon(entry.color), entry.title);
    }
    toCombo->setCurrentIndex(-1);
    toCombo->setEditText(QString());

    form->addRow(QStringLiteral("Bisher:"), fromLabel);
    form->addRow(QStringLiteral("Ersetzen durch:"), toCombo);

    auto *hint = new QLabel(
        QStringLiteral("Alle Arbeitspakete mit dem bisherigen Titel werden umbenannt. "
                       "Der bisherige Titel entfällt aus der Liste."),
        &dialog);
    hint->setWordWrap(true);

    auto *root = new QVBoxLayout(&dialog);
    root->addLayout(form);
    root->addWidget(hint);

    auto *buttons = new QDialogButtonBox(QDialogButtonBox::Ok | QDialogButtonBox::Cancel, &dialog);
    if (auto *ok = buttons->button(QDialogButtonBox::Ok)) {
        ok->setText(QStringLiteral("Ersetzen"));
        ok->setDefault(true);
    }
    if (auto *cancel = buttons->button(QDialogButtonBox::Cancel)) {
        cancel->setText(QStringLiteral("Abbrechen"));
    }
    root->addWidget(buttons);

    connect(buttons, &QDialogButtonBox::accepted, &dialog, &QDialog::accept);
    connect(buttons, &QDialogButtonBox::rejected, &dialog, &QDialog::reject);

    toCombo->setFocus();
    if (dialog.exec() != QDialog::Accepted) {
        return;
    }

    const QString typed = toCombo->currentText().trimmed();
    if (typed.isEmpty()) {
        QMessageBox::warning(this, windowTitle(),
                             QStringLiteral("Bitte einen neuen Titel eingeben oder auswählen."));
        return;
    }

    auto &catalog = TitleCatalog::instance();
    const bool mergesIntoOther =
        catalog.contains(typed) && catalog.canonicalTitle(typed) != from;
    const QString canonicalTo = mergesIntoOther ? catalog.canonicalTitle(typed) : typed;
    if (canonicalTo == from) {
        return;
    }

    QMessageBox box(this);
    box.setIcon(QMessageBox::Question);
    box.setWindowTitle(QStringLiteral("Titel ersetzen"));
    box.setText(QStringLiteral("Alle Arbeitspakete mit dem Titel „%1“ in „%2“ umbenennen?\n"
                               "Der bisherige Titel entfällt aus der Liste.")
                    .arg(from, canonicalTo));
    box.setStandardButtons(QMessageBox::Yes | QMessageBox::No);
    box.setDefaultButton(QMessageBox::No);
    box.button(QMessageBox::Yes)->setText(QStringLiteral("Ja"));
    box.button(QMessageBox::No)->setText(QStringLiteral("Nein"));
    if (box.exec() != QMessageBox::Yes) {
        return;
    }

    const QColor keepColor =
        mergesIntoOther ? catalog.colorFor(canonicalTo) : catalog.colorFor(from);

    QString error;
    if (!JournalStore::instance().renameTitle(from, canonicalTo, &error)) {
        QMessageBox::warning(
            this, windowTitle(),
            error.isEmpty() ? QStringLiteral("Die Arbeitspakete konnten nicht umbenannt werden.")
                            : error);
        return;
    }
    if (!catalog.rename(from, canonicalTo)) {
        catalog.upsert(canonicalTo, keepColor);
    }

    refreshList();
    const auto matches = m_list->findItems(canonicalTo, Qt::MatchFixedString);
    if (!matches.isEmpty()) {
        m_list->setCurrentItem(matches.first());
    }
}
