# Journal

Persönliches Tool zur Erfassung und Dokumentation von Arbeitszeit nach den deutschen gesetzlichen Vorgaben (ArbZG).

## Zielplattform

- **Technologie:** Qt Widgets (C++)
- **Plattformen:** Windows, Linux, macOS
- **UI-Sprache:** ausschließlich Deutsch

---

# Arbeitszeit

## Soll-Arbeitszeit

Die Soll-Zeit kann auf zwei Arten definiert werden:

1. **Regelmäßig:** Wochenstunden geteilt durch die Anzahl der Arbeitstage  
   (Beispiel: 40 h / 5 Tage = 8 h pro Arbeitstag).
2. **Individuell:** feste Soll-Stunden je Wochentag  
   (Beispiel: Montag 9 h, Dienstag 7 h).

**Arbeitstage:**

- Standardmäßig sind **Samstag und Sonntag frei**.
- Jeder Wochentag (Mo–So) kann als Arbeitstag **aktiviert** oder deaktiviert werden.
- Werktage können ausgenommen werden (z. B. klassische 5-Tage-Woche Mo–Fr).

Es wird immer mit **Industrieminuten** gerechnet (Dezimalstunden, z. B. 8,50 h = 8 h 30 min).  
Erfassung und Berechnung erfolgen **minutengenau**.

## Bundesland

Das Bundesland, in dem gearbeitet wird, ist konfigurierbar (z. B. `NI` = Niedersachsen).  
Es steuert den Abruf von Feiertagen und Schulferien.

## Überstundenkonto

Mehr-/Minderstunden werden über Monate fortgeschrieben (Vormonats-Saldo fließt in den aktuellen Monat ein).

Zum **Ende einer Periode** wird der Kontostand auf konfigurierbare Grenzen **gekürzt** (abgeschnitten). Alles oberhalb der Obergrenze bzw. unterhalb der Untergrenze wird nicht fortgeschrieben.

**Einstellungen** (unter Einstellungen → Überstundenkonto):

- **Grenzen anwenden:** ja/nein.
- **Periode:** **monatlich** oder **quartalsweise** (Kalenderquartale: Jan–Mär, Apr–Jun, Jul–Sep, Okt–Dez).
- **Untergrenze / Obergrenze** in Stunden, frei wählbar.  
  Vorgabe: **−20 h / +60 h**, Periode **quartalsweise**.

**Wirkung:**

- Innerhalb der laufenden Periode darf der Saldo die Grenzen überschreiten.
- Erst wenn die Periode **abgeschlossen** ist (letzter Tag der Periode liegt in der Vergangenheit), wird der Schluss-Saldo auf [Untergrenze, Obergrenze] begrenzt.
- Der **folgende** Monat bzw. das folgende Quartal startet mit diesem gekürzten Wert.
- Die tatsächlich geleisteten Stunden (Ist) und die Monatssumme Mehr-/Minderzeit bleiben unverändert; abgeschnitten wird nur die **Fortschreibung** (Konto).
- Abgeschnittene Stunden werden in der Monats- und Jahresübersicht ausgewiesen.

## Ferien (Schulferien)

Über die API  
`https://openholidaysapi.org/SchoolHolidays?countryIsoCode=DE&subdivisionCode=DE-{STATE}&languageIsoCode=DE&validFrom={year}-01-01&validTo={year}-12-31`  
können Schulferien als JSON geladen werden.

- Menü: **Datei → Ferien herunterladen…** (für das in der Jahresübersicht gewählte Jahr).
- Speicherung lokal unter `{Datenordner}/kalender/ferien_{STATE}_{Jahr}.json`.
- Beim Start werden vorhandene lokale Dateien geladen (kein automatischer Download).
- Leere API-Antworten werden als Fehler gemeldet (kein „Erfolg“ mit leerer Datei).
- Ferien werden **nur angezeigt** und haben **keinen Einfluss** auf Soll-Zeit, Ist-Zeit oder Saldo.

