# Journal

Persönliches Desktop-Programm zur **Erfassung und Dokumentation von Arbeitszeit** nach den Vorgaben des deutschen Arbeitszeitgesetzes (ArbZG).

Die Oberfläche ist ausschließlich deutsch. Es gibt **kein Login** und **keinen Server**: alle Daten liegen lokal als JSON.

## Zwei Versionen

Dieselbe Anwendung existiert in zwei parallelen Implementierungen. Beide nutzen dasselbe Datenformat und können denselben Datenordner verwenden.

| Version | Technik | Plattform | Quellcode |
|---------|---------|-----------|-----------|
| **Qt** | Qt 6 Widgets, C++20 | Windows, Linux, macOS | `src/` |
| **Delphi** | VCL, Object Pascal | Windows | `Delphi/` |

Die fachliche Spezifikation steht in [Anforderungen/Anforderungen.md](Anforderungen/Anforderungen.md). Änderungen an der Qt-Oberfläche sollten in der Delphi-Variante nachgezogen werden (und umgekehrt).

## Funktionen

- **Soll-Arbeitszeit** regelmäßig (Wochenstunden / Arbeitstage) oder individuell je Wochentag
- **Arbeitspakete** mit Titel, Farbe und optionalen Details; mehrere Pakete gleichzeitig, auch überlappend
- **Aktive Pakete** am laufenden Tag (Ende = aktuelle Uhrzeit, etwa einmal pro Minute gespeichert)
- **Pausen** nach ArbZG §4 (automatischer Abzug ab 6 bzw. 9 Stunden) plus manuelle Pausen und Vorlagen
- **Überstundenkonto** mit Fortschreibung und optionaler Kappung (monatlich oder quartalsweise)
- **Urlaub und Krankheit** (auch halbe Tage), Urlaubskonto mit geplant/genommen
- **Feiertage und Schulferien** per Download für das konfigurierte Bundesland
- **ArbZG-Hinweise** (Pause, Höchstarbeitszeit, Ruhezeit, Sonn-/Feiertag, Nachtarbeit) und Arbeitszeitnachweis als HTML
- **Übersichten** gleichzeitig: Monat, Jahr, Tagesleiste, Arbeitspaketdiagramm, Trend des Stundenkontos

Erfasst wird die tatsächliche Arbeitszeit vollständig. Auf Soll, Ist und Saldo zählen nur Zeiten **innerhalb der Tagesgrenzen** (Vorgabe 06:00–20:00, global und pro Tag änderbar).

## Daten

Standardordner unter Windows: `%APPDATA%\Journal`. Der Speicherort ist über **Datei → Datenordner wählen…** frei wählbar.

| Inhalt | Pfad |
|--------|------|
| Monat (Pakete, Pausen, Abwesenheiten) | `{Datenordner}/monate/{Jahr}-{Monat}.json` |
| Jahressummen und Fortschreibung | `{Datenordner}/jahre/{Jahr}.json` |
| Feiertage / Schulferien | `{Datenordner}/kalender/` |

## Repository

```
Journal/
  src/                  Qt-Quellcode (C++)
  Delphi/               Delphi-VCL-Projekt
  Anforderungen/        Fachliche Spezifikation
  CMakeLists.txt        Qt-Build
```

## Bauen

### Qt

Voraussetzungen: CMake ≥ 3.21, Qt 6 (Widgets, Network), C++20-Compiler.

```bash
cmake -S . -B build
cmake --build build
```

Unter Windows typischerweise über Qt Creator mit Kit **Desktop Qt 6** und Generator Ninja/MSVC.

### Delphi

Voraussetzungen: RAD Studio (VCL), Projekt `Delphi/Journal.dproj`.

In der IDE öffnen und bauen, oder per Kommandozeile (Pfad zur Studio-Version anpassen):

```bat
call "D:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat"
msbuild Delphi\Journal.dproj /t:Build /p:Config=Debug /p:Platform=Win32
```

Die EXE liegt danach unter `Delphi\Win32\Debug\Journal.exe` (bzw. `Release`).
