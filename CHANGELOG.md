# Changelog

Alle nennenswerten Änderungen am Projekt werden hier dokumentiert.

Format: [Keep a Changelog](https://keepachangelog.com/de/1.0.0/), Versionierung: [Semantic Versioning](https://semver.org/lang/de/).

---

## [1.0.6] - 2026-02-17


### Added

- **Transkription:** Spinner mit Fortschritt in % (1–89 % während Transkription, 90–100 % bei Segmenten). Bibliotheks-Ausgabe (z. B. torchcodec, Lightning) wird unterdrückt und nur ins Log geschrieben.
- **Menü nach Transkription:** „Noch eine transkribieren? (j/n)“ – bei „j“ zurück zu Schritt 1 ohne erneuten Update-Check.
- **Download-Dateinamen:** Einzel-URL: optional eigener Dateiname, sonst Videotitel von YouTube. Bulk: optional Basis-Titel (z. B. „Video“ → Video 1, Video 2, …). Keine Überschreibung: bei Kollision „Titel (2).ext“, „Titel (3).ext“.
- **Menü-Option 4:** Alle Dateien in `medien/` zu prass1, prass2, … umbenennen (sortiert nach Name).
- **yt-dlp:** Erkennt Einzelvideo vs. Playlist; bei Playlist-URL wird nur ein Video geladen (`noplaylist`).

### Changed

- **Dateiliste:** Wird bei Rückkehr ins Menü jedes Mal neu aus `medien/` gelesen (keine gecachte Liste).
- **Bulk-Download:** Klarere Anzeige (Leerzeile zwischen Einträgen, Spinner mit aktuellem Zähler).
- **Fehlerausgabe:** Bei fehlgeschlagenem Download wird die vollständige Fehlerausgabe von yt-dlp/Skript angezeigt; bei fehlgeschlagener Transkription die letzten Zeilen aus `logs/whisper.log`.

### Fixed

- **Transkription „hängt“ nach ✓:** Mit `set -e` beendete `wait $pid` bei Fehlercode das Skript – Exit-Code wird nun ohne Abbruch ausgewertet.
- **Transkription fehlgeschlagen (Exit 1):** FFmpeg-Vorverarbeitung: Für Nicht-WAV-Dateien wird Audio per FFmpeg in eine temporäre WAV (16 kHz, mono) extrahiert, um Codec-/Pipe-Fehler (z. B. „Output file does not contain any stream“) zu vermeiden.
- **Download „fehlgeschlagen“ obwohl Datei da:** Pfad-Ausgabe mit `flush=True`; Fallback sucht neueste Datei in `medien/` seit Download-Start (Start-Marker-Datei, da Progress-Datei ständig überschrieben wird).
- **Spinner:** Weißes Kästchen am Zeilenende war der sichtbare Cursor – Cursor wird während des Spinners ausgeblendet und danach wieder eingeblendet.


## [Unreleased]

_(Keine Änderungen.)_

---
---

## [1.0.4] - 2026-02-17

### Changed

- **Medienordner:** Einheitlicher Ordner `medien/` für alle Audio-/Videodateien. Lokale Dateien werden nur noch in `medien/` gesucht, URL-Downloads (YouTube etc.) speichern ebenfalls in `medien/`. Ersetzt den bisherigen Ordner `downloads/`.
- README und Doku (inkl. INSTALL_UND_TEST.md) an Ordner `medien/` angepasst.

### Added

- **Download-Fortschritt:** Beim URL-Download erscheint ein Spinner mit Fortschrittsanzeige (Prozent oder MB).
- **Robusterer URL-Download:** Wenn eine Datei trotz Fehlermeldung (z. B. Post-Processing) heruntergeladen wurde, wird sie nun erkannt und verwendet.

### Fixed

- **Download „fehlgeschlagen“ obwohl Datei da:** Ausgabe von Skript und Fehlermeldungen wurden getrennt, Pfad wird zuverlässig aus stdout gelesen.
- **gitpush.sh:** Tag-Name wurde verfälscht, wenn vor dem Bump uncommittete Änderungen lagen; Ausgabe von `commit_all_if_dirty` geht nun auf stderr.

---

## [1.0.3] - 2026-02-17

### Changed

- **Update-Anzeige:** yt-dlp erscheint in der Paketliste von `update.sh` und wird bei „Updates verfügbar“ in `start.sh` berücksichtigt.

---

## [1.0.2] - 2026-02-17

### Added

- **Spinner beim Start:** Während der Prüfung „WhisperX prüfen…“ und „Updates prüfen…“ wird ein Spinner angezeigt.
- **yt-dlp statt youtube-dl:** URL-Download nutzt [yt-dlp](https://github.com/yt-dlp/yt-dlp); behebt typische YouTube-Fehler (z. B. „The page needs to be reloaded“). youtube-dl wird bei Installation/Update aus der venv entfernt.

### Fixed

- Spinner-Zeile: Doppelte Punkte („……“) durch Bereinigen der Zeile am Ende behoben.

---

## [1.0.1] - 2026-02-17

### Added

- **URL-Download:** Im Start-Menü optional eine URL eingeben (z. B. YouTube); Download als Video (MP4) oder nur Audio (MP3), anschließend Transkription. Nutzt [yt-dlp](https://github.com/yt-dlp/yt-dlp). _(Ab 1.0.4: Ordner `medien/` statt `downloads/`.)_

---

## [1.0.0] - 2026-02-17

### Added

- Erstes Release: Transkription von Audio/Video mit WhisperX.
- Interaktives Menü (Datei, Modell, Sprache), GPU- und CPU-Unterstützung.
- Skripte: `install.sh`, `update.sh`, `uninstall.sh`, `start.sh`.
- Gemeinsames Logging in `logs/whisper.log`, README auf Deutsch und Englisch.