## Feiertage

Über  
`https://get.api-feiertage.de?years={year}&states={state}`  
können Feiertage für das gewählte Bundesland geladen werden.

- Menü: **Datei → Feiertage herunterladen…** (für das in der Jahresübersicht gewählte Jahr).
- Speicherung lokal unter `{Datenordner}/kalender/feiertage_{STATE}_{Jahr}.json`.
- Beim Start werden vorhandene lokale Dateien geladen (kein automatischer Download).
- An Feiertagen ist die **Soll-Arbeitszeit = 0**.
- Treffen Feiertag und Urlaub/Krankheit auf denselben Tag, **gewinnt der Feiertag** (keine doppelte Anrechnung als Urlaubstag o. Ä.).

## Erfassung vs. Anrechnung

- **Erfassung:** Alle Zeiten werden dokumentiert – auch außerhalb der Tagesgrenzen.  
  (Vollständige Dokumentation der tatsächlichen Arbeitszeit; keine Verfälschung durch Abschneiden.)
- **Anrechnung auf Soll/Ist/Saldo:** Nur Zeiten **innerhalb der definierten Tagesgrenzen** zählen.

Die Tagesgrenzen sind standardmäßig **06:00–20:00**, können aber global und **pro Tag abweichend** gesetzt werden.  
Zeiten vor oder nach den jeweils geltenden Grenzen zählen nicht zum Saldo.

---

# Pausen

Es gelten die gesetzlichen Pausenvorgaben (ArbZG §4), umgesetzt als automatische Zeitrechnung:

| Schwelle | Pause |
|----------|--------|
| Genau 6:00 Stunden Arbeitszeit | kein Pausenabzug |
| Mehr als 6 Stunden Arbeitszeit | mindestens 30 Minuten |
| Mehr als 9 Stunden Arbeitszeit | insgesamt mindestens 45 Minuten (+15 Minuten gegenüber der 6-Stunden-Regel) |

### Regeln im Programm

1. **Genau 6:00 Stunden:** kein Abzug. Die Zeit **darüber bis 6:30** wird als automatische Pause abgezogen (Ist bleibt 6:00). Danach zählt die Arbeitszeit wieder (abzüglich der 30 Minuten).

2. **Analog ab mehr als 9:00 Stunden** Arbeitszeit: weitere **15 Minuten** (Ist bleibt bei 9:00, bis die 15 Minuten Pause erfüllt sind).

3. **Echte Unterbrechung** zwischen Arbeitspaketen zählt als Pause, wenn sie **mindestens 15 Minuten** dauert und **nach mehr als 15 Minuten Arbeit** liegt (ArbZG: Teilabschnitte von mindestens 15 Minuten). Die Minuten werden auf 30 bzw. 45 Minuten Gesamtpause angerechnet – dann entfällt der automatische Abzug, soweit die Pause erfüllt ist. Lücken am Tagesanfang oder nach Feierabend zählen nicht.

4. Pausen werden in der Zeitrechnung (Ist/Saldo, Arbeitspaketdiagramm) berücksichtigt; die Roh-Erfassung der Intervalle bleibt erhalten. Automatisch abgezogene Minuten werden in der Tagesübersicht schraffiert dargestellt.

### Hinweise / Grenzen (Anzeige)

In der Tagesübersicht werden abhängig vom Arbeitsbeginn vertikale Linien bei **6 Stunden**, **8 Stunden**, **10 Stunden** und **12 Stunden** angezeigt.  
Eine harte Sperre der Zeiterfassung gibt es nicht – Erfassung bleibt möglich (Dokumentationspflicht).

### Pausen-Vorlagen

Unter **Einstellungen → Pausen** können bis zu **drei benannte Pausenfenster** festgelegt werden (Vorgabe: **Frühstück 9:00–9:15**, **Mittag 11:30–12:00**). Leerer Name = ungenutzt. Die Fenster dürfen sich nicht überlappen.

