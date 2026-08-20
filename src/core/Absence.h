#pragma once

#include <QString>

enum class AbsenceType {
    None,
    Vacation,
    Sick,
    PaidLeave,
    Compensatory
};

struct Absence {
    AbsenceType type = AbsenceType::None;
    double fraction = 1.0;

    bool isSet() const { return type != AbsenceType::None && fraction > 0.005; }

    bool isHalfDay() const { return isSet() && fraction < 0.999; }

    bool fillsToTarget() const
    {
        return isSet()
            && (type == AbsenceType::Vacation || type == AbsenceType::Sick
                || type == AbsenceType::PaidLeave);
    }

    QString label() const
    {
        if (!isSet()) {
            return {};
        }
        const bool half = isHalfDay();
        if (type == AbsenceType::Vacation) {
            return half ? QStringLiteral("Urlaub (½)") : QStringLiteral("Urlaub");
        }
        if (type == AbsenceType::Sick) {
            return half ? QStringLiteral("Krankheit (½)") : QStringLiteral("Krankheit");
        }
        if (type == AbsenceType::PaidLeave) {
            return half ? QStringLiteral("Bezahlt frei (½)") : QStringLiteral("Bezahlt frei");
        }
        if (type == AbsenceType::Compensatory) {
            return half ? QStringLiteral("Zeitausgleich (½)") : QStringLiteral("Zeitausgleich");
        }
        return {};
    }

    QString typeString() const
    {
        switch (type) {
        case AbsenceType::Vacation:
            return QStringLiteral("vacation");
        case AbsenceType::Sick:
            return QStringLiteral("sick");
        case AbsenceType::PaidLeave:
            return QStringLiteral("paid");
        case AbsenceType::Compensatory:
            return QStringLiteral("compensatory");
        case AbsenceType::None:
            break;
        }
        return {};
    }

    static Absence fromJson(const QString &type, double fraction)
    {
        Absence absence;
        if (type == QLatin1String("vacation")) {
            absence.type = AbsenceType::Vacation;
        } else if (type == QLatin1String("sick")) {
            absence.type = AbsenceType::Sick;
        } else if (type == QLatin1String("paid")) {
            absence.type = AbsenceType::PaidLeave;
        } else if (type == QLatin1String("compensatory")) {
            absence.type = AbsenceType::Compensatory;
        } else {
            return {};
        }
        if (fraction >= 0.999) {
            absence.fraction = 1.0;
        } else if (fraction > 0.005) {
            absence.fraction = 0.5;
        } else {
            return {};
        }
        return absence;
    }
};
