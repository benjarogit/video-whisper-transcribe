#!/usr/bin/env bash
# Video Whisper – Vollständiger Rückbau: Projekt-Ressourcen (venv, State, txt, logs) und
# von der Installation gesetzte System-Pakete (laut logs/install.json). Alles wird in whisper.log protokolliert.

set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(cd "$SCRIPTS_DIR/.." && pwd)"
VENV_PATH="${SCRIPT_DIR}/venv"
cd "$SCRIPT_DIR"

# Logging von Anfang an: logs/ anlegen, lib_log sourcen, sofort log_init
mkdir -p "${SCRIPT_DIR}/logs"
# shellcheck source=scripts/lib_log.sh
source "${SCRIPTS_DIR}/lib_log.sh"
log_init "uninstall.sh"

log_info_quiet "--- Uninstall gestartet ---"
log_info_quiet "Projektverzeichnis: $SCRIPT_DIR"

# Manifest einlesen (logs/install.json)
MANIFEST_PATH="${SCRIPT_DIR}/logs/install.json"
VENV_TO_REMOVE="${SCRIPT_DIR}/venv"
STATE_TO_REMOVE="${SCRIPT_DIR}/.video_whisper_state"
SYSTEM_PACKAGES_JSON="[]"
export SCRIPT_DIR MANIFEST_PATH

if [ -f "$MANIFEST_PATH" ]; then
    log_info_quiet "Lese Manifest: $MANIFEST_PATH"
    if command -v jq &>/dev/null; then
        VENV_TO_REMOVE=$(jq -r '.venv_path // empty' "$MANIFEST_PATH" 2>/dev/null) || VENV_TO_REMOVE="${SCRIPT_DIR}/venv"
        STATE_TO_REMOVE=$(jq -r '.state_path // empty' "$MANIFEST_PATH" 2>/dev/null) || STATE_TO_REMOVE="${SCRIPT_DIR}/.video_whisper_state"
        SYSTEM_PACKAGES_JSON=$(jq -c '.system_packages_installed // []' "$MANIFEST_PATH" 2>/dev/null) || SYSTEM_PACKAGES_JSON="[]"
        log_info_quiet "Manifest eingelesen (jq): venv_path=$VENV_TO_REMOVE state_path=$STATE_TO_REMOVE"
    else
        # Fallback: Python (system) zum Parsen des JSON
        export MANIFEST_PATH
        eval "$(python3 << 'PYPARSE'
import json, os
mp = os.environ.get("MANIFEST_PATH", "")
sd = os.environ.get("SCRIPT_DIR", "")
try:
    with open(mp) as f:
        d = json.load(f)
    v = d.get("venv_path", sd + "/venv")
    s = d.get("state_path", sd + "/.video_whisper_state")
    p = json.dumps(d.get("system_packages_installed", []))
    print("VENV_TO_REMOVE=%s" % repr(v))
    print("STATE_TO_REMOVE=%s" % repr(s))
    print("SYSTEM_PACKAGES_JSON=%s" % repr(p))
except Exception:
    print("VENV_TO_REMOVE=%s" % repr(sd + "/venv"))
    print("STATE_TO_REMOVE=%s" % repr(sd + "/.video_whisper_state"))
    print('SYSTEM_PACKAGES_JSON="[]"')
PYPARSE
)" 2>/dev/null || true
        log_info_quiet "Manifest eingelesen (Python-Fallback): venv_path=$VENV_TO_REMOVE state_path=$STATE_TO_REMOVE"
    fi
    [ -z "$VENV_TO_REMOVE" ] && VENV_TO_REMOVE="${SCRIPT_DIR}/venv"
    [ -z "$STATE_TO_REMOVE" ] && STATE_TO_REMOVE="${SCRIPT_DIR}/.video_whisper_state"
else
    log_warn "Kein logs/install.json gefunden – nur Standard-Pfade werden entfernt."
fi