- In der **Tagesübersicht** erscheinen die Vorlagen als gelbe Markierung und als Häkchen neben dem Pause-Button.
- Ein Häkchen fügt die Pause genau in diesem Zeitraum ein bzw. entfernt die **überdeckende** Pause wieder. Manuelles Einfügen und Bearbeiten über den Pause-Dialog bleibt unverändert.
- Das Häkchen ist gesetzt, wenn eine Pause das Vorlagenfenster **vollständig überdeckt** (Pause beginnt nicht später und endet nicht früher). Verschobene Zeiten (z. B. 11:32–12:05) gelten nicht als diese Vorlage.
- In der Paketliste und auf dem Pausenstreifen erscheint der Vorlagenname, wenn die Pause das Fenster überdeckt.
- Der Hinweis „übliche Pause verpasst“ gilt **je Vorlage**, aber **nur wenn die gesetzliche Pause (§4) noch nicht erfüllt ist**: Arbeit begann vor dem Fenster, um dessen Beginn wird noch gearbeitet, und es startet dort keine Pause bzw. keine Pause überdeckt das Fenster. Ist die 30- bzw. 45-Minuten-Pause bereits genommen (und keine ununterbrochene Arbeit über 6 Stunden), bleibt der Hinweis aus – auch wenn z. B. die Frühstücksvorlage ungenutzt bleibt.

---

# ArbZG (Hinweise)

Journal prüft die erfasste **Rohzeit** gegen das Arbeitszeitgesetz. Das Überstundenkonto bleibt unverändert (Netto innerhalb der Tagesgrenzen, inkl. automatischem Pausenabzug).

**Getrennte Rechnungen:**

- **Konto / Ist:** Zeiten innerhalb der Tagesgrenzen, abzüglich automatischer Pause.
- **ArbZG:** alle erfassten Minuten des Kalendertags, Pausen nur als echte Lücken zwischen Arbeitspaketen (mindestens 15 Minuten, nach mehr als 15 Minuten Arbeit).

**Prüfungen** (Anzeige, keine Sperre):

| Thema | Regel |
|-------|--------|
| Pause §4 | 30 Min. bei mehr als 6 h, 45 Min. bei mehr als 9 h; nicht länger als 6 h ununterbrochen |
| Höchstarbeitszeit §3 | Höchstens 10 h je Kalendertag (täglicher Hinweis). 8 h je Werktag (Mo–Sa) ist der Durchschnitt: Ausgleich Ø 8 h in 6 Kalendermonaten oder 24 Wochen, gezählt in **Datei → ArbZG…**, kein täglicher Hinweis bei mehr als 8 h |
| Ruhezeit §5 | 11 Stunden zwischen letztem Ende und nächstem Beginn |
| Sonn-/Feiertag §9 / §11 | Arbeit kennzeichnen; Ersatzruhe (So: 2 Wochen, Feiertag: 8 Wochen); mindestens 15 freie Sonntage im Jahr |
| Nachtarbeit §6 | 23:00–6:00; mehr als 2 Stunden = Nachtarbeit; ab 48 Tagen im Jahr Nachtarbeitnehmer |

Menü: **Datei → ArbZG…** (Übersicht und **Arbeitszeitnachweis** als HTML: Beginn, Ende, Pausenlage, Dauer).

---

# Arbeitspakete

Ziel ist, die Arbeitszeit zu erfassen und auf Arbeitspakete zu verteilen.

## Eigenschaften

- Jedes Arbeitspaket hat einen **Titel**, eine **Farbe** und optional **Detailinformationen**.
- Arbeitspakete dürfen sich **überlappen**, dürfen aber **nicht in derselben Minute beginnen**.
- Sortierung (u. a. für „oberstes“ Paket): nach **Startzeit**.

## Aktive Pakete

Am aktuellen Arbeitstag können **ein oder mehrere** Arbeitspakete als aktiv gekennzeichnet sein.  
Solange ein Paket aktiv ist, ist sein Ende immer die **aktuelle Uhrzeit**, bis die Kennzeichnung aufgehoben wird.

