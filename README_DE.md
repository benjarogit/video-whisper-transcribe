**Deutsch** | [English](README.md)

---

# 🎙️ Video Whisper - Audio/Video Transkriptionstool

Ein modernes, benutzerfreundliches Tool zur automatischen Transkription von Audio- und Videodateien mit WhisperX und OpenAI Whisper.

**Nur Linux** – Windows/macOS werden nicht unterstützt.

## ✨ Features

- 🎯 **Automatische Spracherkennung** - Unterstützt 10+ Sprachen
- 📝 **Zeitstempel** - Präzise Segment-Level Timestamps
- 🚀 **GPU-Beschleunigung** - Automatische Erkennung von CUDA/ROCm
- 💻 **CPU-Fallback** - Funktioniert auch ohne GPU
- 🎨 **Moderne CLI** - Farbige, interaktive Benutzeroberfläche
- 📊 **Fortschrittsanzeige** - Echtzeitanzeige des Transkriptionsstatus
- 📁 **Batch-Verarbeitung** - Mehrere Dateien nacheinander transkribieren
- 🔗 **URL-Download** - YouTube- oder andere URL eingeben; als Video oder MP3 herunterladen, dann transkribieren (via [youtube-dl](https://github.com/ytdl-org/youtube-dl))

## 🎬 Unterstützte Formate

**Audio:** MP3, WAV, M4A, FLAC, AAC, OGG, OPUS  
**Video:** MP4, MKV, AVI, MOV, WebM, WMV

## 📋 Voraussetzungen (Linux)

Orientierung: [WhisperX README – Setup](https://github.com/m-bain/whisperX) (CUDA 12.8 optional → `pip install whisperx`; FFmpeg nötig).

- **Python 3.10–3.13** (WhisperX unterstützt kein 3.14+). Mehrere Python-Versionen systemweit sind üblich – 3.12 oder 3.13 **neben** der aktuellen Version installieren.
- **FFmpeg** (Systempaket, muss installiert sein; README: „You may also need to install ffmpeg“)
- Optional: **CUDA 12.8** für GPU (README: „install the CUDA toolkit 12.8 before WhisperX“)

### Python: mehrere Versionen systemweit (koexistierend)

Unter Linux können mehrere Python-Versionen parallel installiert sein (z.B. `python3` = 3.14 und `python3.12` = 3.12). Die **venv** nutzt nur die kompatible Version – dein System-Python bleibt unberührt.

**Wenn noch kein kompatibles Python (3.10–3.13) vorhanden ist:** Einfach `./start.sh` ausführen (startet bei Bedarf die Installation) oder `./scripts/install.sh`. Das Skript erkennt die Distribution (Arch, Debian/Ubuntu, Fedora, OpenSUSE) und fragt, ob eine kompatible Version **systemweit (koexistierend)** installiert werden soll; bei NVIDIA/AMD wird optional PyTorch mit CUDA/ROCm angeboten.

**Manuell installieren** (optional):

```bash
# Arch Linux / CachyOS (AUR)
yay -S python312

# Debian / Ubuntu
sudo apt install python3.12 python3.12-venv
```

Danach im Projektordner erneut `./start.sh` oder `./scripts/install.sh` – es erkennt `python3.12` bzw. `python3.13` automatisch.

### System-Pakete

```bash
# Arch Linux / CachyOS (Python 3.12 neben Standard-Python, z.B. wenn python3 schon 3.14 ist)
yay -S python312 ffmpeg
# oder nur Basis
sudo pacman -S python ffmpeg

# Debian / Ubuntu
sudo apt install python3.12 python3.12-venv ffmpeg

# Fedora
sudo dnf install python3 python3-pip ffmpeg
```

### Optional: GPU-Support

**NVIDIA CUDA (laut WhisperX README: CUDA 12.8):**
```bash
# CUDA Installation Guide: https://docs.nvidia.com/cuda/cuda-installation-guide-linux/
# Arch/CachyOS (Beispiel)
sudo pacman -S nvidia cuda
```
Das Installationsskript bietet PyTorch mit CUDA 12.8 / 12.4 / 12.1 an (cu128/cu124/cu121).

**AMD ROCm (für neuere AMD GPUs):**
```bash
# ROCm-Installation (siehe AMD ROCm Dokumentation)
```

## Skripte im Überblick

| Skript | Zweck | Wann nutzen? |
|--------|--------|----------------|
| **scripts/install.sh** | **Einmal-Installation:** Prüft System (Python 3.10–3.13, ggf. systemweit installieren), legt venv an, fragt bei NVIDIA/AMD nach PyTorch mit CUDA/ROCm, installiert alle Pakete (WhisperX, torch, …), schreibt `logs/install.json` (Manifest), optional Kurztest mit test.mp4. | Erste Installation oder „alles neu“. |
| **scripts/update.sh** | **Kein Installer.** Setzt bestehende venv voraus. Zeigt Status (systemweite Pythons, venv, WhisperX), prüft Kompatibilität, aktualisiert nur Pakete (`pip install -r requirements.txt`). | Regelmäßig zum Aktualisieren; oder direkt nach der Installation zum Prüfen. |
| **scripts/uninstall.sh** | **Vollständiger Rückbau:** Entfernt venv, State, txt, logs (liest `logs/install.json`); fragt optional nach Deinstallation von durch die Installation gesetzten System-Paketen. Alles in whisper.log. | Werkseinstellung / komplett deinstallieren. |
| **start.sh** | **Täglicher Start:** Prüft, ob installiert; wenn nicht, startet automatisch `scripts/install.sh`. Zeigt bei Updates einen Hinweis. Menü für Datei, Modell, Sprache; startet die Transkription. | Immer zum Transkribieren. |

**Empfohlener Ablauf (erstmalig):**
1. **Installation** – `./start.sh` (startet bei Bedarf die Installation) oder `./scripts/install.sh` (prüft System, fragt bei GPU nach CUDA/ROCm, installiert alles).
2. **Update testen** – `./scripts/update.sh`.
3. **Erster Lauf** – `./start.sh` und test.mp4 wählen (oder direkt `./venv/bin/python3 transcribe.py test.mp4 ./txt small de`).

**Abhängigkeiten:** Wir richten uns nach der [WhisperX README](https://github.com/m-bain/whisperX). Dort: CUDA 12.8 optional für GPU, dann `pip install whisperx`. Unser `scripts/install.sh` übernimmt genau diese Reihenfolge (System prüfen → optional PyTorch mit CUDA/ROCm → WhisperX + unsere Zusätze). `requirements.txt` enthält nur `whisperx` (WhisperX legt die passenden Versionen von torch, torchaudio usw. fest) plus unsere Zusätze (ffmpeg-python, tqdm). **Aktuell halten:** `./scripts/update.sh` oder `pip install --upgrade whisperx`. Es gibt **keine portable Python-Variante**; nur systemweites Python (mehrere Versionen koexistierend).

---

## 🚀 Installation

1. **Python 3.12 oder 3.13** neben der aktuellen Version installieren (siehe oben, z.B. `yay -S python312` oder `apt install python3.12 python3.12-venv`).

2. **Projektverzeichnis wechseln**
```bash
cd "/pfad/zu/Video Whisper"
```

3. **Venv anlegen und Abhängigkeiten installieren** (einmalig)
```bash
./scripts/install.sh
```
Erkennt automatisch `python3.12`/`python3.13`; bei NVIDIA/AMD erscheint die Abfrage für PyTorch mit CUDA bzw. ROCm.

**Manuell (falls gewünscht):**
```bash
./venv/bin/pip install --upgrade pip
./venv/bin/pip install -r requirements.txt
# Mit NVIDIA GPU (laut README CUDA 12.8): zuerst torch/torchaudio mit cu128/cu124/cu121, dann requirements.txt
```

**Für AMD GPU (ROCm):**
```bash
./venv/bin/pip install --upgrade pip
./venv/bin/pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.0
./venv/bin/pip install -r requirements.txt
```

**Hinweis:** `./start.sh` prüft, ob bereits installiert ist; wenn nicht, startet automatisch die Installation (`scripts/install.sh`). Nach Installation von Python 3.12 einmal `./scripts/install.sh` ausführen.

## 🎯 Verwendung

### Interaktiver Modus (empfohlen)

```bash
./start.sh
```

Das Skript wird mit Bash ausgeführt und führt durch:
1. **Datei oder URL:** Lokale Datei wählen oder eine URL eingeben (z. B. YouTube) – als Video (MP4) oder nur Audio (MP3) herunterladen, dann transkribieren
2. Modell-Auswahl (tiny bis large-v3)
3. Sprach-Auswahl (oder automatisch)

### Direkter Aufruf (ohne venv aktivieren)

```bash
./venv/bin/python3 transcribe.py <input_datei> <ausgabe_ordner> [modell] [sprache]
```

**Beispiele:**
```bash
# Mit Standardeinstellungen (small model, auto-detect)
./venv/bin/python3 transcribe.py video.mp4 ./txt

# Mit spezifischem Modell
./venv/bin/python3 transcribe.py audio.mp3 ./txt medium

# Mit Modell und Sprache
./venv/bin/python3 transcribe.py interview.mp4 ./txt large-v3 de
```

## 🧠 Modell-Übersicht

| Modell | Größe | VRAM | Geschwindigkeit | Qualität |
|--------|-------|------|-----------------|----------|
| `tiny` | ~1GB | ~1GB | ⚡⚡⚡⚡⚡ | ⭐⭐ |
| `base` | ~1GB | ~1GB | ⚡⚡⚡⚡ | ⭐⭐⭐ |
| `small` | ~2GB | ~2GB | ⚡⚡⚡ | ⭐⭐⭐⭐ |
| `medium` | ~5GB | ~5GB | ⚡⚡ | ⭐⭐⭐⭐⭐ |
| `large` | ~10GB | ~10GB | ⚡ | ⭐⭐⭐⭐⭐ |
| `large-v2` | ~10GB | ~10GB | ⚡ | ⭐⭐⭐⭐⭐ |
| `large-v3` | ~10GB | ~10GB | ⚡ | ⭐⭐⭐⭐⭐⭐ |

**Empfehlung:**
- **CPU:** `tiny` oder `base` (schnell genug)
- **GPU mit 4-6GB VRAM:** `small` oder `medium`
- **GPU mit 12GB+ VRAM:** `large-v3` (beste Qualität)

## 🌍 Unterstützte Sprachen

- 🇩🇪 Deutsch (`de`)
- 🇬🇧 Englisch (`en`)
- 🇫🇷 Französisch (`fr`)
- 🇪🇸 Spanisch (`es`)
- 🇮🇹 Italienisch (`it`)
- 🇵🇹 Portugiesisch (`pt`)
- 🇷🇺 Russisch (`ru`)
- 🇯🇵 Japanisch (`ja`)
- 🇨🇳 Chinesisch (`zh`)
- ... und viele weitere (automatische Erkennung)

## 📊 Ausgabeformat

Die Transkription wird als `.txt`-Datei gespeichert mit folgendem Format:

```
[0.00s - 3.45s] Dies ist der erste Satz des Transkripts.

[3.45s - 7.20s] Hier folgt der zweite Satz mit präzisen Zeitstempeln.

[7.20s - 12.80s] Und so weiter...
```

## 🐛 Fehlerbehebung

### "FFmpeg not found"
```bash
sudo pacman -S ffmpeg  # Arch/CachyOS
sudo apt install ffmpeg  # Debian/Ubuntu
```

### "CUDA out of memory"
- Kleineres Modell verwenden
- Andere GPU-Programme schließen
- CPU-Modus nutzen

### "No module named 'whisperx'"
```bash
./venv/bin/pip install -r requirements.txt
```
Oder `./start.sh` ausführen – installiert bei Bedarf.

### Komplett neu installieren (Werkseinstellung)

**Empfohlen:** `./scripts/uninstall.sh` dann `./start.sh`

**Manuell:**
```bash
rm -rf venv
rm -f .video_whisper_state
./start.sh
```

## 📝 Logging

Alle Skripte und transcribe.py schreiben in `logs/whisper.log`. Bei neuem Start wird die aktuelle Datei zu `logs/whisper.old.log` umbenannt.

## 🔄 Updates

```bash
./scripts/update.sh
```

## 📁 Projektstruktur

- `transcribe.py` – Hauptskript (WhisperX-Transkription)
- `start.sh` – Interaktiver Launcher (Bash)
- `scripts/install.sh` – Einmal-Installation (venv + WhisperX + Pakete; schreibt logs/install.json)
- `scripts/update.sh` – Pakete aktualisieren
- `scripts/uninstall.sh` – Vollständiger Rückbau (venv, State, txt, logs; optional System-Pakete)
- `requirements.txt` – Python-Abhängigkeiten
- `venv/` – Virtuelle Umgebung (lokal, nicht im Repo)
- `txt/` – Ausgabeordner für Transkripte (nicht im Repo)

## 📋 Changelog

Siehe [CHANGELOG.md](CHANGELOG.md) für Versionsgeschichte und neue Features.

## 📜 Lizenz

Dieses Tool verwendet: **WhisperX** (BSD), **OpenAI Whisper** (MIT), **FFmpeg** (GPL/LGPL).

## 📚 Weiterführende Links

- [WhisperX (m-bain/whisperX)](https://github.com/m-bain/whisperX)
- [OpenAI Whisper](https://github.com/openai/whisper)
- [FFmpeg Documentation](https://ffmpeg.org/documentation.html)

---

**Viel Erfolg beim Transkribieren! 🎉**
