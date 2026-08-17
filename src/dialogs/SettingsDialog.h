#pragma once

#include "core/WorkPackage.h"

#include <QDialog>
#include <array>

class QCheckBox;
class QComboBox;
class QDoubleSpinBox;
class QLabel;
class QLineEdit;
class QRadioButton;
class QTimeEdit;
class QWidget;

class SettingsDialog : public QDialog
{
    Q_OBJECT

public:
    explicit SettingsDialog(QWidget *parent = nullptr);

private:
    void setupUi();
    void loadFromSettings();
    void saveToSettings();
    void updateModeUi();
    void updateEvenPreview();
    void updateOvertimeUi();
    void applyEvenHoursToWorkDays();
    int selectedWorkDayCount() const;
    double evenHoursPerDay() const;

    void accept() override;

    QComboBox *m_stateCombo = nullptr;
    QDoubleSpinBox *m_vacationSpin = nullptr;
    std::array<QCheckBox *, 7> m_workDayChecks {};
    QRadioButton *m_evenRadio = nullptr;
    QRadioButton *m_individualRadio = nullptr;
    QDoubleSpinBox *m_weeklyHoursSpin = nullptr;
    QLabel *m_evenPreviewLabel = nullptr;
    QWidget *m_evenPane = nullptr;
    QWidget *m_individualPane = nullptr;
    std::array<QDoubleSpinBox *, 7> m_dayHoursSpins {};
    QTimeEdit *m_dayStartEdit = nullptr;
    QTimeEdit *m_dayEndEdit = nullptr;
    std::array<QLineEdit *, kPausePresetCount> m_pauseNameEdits {};
    std::array<QTimeEdit *, kPausePresetCount> m_pauseStartEdits {};
    std::array<QTimeEdit *, kPausePresetCount> m_pauseEndEdits {};

    QCheckBox *m_overtimeLimitsCheck = nullptr;
    QComboBox *m_overtimePeriodCombo = nullptr;
    QDoubleSpinBox *m_overtimeMinSpin = nullptr;
    QDoubleSpinBox *m_overtimeMaxSpin = nullptr;
    QWidget *m_overtimeLimitsPane = nullptr;
};
