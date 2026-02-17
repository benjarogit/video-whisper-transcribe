#!/usr/bin/env bash
# Video Whisper – Update (kein Installer). Voraussetzung: installiert (venv + WhisperX).
# Prüft Kompatibilität; bei verfügbarem Update: Kompatibilität prüfen, ggf. upgraden und State aktualisieren.

set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(cd "$SCRIPTS_DIR/.." && pwd)"
readonly VENV_PATH="${SCRIPT_DIR}/venv"

# shellcheck source=scripts/ui.sh
source "${SCRIPTS_DIR}/ui.sh"
# Gemeinsame State-Lib
# shellcheck source=scripts/lib_install_state.sh
source "${SCRIPTS_DIR}/lib_install_state.sh"
# shellcheck source=scripts/lib_log.sh
source "${SCRIPTS_DIR}/lib_log.sh"
log_init "update.sh"

ui_header "Video Whisper – Update"

# Einheitliche Installationsprüfung (wie start.sh/install.sh)
if ! is_installed; then
    log_warn "Nicht installiert (venv oder WhisperX fehlt)."
    ui_fail "Nicht installiert. Zuerst: ./start.sh oder ./scripts/install.sh"
    exit 1
fi

# State-Datei lesen (falls vorhanden), sonst aktuellen State aus venv ableiten
state_path=$(get_state_path)
if [ -f "$state_path" ]; then
    read_state_file || true
else
    read_system_info
    get_venv_versions || true
fi

# Aktuelle venv-Versionen für Kompatibilitätsprüfung und Anzeige
get_venv_versions || true
venv_py="${VENV_PYTHON_VERSION:-}"
if [ -z "$venv_py" ]; then
    venv_py=$("${VENV_PATH}/bin/python3" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null) || true
fi

# --- Systeminfos (kurz) ---
read_system_info
ui_section "System"
ui_log "OS: ${SYS_OS_ID:-unknown} ${SYS_OS_VERSION:-}  FFmpeg: ${SYS_FFMPEG_VERSION:-?}  GPU: ${SYS_GPU_TYPE:-none}"
echo ""

ui_section "Venv (dieses Projekt)"
ui_log "Python $venv_py  ·  WhisperX ${VENV_WHISPERX_VERSION:-?}  ·  torch ${VENV_TORCH_VERSION:-?}"
if python_version_in_range "$venv_py"; then
    ui_ok "Python $venv_py ist WhisperX-kompatibel (3.10–3.13)."
else
    log_error "Python $venv_py ist nicht WhisperX-kompatibel (benötigt 3.10–3.13)."
    ui_log "venv neu anlegen: rm -rf venv && ./scripts/install.sh"
    exit 1
fi
echo ""

ui_section "Relevante Pakete"
"${VENV_PATH}/bin/pip" list 2>/dev/null | grep -iE "whisper|torch|tqdm|numpy|ffmpeg" || true
echo ""

# --- Verfügbare Updates prüfen ---
outdated=$("${VENV_PATH}/bin/pip" list --outdated 2>/dev/null | grep -iE "whisperx|torch|whisper|torchaudio" || true)
if [ -z "$outdated" ]; then
    log_info_quiet "Alles auf dem Stand und kompatibel."
    ui_ok "Alles auf dem Stand und kompatibel."
    echo ""
    exit 0
fi

ui_section "Updates verfügbar"
echo "$outdated"
echo ""

# Kompatibilität: venv-Python muss im Bereich 3.10–3.13 sein (bereits oben geprüft)
# Wenn nicht kompatibel, würden wir hier schon mit exit 1 raus sein.
# Zusätzlich: Falls wir eine "nicht kompatibel"-Regel hätten (z.B. bestimmte WhisperX-Version),
# könnten wir hier prüfen und nicht upgraden.

ui_section "Aktualisierung"
log_run_cmd_spinner "pip install --upgrade pip" "pip aktualisieren…" "${VENV_PATH}/bin/pip" install --upgrade pip || true
log_info_quiet "Starte: pip install --upgrade -r requirements.txt"
if log_run_cmd_spinner "pip install --upgrade -r requirements.txt (WhisperX etc.)" "Pakete aktualisieren (WhisperX etc.)…" "${VENV_PATH}/bin/pip" install --upgrade -r "${SCRIPT_DIR}/requirements.txt"; then
    log_info_quiet "Update durchgeführt (WhisperX/torch etc.)."
    ui_ok "Update durchgeführt."
    # State-Datei mit neuen Versionen aktualisieren
    get_venv_versions || true
    read_state_file 2>/dev/null || true
    read_system_info
    updated_at=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S)
    write_state_file \
        "$updated_at" \
        "${STATE_system_python_used:-$SYS_PYTHON_USED}" \
        "${VENV_PYTHON_VERSION:-$venv_py}" \
        "${STATE_system_gpu_type:-$SYS_GPU_TYPE}" \
        "${STATE_system_cuda_version:-$SYS_CUDA_VERSION}" \
        "${VENV_WHISPERX_VERSION:-}" \
        "${VENV_TORCH_VERSION:-}" \
        "${STATE_first_test_done:-false}"
else
    log_warn "Update fehlgeschlagen oder abgebrochen."
fi
echo ""
ui_divider
log_info_quiet "Update abgeschlossen. Log: $(get_log_path 2>/dev/null)"
ui_log "Versionen nach Update:"
"${VENV_PATH}/bin/pip" list 2>/dev/null | grep -iE "whisper|torch|tqdm|numpy|ffmpeg" || true
echo ""
ui_ok "Fertig."
echo ""
