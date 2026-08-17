#pragma once

#include <QString>

enum class AbsenceType {
    None,
    Vacation,
    Sick
};

struct Absence {
    AbsenceType type = AbsenceType::None;
    double fraction = 1.0;

    bool isSet() const { return type != AbsenceType::None && fraction > 0.005; }

    bool isHalfDay() const { return isSet() && fraction < 0.999; }

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
        return {};
    }

    QString typeString() const
    {
        switch (type) {
        case AbsenceType::Vacation:
            return QStringLiteral("vacation");
        case AbsenceType::Sick:
            return QStringLiteral("sick");
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