## Titel-Liste

- Das Programm führt automatisch eine Liste verwendeter Titel zur Auswahl.
- Die Liste kann manuell ergänzt werden.
- Ein Titel kann **global** durch einen anderen ersetzt werden; der ursprüngliche Titel entfällt dann aus der Liste.

## Überlappung in Auswertungen

Bei überlappenden Arbeitspaketen zählt die Zeit in Diagrammen immer für das **oberste** Paket (maßgeblich: spätere bzw. gemäß Sortierung nach Startzeit oberste Lage – siehe Sortierung nach Startzeit).

## Krankheit und Urlaub

- Bei **Krankheit** oder **Urlaub** wird die **tägliche Soll-Arbeitszeit** angenommen.
- Es entsteht **keine** Mehr- oder Minderzeit.
- **Halbe Tage** sind möglich.
- Krankheit und Urlaub sind eigene Status (getrennt voneinander).
- **Urlaubskonto:** Jahresanspruch ist konfigurierbar (z. B. 30 Tage).
- **Geplant** = Urlaubstag in der Zukunft; **genommen** = Urlaubstag in der Vergangenheit.

## Heiligabend und Silvester

Der **24.12.** (Heiligabend) und der **31.12.** (Silvester) sind in den meisten Bundesländern **keine** gesetzlichen Feiertage. Weihnachten (25./26.12.) bleibt Feiertag (Soll = 0).

Unter **Einstellungen → Urlaub** gilt für beide Tage dieselbe Regel, sofern der Tag ein Arbeitstag und kein Feiertag ist:

| Einstellung | Soll | Urlaubskonto |
|-------------|------|----------------|
| **Normaler Arbeitstag** (Vorgabe) | wie an diesem Wochentag | keine automatische Anrechnung |
| **Jeweils ein Urlaubstag** | volle Tages-Sollzeit, Ist = Soll | 1 Tag je betroffenem Datum |
| **Jeweils ein halber Urlaubstag** | halber Tag wie bei manuellem halben Urlaub | ½ Tag je betroffenem Datum |
| **Vollständig frei ohne Arbeitspflicht** | 0 | kein Abzug |

Eine **manuell** gesetzte Abwesenheit (Urlaub/Krankheit) an diesem Tag hat Vorrang vor der automatischen Anrechnung. Fällt der Tag auf ein Wochenende bzw. einen arbeitsfreien Wochentag, ändert sich nichts.

---

# Termine

Journal ist kein Kalender. Termine und regelmäßige Meetings dienen nur der **Orientierung** (wie Schulferien): sichtbar, ohne Einfluss auf die Zeitrechnung.

Erfasste Arbeit bleibt bei den **Arbeitspaketen**. Ein bereits abgeleistetes Meeting wird weiterhin als Paket eingetragen. Termine zeigen die **Vorschau** (z. B. Stand-up, Jour fixe), auch an Tagen ohne erfasste Pakete.

## Eigenschaften

- Jeder Termin hat einen **Titel** sowie **Beginn** und **Ende** (Uhrzeit, minutengenau).
- **Einmalig:** gilt nur an einem Datum.
- **Wöchentlich:** gilt an ausgewählten Wochentagen (Mo–So, auch mehrere) zur gleichen Uhrzeit. Keine weiteren Rhythmen (kein 14-tägig, kein monatlich).
- Termine dürfen sich untereinander und mit Arbeitspaketen **überlappen**.

## Keine Zeitrechnung

Termine haben **keinen Einfluss** auf Soll, Ist, Saldo, Überstundenkonto, Pausenabzug oder ArbZG.  
Sie werden **nicht** automatisch als Arbeitspakete angelegt.

Es gibt **keinen** Import fremder Kalender (Outlook, Google o. Ä.), keine Einladungen und keine Erinnerungen.

## Verwaltung

