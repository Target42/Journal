cmake_minimum_required(VERSION 3.21)

project(Journal VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt6 REQUIRED COMPONENTS Widgets Network)

qt_standard_project_setup()

qt_add_executable(Journal
    src/main.cpp
    src/MainWindow.h
    src/MainWindow.cpp
    src/views/MonthView.h
    src/views/MonthView.cpp
    src/views/DayView.h
    src/views/DayView.cpp
    src/views/YearView.h
    src/views/YearView.cpp
    src/views/PackageChartView.h
    src/views/PackageChartView.cpp
    src/views/AccountTrendView.h
    src/views/AccountTrendView.cpp
    src/core/Absence.h
    src/core/BreakRules.h
    src/core/BreakRules.cpp
    src/core/AppSettings.h
    src/core/AppSettings.cpp
    src/core/WorkPackage.h
    src/core/TitleCatalog.h
    src/core/TitleCatalog.cpp
    src/core/JournalStore.h
    src/core/JournalStore.cpp
    src/core/TimeTotals.h
    src/core/TimeTotals.cpp
    src/core/CalendarService.h
    src/core/CalendarService.cpp
    src/core/RetirementCalculator.h
    src/core/RetirementCalculator.cpp
    src/core/ArbzgRules.h
    src/core/ArbzgRules.cpp
    src/dialogs/AbsenceDialog.h
    src/dialogs/AbsenceDialog.cpp
    src/dialogs/DayBoundsDialog.h
    src/dialogs/DayBoundsDialog.cpp
    src/dialogs/DayPackagesDialog.h
    src/dialogs/DayPackagesDialog.cpp
    src/dialogs/SettingsDialog.h
    src/dialogs/SettingsDialog.cpp
    src/dialogs/RetirementDialog.h
    src/dialogs/RetirementDialog.cpp
    src/dialogs/ArbzgDialog.h
    src/dialogs/ArbzgDialog.cpp
    src/dialogs/TitlesDialog.h
    src/dialogs/TitlesDialog.cpp
    src/dialogs/WorkPackageDialog.h
    src/dialogs/WorkPackageDialog.cpp
    src/dialogs/PauseDialog.h
    src/dialogs/PauseDialog.cpp
)

target_include_directories(Journal PRIVATE src)

target_link_libraries(Journal PRIVATE
    Qt6::Widgets
    Qt6::Network
)

set_target_properties(Journal PROPERTIES
    WIN32_EXECUTABLE TRUE
    MACOSX_BUNDLE TRUE
)

install(TARGETS Journal
    BUNDLE DESTINATION .
    RUNTIME DESTINATION bin
)
