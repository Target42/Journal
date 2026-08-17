#pragma once

#include <QVector>

inline constexpr int kSixHourThresholdMinutes = 6 * 60;
inline constexpr int kNineHourThresholdMinutes = 9 * 60;
inline constexpr int kPauseAfterSixHoursMinutes = 30;
inline constexpr int kPauseAfterNineHoursMinutes = 45;
inline constexpr int kMinWorkBeforeQualifyingPauseMinutes = 15;
inline constexpr int kMinQualifyingPauseSegmentMinutes = 15;

struct PauseInterval {
    int startMinute = 0;
    int endMinute = 0;

    bool isValid() const { return endMinute > startMinute; }
};

struct BreakAdjustment {
    int rawWorkMinutes = 0;
    int creditedMinutes = 0;
    int autoPauseMinutes = 0;
    QVector<char> credited;
    QVector<char> autoPause;
};

/** Wendet ArbZG §4 auf die Minutenbelegung eines Tages an (Union der Arbeitspakete). */
BreakAdjustment applyAutomaticBreaks(const QVector<char> &covered);
