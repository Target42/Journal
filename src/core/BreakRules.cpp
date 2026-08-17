#include "BreakRules.h"

namespace {
int requiredPauseMinutes(int creditedWorkMinutes)
{
    if (creditedWorkMinutes > kNineHourThresholdMinutes) {
        return kPauseAfterNineHoursMinutes;
    }
    if (creditedWorkMinutes > kSixHourThresholdMinutes) {
        return kPauseAfterSixHoursMinutes;
    }
    return 0;
}

int qualifyingPauseMinutes(const QVector<char> &covered)
{
    int rawWork = 0;
    int gapRun = 0;
    int pause = 0;

    auto flushGap = [&]() {
        if (gapRun >= kMinQualifyingPauseSegmentMinutes
            && rawWork > kMinWorkBeforeQualifyingPauseMinutes) {
            pause += gapRun;
        }
        gapRun = 0;
    };

    for (char flag : covered) {
        if (flag) {
            flushGap();
            ++rawWork;
        } else if (rawWork > kMinWorkBeforeQualifyingPauseMinutes) {
            ++gapRun;
        }
    }
    return pause;
}
} // namespace

BreakAdjustment applyAutomaticBreaks(const QVector<char> &covered)
{
    BreakAdjustment result;
    const int n = covered.size();
    result.credited.fill(0, n);
    result.autoPause.fill(0, n);

    int credited = 0;
    int pauseAccrued = qualifyingPauseMinutes(covered);

    for (int i = 0; i < n; ++i) {
        if (!covered[i]) {
            continue;
        }

        ++result.rawWorkMinutes;
        const int needed = requiredPauseMinutes(credited + 1);
        if (pauseAccrued < needed) {
            ++pauseAccrued;
            result.autoPause[i] = 1;
        } else {
            ++credited;
            result.credited[i] = 1;
        }
    }

    result.creditedMinutes = credited;
    result.autoPauseMinutes = result.rawWorkMinutes - credited;
    return result;
}