Menü: **Datei → Termine…** (anlegen, bearbeiten, löschen).  
In der Tagesübersicht kann über das Kontextmenü ein **einmaliger** Termin an der geklickten Uhrzeit angelegt werden.

Speicherung lokal als JSON, **getrennt** von den Monatsdateien. Änderungen an Terminen lösen **keine** Neuberechnung von Monat oder Jahr aus.

---

# GUI

Die **Einstellungen** sind in **Registerkarten** gegliedert (Arbeitszeit, Urlaub, Konto, Tag), damit der Dialog nicht zu einer langen Liste wird.

Das **Hauptfenster** zeigt alle Bereiche **gleichzeitig** (keine Tabs):

| Bereich | Position |
|---------|----------|
| Monatsübersicht | links |
| Jahresübersicht + Arbeitspaketdiagramm + Konto-Trend | rechts (übereinander) |
| Tagesübersicht mit Arbeitspaketen | unten, volle Formularbreite, ca. **100 px** Höhe |

- Positive Zeiten: **grün**, negative: **rot**, **ohne Vorzeichen**.
- Tabellen: **keine Proportionalschrift** (Festbreitenschrift).

## Monat

Die Monatsübersicht zeigt **immer alle Tage** des gewählten Monats:

- zu arbeitende Stunden (Soll),
- Mehr-/Minderstunden aus dem Vormonat,
- Kontostand nach Fortschreibung (und ggf. abgeschnittene Stunden zum Periodenende),
- aktuell geleistete und geforderte Stunden,
- je Tag: Arbeitsbeginn und -ende, geleistete Stunden und resultierende Mehr-/Minderstunden.

**Doppelklick** auf einen Tag (oder Kontextmenü → Arbeitspakete…) öffnet ein Fenster mit allen Arbeitspaketen des Tages; dort können Pakete hinzugefügt, bearbeitet und gelöscht werden.

**Urlaub / Krankheit:** Schaltfläche in der Monatsübersicht, Menü **Datei → Urlaub / Krankheit…** oder Kontextmenü auf einem Tag (ganzer/halber Tag, bzw. **Zeitraum…** für mehrere Tage). Beim Setzen zählen nur Arbeitstage ohne Feiertag.

**Einfärbung:** Wochenenden, Feiertage und Schulferientage erhalten jeweils eine Hintergrundfarbe.  
Feiertags- und Feriennamen sowie **Termintitel** des Tages werden in der Hinweis-Spalte angezeigt.

Der angezeigte Monat folgt der Auswahl in der Jahresübersicht.

## Arbeitspaketdiagramm

Für den jeweiligen Monat: Diagramm der Arbeitszeiten je Arbeitspaket.  
Bei Überlappung zählt die Zeit für das oberste Paket (Sortierung nach Startzeit).

## Trend Stundenkonto

Aus den **letzten 30 Tagen, an denen tatsächlich gearbeitet wurde** (Tage mit erfasster Ist-Zeit; volle Urlaubs- und Krankheitstage zählen nicht):

- Kurve des **kumulierten Saldos** über diese Arbeitstage,
- **Ø je Arbeitstag** (Mehr-/Minderstunden),
- **Hochrechnung** auf Woche und Monat: Ø × konfigurierte Arbeitstage je Woche bzw. × 52/12 Wochen je Monat.

Die Hochrechnung nimmt an, dass an allen konfigurierten Arbeitstagen so weitergearbeitet wird. Sie berücksichtigt **keine** Periodenkappung und **keinen** geplanten Urlaub. Fehlen weniger als 30 Arbeitstage in den Daten, wird mit den vorhandenen gerechnet.

## Tagesübersicht

