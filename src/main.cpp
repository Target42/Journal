#include "MainWindow.h"

#include <QApplication>
#include <QLocale>

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    QApplication::setApplicationName(QStringLiteral("Journal"));
    QApplication::setApplicationVersion(QStringLiteral("0.1.0"));
    QApplication::setOrganizationName(QStringLiteral("Journal"));

    QLocale::setDefault(QLocale(QLocale::German, QLocale::Germany));

    MainWindow window;
    window.show();

    return app.exec();
}
