# Video Whisper – Installation, Update & Test

**Ablauf:** Installation (System prüfen, WhisperX installieren) → Update testen → Erster Start mit test.mp4.

**Orientierung:** [WhisperX README – Setup](https://github.com/m-bain/whisperX) (CUDA 12.8 optional, dann `pip install whisperx`; FFmpeg nötig). Unsere Skripte folgen dieser Reihenfolge.

Mehrere Python-Versionen systemweit (koexistierend) sind üblich. Bei fehlendem kompatiblen Python (3.10–3.13) können die Installationsskripte es **systemweit** über den Paketmanager einrichten.

**Skripte:** `scripts/install.sh` = einmalige Installation (FFmpeg-Check, Python, venv, optional PyTorch CUDA 12.8/12.4/12.1 oder ROCm, dann WhisperX); `scripts/update.sh` = Pakete aktualisieren; `start.sh` = täglicher Start (startet bei Bedarf die Installation, dann Menü).

---

## Schritt 1: In den Projektordner wechseln

```bash
cd "/mnt/ssd2/Backup (SSD2)/Projekte/Video Whisper"
```

---

## Schritt 2: Installation (venv + WhisperX)

**Variante A – Empfohlen:** Einfach starten; bei Bedarf wird die Installation automatisch gestartet:

```bash
./start.sh
```

**Variante B – Installation manuell ausführen:**

```bash
./scripts/install.sh
```

- Ist bereits ein kompatibles Python (z.B. `python3.12`) installiert, wird es automatisch genutzt.
- **Ist keins vorhanden:** Das Skript erkennt die Distribution und fragt, ob eine kompatible Version systemweit (koexistierend) installiert werden soll. Bei NVIDIA/AMD erscheint die Abfrage für PyTorch mit CUDA bzw. ROCm.

---

## Schritt 3: Update (Status + kompatible Pakete)

```bash
./scripts/update.sh
```

Zeigt u.a.: systemweit installierte Python-Versionen, venv-Python, WhisperX-Status, relevante Pakete. Aktualisiert nur WhisperX-kompatible Pakete.

---

## Schritt 4: Erster Starttest (Menüführung)

Nach Installation (und optional `./scripts/update.sh`) den ersten Lauf mit dem interaktiven Menü durchführen:

1. **start.sh starten**
   ```bash
   ./start.sh
   ```
2. **Datei wählen** – Es erscheint eine nummerierte Liste aller Audio-/Videodateien im Projektordner. Gib die **Nummer** der gewünschten Datei ein (z. B. `1` für test.mp4, falls vorhanden).
3. **Modell wählen** – Optionen: tiny, base, small (Standard), medium, large, large-v2, large-v3. Für einen schnellen Test: `1` (tiny) oder Enter für small.
4. **Sprache wählen** – z. B. `2` für Deutsch, oder Enter für automatische Erkennung.
5. **Transkription** – Sie läuft automatisch. Die Ausgabe landet in `txt/<dateiname>.txt` (z. B. `txt/test.txt`).

**Alternative ohne Menü (Einzeiler):**

```bash
./venv/bin/python3 transcribe.py test.mp4 ./txt tiny de
```

(Modell „tiny“, Sprache Deutsch; Ausgabe in `txt/test.txt`.)

**State/Kompatibilität:** Die Skripte speichern Installations- und Systeminfos in `.video_whisper_state` (wird von install.sh/update.sh geschrieben). start.sh zeigt optional „Installation vom … (Python X.Y, WhisperX Z)“ an. update.sh prüft die Kompatibilität (z. B. Python 3.10–3.13) und führt nur kompatible Updates durch; bei inkompatiblen Hinweisen wird nicht upgegradet, aber eine Meldung ausgegeben.

---

## Übersicht

| Schritt | Befehl | Wirkung |
|--------|--------|--------|
| 1 | `cd "…/Video Whisper"` | Projektordner |
| 2 | `./start.sh` oder `./scripts/install.sh` | start.sh: bei Bedarf Installation, dann Menü; install.sh: venv anlegen; bei fehlendem Python: Angebot zur systemweiten Installation; bei GPU: CUDA/ROCm-Abfrage |
| 3 | `./scripts/update.sh` | Status anzeigen, nur WhisperX-kompatible Pakete aktualisieren |
| 4 | `./start.sh` | Testlauf / Transkribieren |

**Log-System:** Alle Logs liegen im Ordner `logs/`:
- `logs/whisper.log` – install.sh, update.sh, start.sh, uninstall.sh und transcribe.py (eine gemeinsame Datei, Timestamp, Level, Skriptname)
- `logs/whisper.old.log` – vorheriger Lauf (wird bei neuem Start von start.sh umbenannt)
- `logs/install.json` – Install-Manifest (wird nach jeder Installation geschrieben; enthält u. a. Projektpfade, system_packages_installed, pip_freeze). Wird von `./scripts/uninstall.sh` gelesen.

**Uninstall:** `./scripts/uninstall.sh` baut die Installation vollständig zurück (venv, State, txt, logs) und kann optional die im Manifest erfassten System-Pakete deinstallieren. Alles wird in whisper.log geloggt.

Bei Problemen: Logs in `logs/` prüfen, Fehlermeldungen im Terminal.