- Standard-Tagesfenster: **06:00–20:00** (änderbar, auch pro Tag).
- Waagerechtes Diagramm: **Beschriftung in 15-Minuten-Schritten**, Darstellung der Pakete **minutengenau**.
- Vertikale Linien bei 6 h / 10 h / 12 h ab Arbeitsbeginn.
- In den Arbeitspaketen stehen die Titel; **Doppelklick** öffnet die Bearbeitung.
- **Termine** erscheinen als eigene Markierung auf der Zeitachse (analog zu den gelben Pausenfenstern), optisch klar von Paketen und Pausen getrennt; der Titel steht an der Markierung. Anzeige auch an freien Tagen und Feiertagen, sofern Datum bzw. Wochentag passt.

## Jahresübersicht

Pro Kalenderjahr:

- Navigation per Button zum **vorherigen** bzw. **nächsten** Jahr,
- je Monat: Soll- und Ist-Arbeitszeit, Mehr-/Minderzeit des Monats sowie der **Kontostand** (nach möglicher Kappung),
- geplante und genommene Urlaubstage.
- Wurden Stunden abgeschnitten, wird das in der Kopfzeile ausgewiesen.

Auswahl eines Monats aktualisiert die Monatsübersicht.

---

# Neuberechnung und Fortschreibung

Soll, Ist, Saldo und Urlaub bauen aufeinander auf: der Vormonats-Saldo (und z. B. genommene Urlaubstage) fließt in den Folgemonat ein. Deshalb gilt eine feste Reihenfolge.

## Laufender Arbeitstag

Solange am **aktuellen Tag** mindestens ein Arbeitspaket aktiv ist:

1. Die Zeiten (Ende der aktiven Pakete) werden **etwa einmal pro Minute** in die Monatsdatei geschrieben.
2. Anschließend wird der **gesamte aktuelle Monat** neu berechnet.
3. Die GUI wird gezielt aktualisiert:
   - **Monatsübersicht:** der betroffene Tag (Ist/Saldo) und die Monatssumme,
   - **Jahresübersicht:** der betreffende Monat und die **Jahressumme**.

Folgemonate werden bei diesem Minutentakt **nicht** neu berechnet.

## Änderung eines früheren Monats

Wird ein **bereits abgeschlossener bzw. vorheriger Monat** manuell geändert (Arbeitspakete, Urlaub, Krankheit o. Ä.):

1. Dieser Monat wird neu berechnet.
2. Danach werden **alle Folgemonate** neu berechnet, weil sich Monatssaldo, Urlaubstage usw. auf die Folgezeit auswirken.
3. Sind alle betroffenen Monate berechnet, wird die **Jahressumme** (bei Jahreswechsel jede betroffene Jahressumme) neu berechnet.
4. Die GUI wird aktualisiert (Monatszeilen, Monatssumme, Jahressumme).

## Änderung im aktuellen Monat (nicht nur Minutentakt)

Eine manuelle Änderung an einem Tag des **aktuellen Monats** berechnet diesen Monat neu und aktualisiert den Tag, die Monatssumme sowie den Monat und die Jahressumme in der Jahresübersicht – analog zum laufenden Arbeitstag, ohne Kaskade auf Folgemonate.

---

# Datenablage

- Speicherung als **JSON**, lokal (kein Server in v1).
- **Standard-Datenordner:** `%APPDATA%/Journal` (ein Benutzer, ein Konto). Beim ersten Start wird der frühere Ordner `%APPDATA%/Journal/Journal` dorthin verschoben, sofern kein anderer Ordner gewählt ist.
- **Eine Datei pro Monat** unter `{Datenordner}/monate/{Jahr}-{Monat}.json`.
- **Eine Datei pro Jahr** unter `{Datenordner}/jahre/{Jahr}.json` (Monatssummen, Jahressumme, Fortschreibung).
- **Termine** unter `{Datenordner}/termine.json` (einmalige und wöchentliche Termine; keine Zeitrechnung).
- Speicherort: **vom Benutzer wählbar**.
- Ein Benutzer / eine Installation – **kein Login**.
- **Export** (z. B. CSV/PDF): optional, gewünscht für eine spätere Ausbaustufe oder als optionale Funktion.
