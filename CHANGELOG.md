# Changelog

Alle nennenswerten Änderungen am Projekt werden hier dokumentiert.

Format: [Keep a Changelog](https://keepachangelog.com/de/1.0.0/), Versionierung: [Semantic Versioning](https://semver.org/lang/de/).

---

## [Unreleased]

_(Keine Änderungen.)_

---

## [1.0.1] - 2026-02-17

### Added

- **URL-Download:** Im Start-Menü optional eine URL eingeben (z. B. YouTube); Download als Video (MP4) oder nur Audio (MP3), anschließend Transkription. Nutzt [youtube-dl](https://github.com/ytdl-org/youtube-dl). Dateien landen im Ordner `downloads/`.

---

## [1.0.0] - 2026-02-17

### Added

- Erstes Release: Transkription von Audio/Video mit WhisperX.
- Interaktives Menü (Datei, Modell, Sprache), GPU- und CPU-Unterstützung.
- Skripte: `install.sh`, `update.sh`, `uninstall.sh`, `start.sh`.
- Gemeinsames Logging in `logs/whisper.log`, README auf Deutsch und Englisch.