# Projekt-Rückbau (immer geloggt)
log_info_quiet "Entferne venv: $VENV_TO_REMOVE"
if [ -d "$VENV_TO_REMOVE" ]; then
    log_run_cmd "rm -rf venv" rm -rf "$VENV_TO_REMOVE" || true
else
    log_info_quiet "venv nicht vorhanden, übersprungen."
fi

log_info_quiet "Entferne State-Datei: $STATE_TO_REMOVE"
if [ -f "$STATE_TO_REMOVE" ]; then
    log_run_cmd "rm -f .video_whisper_state" rm -f "$STATE_TO_REMOVE" || true
else
    log_info_quiet "State-Datei nicht vorhanden, übersprungen."
fi

log_info_quiet "Entferne txt/* (Transkripte)"
if [ -d "${SCRIPT_DIR}/txt" ]; then
    log_run_cmd "rm -rf txt/*" rm -rf "${SCRIPT_DIR}/txt"/* 2>/dev/null || true
    log_info_quiet "txt bereinigt."
else
    log_info_quiet "Ordner txt nicht vorhanden, übersprungen."
fi

# System-Pakete (nur wenn im Manifest und nicht leer)
if [ -n "$SYSTEM_PACKAGES_JSON" ] && [ "$SYSTEM_PACKAGES_JSON" != "[]" ]; then
    log_info_quiet "System-Pakete im Manifest: $SYSTEM_PACKAGES_JSON"
    echo ""
    read -rp "System-Pakete aus install.json deinstallieren? (j/n): " sys_antwort
    log_info_quiet "Frage: System-Pakete deinstallieren? Benutzer-Antwort: $sys_antwort"
    if [[ "$sys_antwort" =~ ^[jJyY]$ ]]; then
        export SYSTEM_PACKAGES_JSON
        # Pro Eintrag einen Deinstallationsbefehl ausgeben, dann in Bash ausführen und loggen
        while IFS= read -r cmd; do
            [ -z "$cmd" ] && continue
            log_info_quiet "Führe aus: $cmd"
            log_run_cmd "System-Paket deinstallieren: $cmd" sh -c "$cmd" || true
        done < <(python3 -c "
import json, os, shlex
data = json.loads(os.environ.get('SYSTEM_PACKAGES_JSON', '[]'))
for entry in data:
    manager = entry.get('manager', '')
    packages = entry.get('packages', [])
    if not packages:
        continue
    if manager == 'pacman':
        print('sudo pacman -R --noconfirm ' + ' '.join(shlex.quote(p) for p in packages))
    elif manager == 'yay':
        print('yay -R --noconfirm ' + ' '.join(shlex.quote(p) for p in packages))
    elif manager == 'apt':
        print('sudo apt remove -y ' + ' '.join(shlex.quote(p) for p in packages))
    elif manager == 'dnf':
        print('sudo dnf remove -y ' + ' '.join(shlex.quote(p) for p in packages))
    elif manager == 'zypper':
        print('sudo zypper -n remove ' + ' '.join(shlex.quote(p) for p in packages))
" 2>/dev/null)
        log_info_quiet "System-Paket-Deinstallation abgeschlossen."
    else
        log_info_quiet "System-Pakete nicht deinstalliert (Benutzer: nein)."
    fi
else
    log_info_quiet "Keine System-Pakete im Manifest oder leer – übersprungen."
fi

# logs/* entfernen (inkl. install.json und whisper.log – kompletter Rückbau)
log_info_quiet "Entferne logs/* (inkl. install.json und whisper.log)"
if [ -d "${SCRIPT_DIR}/logs" ]; then
    log_run_cmd "rm -rf logs/*" rm -rf "${SCRIPT_DIR}/logs"/* 2>/dev/null || true
    log_info_quiet "logs bereinigt."
fi

log_info_quiet "--- Uninstall abgeschlossen ---"
echo ""
echo -e "${LOG_GREEN}Uninstall abgeschlossen.${LOG_NC} Projekt-Ressourcen und ggf. erfasste System-Pakete wurden entfernt."
echo "Log wurde in whisper.log geschrieben (und mit logs/ entfernt)."
