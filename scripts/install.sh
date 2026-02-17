#!/usr/bin/env bash
# Video Whisper – Einmal-Installation. Reihenfolge laut offiziellem WhisperX README:
# https://github.com/m-bain/whisperX (Setup: CUDA 12.8 optional → pip install whisperx; ffmpeg nötig)
# Nur systemweites Python (koexistierend), keine portable Variante.

set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(cd "$SCRIPTS_DIR/.." && pwd)"
VENV_PATH="${SCRIPT_DIR}/venv"
cd "$SCRIPT_DIR"

# shellcheck source=scripts/ui.sh
source "${SCRIPTS_DIR}/ui.sh"
# Gemeinsame State-Lib (Installation prüfen, Systeminfos, State lesen/schreiben)
# shellcheck source=scripts/lib_install_state.sh
source "${SCRIPTS_DIR}/lib_install_state.sh"
# shellcheck source=scripts/lib_log.sh
source "${SCRIPTS_DIR}/lib_log.sh"
log_init "install.sh"

# Wenn bereits installiert und State existiert: Hinweis und optional Neuinstallation
state_path=$(get_state_path)
if is_installed && [ -f "$state_path" ]; then
    read_state_file || true
    ui_ok "Bereits installiert (${STATE_installed_at:-unbekannt})"
    ui_log "Python ${STATE_installed_python_version:-?} · WhisperX ${STATE_installed_whisperx_version:-?}"
    echo ""
    read -rp "Trotzdem neu installieren? (j/n): " antwort
    if [[ ! "$antwort" =~ ^[jJyY]$ ]]; then
        ui_log "Übersprungen. Zum Transkribieren: ./start.sh"
        exit 0
    fi
fi

# Prüft, ob FFmpeg installiert ist (laut WhisperX README: "You may also need to install ffmpeg")
check_ffmpeg() {
    if ! command -v ffmpeg &>/dev/null; then
        log_error "FFmpeg nicht gefunden. WhisperX benötigt FFmpeg."
        ui_info "Installieren: sudo pacman -S ffmpeg (Arch) | sudo apt install ffmpeg (Debian/Ubuntu)"
        ui_log "Danach dieses Skript erneut ausführen."
        exit 1
    fi
}

# Sucht systemweites Python 3.10–3.13; gibt Pfad/Befehl in PY zurück oder leer.
find_compatible_python() {
    local py v major minor
    if [ -n "${VIDEO_WHISPER_PYTHON:-}" ] && (command -v "$VIDEO_WHISPER_PYTHON" &>/dev/null || [ -x "$VIDEO_WHISPER_PYTHON" ]); then
        echo "$VIDEO_WHISPER_PYTHON"
        return
    fi
    for py in python3.13 python3.12 python3.11 python3.10; do
        if command -v "$py" &>/dev/null; then
            v=$("$py" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null) || true
            [ -z "$v" ] && continue
            major="${v%%.*}"; minor="${v#*.}"
            if [ "$major" -eq 3 ] && [ "$minor" -lt 14 ]; then
                echo "$py"
                return
            fi
        fi
    done
    v=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null) || true
    if [ -n "$v" ]; then
        major="${v%%.*}"; minor="${v#*.}"
        if [ "$major" -eq 3 ] && [ "$minor" -lt 14 ]; then
            echo "python3"
            return
        fi
    fi
    echo ""
}

# Von uns installierte System-Pakete (für Install-Manifest). Wird in install_system_python_compatible() bei Erfolg gesetzt.
INSTALLED_SYSTEM_PACKAGES_JSON="[]"

# Installiert eine WhisperX-kompatible Python-Version systemweit (koexistierend) per Paketmanager.
# Bevorzugt Binärpakete (pacman/apt/dnf); AUR (yay) baut oft aus Quellcode → dauert lange.
# Liest /etc/os-release; gibt 0 bei Erfolg zurück, 1 bei Abbruch/Fehler.
install_system_python_compatible() {
    local id id_like
    if [ -f /etc/os-release ]; then
        id=$(grep -E '^ID=' /etc/os-release 2>/dev/null | head -1 | cut -d= -f2 | tr -d '"') || id=""
        id_like=$(grep -E '^ID_LIKE=' /etc/os-release 2>/dev/null | head -1 | cut -d= -f2 | tr -d '"') || id_like=""
    else
        id=""; id_like=""
    fi

    ui_warn "Kein kompatibles Python (3.10–3.13) gefunden. WhisperX benötigt eine dieser Versionen."
    ui_log "Einfachste Variante: In anderem Terminal sudo pacman -S python312 (falls verfügbar), dann hier n und ./start.sh"
    echo ""
    read -rp "Soll das Skript jetzt eine Version installieren? (j/n): " antwort
    if [[ ! "$antwort" =~ ^[jJyY]$ ]]; then
        ui_log "Abbruch. Python per Paketmanager installieren, dann ./start.sh:"
        ui_info "Cachyos/Arch:  sudo pacman -S python312"
        ui_info "Debian/Ubuntu: sudo apt install python3.12 python3.12-venv"
        ui_info "Fedora:        sudo dnf install python3.12"
        return 1
    fi

    case "$id" in
        arch|manjaro|cachyos|endeavouros|garuda)
            if command -v pacman &>/dev/null; then
                ui_info "Versuche Binärpaket (pacman)..."
                if sudo pacman -S --noconfirm python312 2>/dev/null; then
                    ui_ok "Python 3.12 aus Repos installiert."
                    INSTALLED_SYSTEM_PACKAGES_JSON='[{"manager":"pacman","packages":["python312"]}]'
                    log_info_quiet "System-Paket erfasst für Manifest: pacman python312"
                    return 0
                fi
                ui_log "python312 nicht in Pacman-Repos gefunden."
            fi
            if command -v yay &>/dev/null; then
                echo ""
                ui_warn "AUR-Paket python312 wird aus Quellcode gebaut (10–20 Min.)."
                ui_log "Alternative: pacman -Ss python312 prüfen; bei Treffer: sudo pacman -S <paket> und ./start.sh"
                echo ""
                read -rp "Trotzdem jetzt per yay bauen? (j/n): " yay_antwort
                if [[ "$yay_antwort" =~ ^[jJyY]$ ]]; then
                    if yay -S --noconfirm python312; then
                        INSTALLED_SYSTEM_PACKAGES_JSON='[{"manager":"yay","packages":["python312"]}]'
                        log_info_quiet "System-Paket erfasst für Manifest: yay python312"
                        return 0
                    fi
                fi
                ui_log "Übersprungen. Manuell: sudo pacman -S python312 oder yay -S python312"
                return 1
            fi
            ui_log "Am einfachsten: sudo pacman -S python312 (oder yay -S python312). Danach ./start.sh"
            return 1
            ;;
        debian|ubuntu|raspbian|linuxmint|pop)
            ui_info "Installiere python3.12 (apt)..."
            if sudo apt update -qq && sudo apt install -y python3.12 python3.12-venv; then
                INSTALLED_SYSTEM_PACKAGES_JSON='[{"manager":"apt","packages":["python3.12","python3.12-venv"]}]'
                log_info_quiet "System-Paket erfasst für Manifest: apt python3.12 python3.12-venv"
                return 0
            fi
            ;;
        fedora|rhel|centos)
            ui_info "Installiere python3.12 (dnf)..."
            if sudo dnf install -y python3.12; then
                INSTALLED_SYSTEM_PACKAGES_JSON='[{"manager":"dnf","packages":["python3.12"]}]'
                log_info_quiet "System-Paket erfasst für Manifest: dnf python3.12"
                return 0
            fi
            ;;
        opensuse*|suse)
            ui_info "Installiere python312 (zypper)..."
            if sudo zypper -n install python312; then
                INSTALLED_SYSTEM_PACKAGES_JSON='[{"manager":"zypper","packages":["python312"]}]'
                log_info_quiet "System-Paket erfasst für Manifest: zypper python312"
                return 0
            fi
            ;;
        *)
            if [[ "$id_like" == *arch* ]]; then
                if command -v pacman &>/dev/null; then
                    ui_info "Versuche Binärpaket (pacman)..."
                    if sudo pacman -S --noconfirm python312 2>/dev/null; then
                        INSTALLED_SYSTEM_PACKAGES_JSON='[{"manager":"pacman","packages":["python312"]}]'
                        log_info_quiet "System-Paket erfasst für Manifest: pacman python312"
                        return 0
                    fi
                fi
                if command -v yay &>/dev/null; then
                    ui_warn "AUR baut aus Quellcode (10–20 Min.)."
                    read -rp "Trotzdem jetzt per yay bauen? (j/n): " yay_antwort
                    if [[ "$yay_antwort" =~ ^[jJyY]$ ]]; then
                        if yay -S --noconfirm python312; then
                            INSTALLED_SYSTEM_PACKAGES_JSON='[{"manager":"yay","packages":["python312"]}]'
                            log_info_quiet "System-Paket erfasst für Manifest: yay python312"
                            return 0
                        fi
                    fi
                fi
                ui_log "sudo pacman -S python312 (pacman -Ss python312 prüfen). Danach ./start.sh"
                return 1
            fi
            if [[ "$id_like" == *debian* ]] || [[ "$id_like" == *ubuntu* ]]; then
                ui_info "Installiere python3.12 (apt)..."
                if sudo apt update -qq && sudo apt install -y python3.12 python3.12-venv; then
                    INSTALLED_SYSTEM_PACKAGES_JSON='[{"manager":"apt","packages":["python3.12","python3.12-venv"]}]'
                    log_info_quiet "System-Paket erfasst für Manifest: apt python3.12 python3.12-venv"
                    return 0
                fi
            fi
            if [[ "$id_like" == *fedora* ]] || [[ "$id_like" == *rhel* ]]; then
                ui_info "Installiere python3.12 (dnf)..."
                if sudo dnf install -y python3.12; then
                    INSTALLED_SYSTEM_PACKAGES_JSON='[{"manager":"dnf","packages":["python3.12"]}]'
                    log_info_quiet "System-Paket erfasst für Manifest: dnf python3.12"
                    return 0
                fi
            fi
            ui_warn "Unbekannte Distribution ($id). Python 3.10–3.13 installieren, dann ./start.sh:"
            ui_info "Arch:  sudo pacman -S python312 oder yay -S python312"
            ui_info "Debian/Ubuntu:  sudo apt install python3.12 python3.12-venv"
            ui_info "Fedora:  sudo dnf install python3.12"
            return 1
            ;;
    esac
}

# Liest die vom NVIDIA-Treiber unterstützte CUDA-Version (nvidia-smi), gibt 12.8 / 12.4 / 12.1 zurück (für PyTorch-Wheel).
# Ausgabe leer = Erkennung fehlgeschlagen, dann 12.8 als Fallback nutzen.
get_recommended_cuda_for_pytorch() {
    local raw major minor
    raw=$(nvidia-smi 2>/dev/null | grep -oE 'CUDA Version: [0-9.]+' | head -1 | grep -oE '[0-9.]+') || true
    [ -z "$raw" ] && { echo "12.8"; return; }
    major="${raw%%.*}"; minor="${raw#*.}"; minor="${minor%%.*}"
    [ -z "$minor" ] && minor=0
    if [ "$major" -ge 12 ] 2>/dev/null && [ "$minor" -ge 8 ] 2>/dev/null; then echo "12.8"; return; fi
    if [ "$major" -ge 12 ] 2>/dev/null && [ "$minor" -ge 4 ] 2>/dev/null; then echo "12.4"; return; fi
    if [ "$major" -ge 12 ] 2>/dev/null && [ "$minor" -ge 1 ] 2>/dev/null; then echo "12.1"; return; fi
    echo "12.8"
}

# === Schritt 0: FFmpeg (laut WhisperX README) ===
check_ffmpeg
log_info_quiet "FFmpeg gefunden: $(command -v ffmpeg)"

echo ""
ui_ok "FFmpeg gefunden: $(command -v ffmpeg)"
echo ""

# === Systeminfos anzeigen (vor Installation) ===
read_system_info || true

ui_section "Systeminfos"
ui_kv "OS" "${SYS_OS_ID:-?} ${SYS_OS_VERSION:-}" ""
ui_kv "FFmpeg" "${SYS_FFMPEG_VERSION:-nicht gefunden}" ""
ui_kv "GPU" "${SYS_GPU_TYPE:-none}${SYS_CUDA_VERSION:+ ($SYS_CUDA_VERSION)}" ""
ui_log "Python (System): Auf dem System können mehrere Versionen installiert sein; Video Whisper nutzt eine kompatible (3.10–3.13)."
for py in python3.13 python3.12 python3.11 python3.10 python3; do
    if command -v "$py" &>/dev/null; then
        v=$("$py" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')" 2>/dev/null) || true
        [ -z "$v" ] && v=$("$py" --version 2>&1 | sed 's/^Python //; s/ .*//; q') || true
        ui_log "  $py → ${v:-?}"
    fi
done
if [ -n "${SYS_PYTHON_USED:-}" ] && [ -n "${SYS_PYTHON_VERSION:-}" ]; then
    ui_ok "Für Video Whisper wird genutzt: ${SYS_PYTHON_USED} (${SYS_PYTHON_VERSION})"
else
    ui_log "  Für Video Whisper: Keine kompatible Version (3.10–3.13) gefunden."
fi
ui_infobox "WhisperX-Anforderung: Python 3.10–3.13, FFmpeg, optional CUDA 12.8"
ui_divider
log_info_quiet "Systeminfos: OS=$SYS_OS_ID $SYS_OS_VERSION, FFmpeg=$SYS_FFMPEG_VERSION, GPU=$SYS_GPU_TYPE, Python(s) erfasst"

echo ""
echo ""

# === Python ermitteln (nur systemweit, koexistierend; keine portable Variante) ===
PY=$(find_compatible_python)
if [ -z "$PY" ]; then
    if ! install_system_python_compatible; then
        log_error "Kein kompatibles Python (3.10–3.13), Benutzer hat Installation abgebrochen oder fehlgeschlagen."
        exit 1
    fi
    PY=$(find_compatible_python)
fi
if [ -z "$PY" ]; then
    log_error "Nach Installation immer noch kein kompatibles Python gefunden."
    ui_fail "Kein kompatibles Python gefunden. Terminal neu öffnen oder PATH prüfen."
    exit 1
fi
log_info_quiet "Nutze System-Python: $PY"

echo ""
ui_ok "Nutze System-Python: $PY"
echo ""

# Systeminfos für State-Datei (vor Installation) – darf bei set -e nicht abbrechen
read_system_info || true

ui_step 1 4 "Alte venv entfernen"
log_info_quiet "Entferne alte venv (falls vorhanden): $SCRIPT_DIR/venv"
rm -rf "$SCRIPT_DIR/venv"
log_info_quiet "venv entfernt."
ui_ok "erledigt"
echo ""

ui_step 2 4 "Neue venv anlegen"
log_info_quiet "Erstelle venv mit: $PY -m venv $SCRIPT_DIR/venv"
log_run_cmd_spinner "venv anlegen" "venv anlegen…" "$PY" -m venv "$SCRIPT_DIR/venv"
log_run_cmd_spinner "pip install --upgrade pip" "pip aktualisieren…" "$SCRIPT_DIR/venv/bin/pip" install --upgrade pip || true
ui_ok "venv bereit"
echo ""

ui_step 3 4 "Pakete installieren (GPU optional)"
echo ""

# Für State-Datei: gewählte GPU-Option merken
INSTALL_GPU_TYPE="none"
INSTALL_CUDA_VERSION=""
# CUDA: vom Treiber unterstützte Version ermitteln und als Standard vorschlagen; sonst CPU (venv).
if command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null; then
    nvidia_name=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n1)
    cuda_recommended=$(get_recommended_cuda_for_pytorch)
    cuda_driver_raw=$(nvidia-smi 2>/dev/null | grep -oE 'CUDA Version: [0-9.]+' | head -1 | sed 's/CUDA Version: //') || cuda_driver_raw=""
    log_info_quiet "NVIDIA erkannt: $nvidia_name, Treiber-CUDA: ${cuda_driver_raw:-?}, Empfehlung: $cuda_recommended"

    ui_info "GPU erkannt: $nvidia_name"
    if [ -n "$cuda_driver_raw" ]; then
        ui_log "Treiber: CUDA $cuda_driver_raw → PyTorch mit CUDA $cuda_recommended empfohlen."
        if expr "$cuda_driver_raw" : '1[3-9]' >/dev/null 2>&1 || expr "$cuda_driver_raw" : '12\.[9]' >/dev/null 2>&1; then
            ui_log "(PyTorch unterstützt bis 12.8; Treiber $cuda_driver_raw ist kompatibel.)"
        fi
    else
        ui_log "PyTorch mit CUDA $cuda_recommended empfohlen."
    fi
    echo ""
    echo -e "  ${BOLD}GPU — CUDA-Modus ($nvidia_name)${NC}"
    echo -e "  ${DIM}Nummer eingeben (1–4), Enter = 1${NC}"
    echo ""
    echo -e "  ${GREEN} 1${NC}) PyTorch mit CUDA $cuda_recommended (GPU)  ${DIM}[empfohlen]${NC}"
    echo -e "  ${GREEN} 2${NC}) PyTorch CPU only (langsamer)"
    echo -e "  ${GREEN} 3${NC}) CUDA 12.4 explizit"
    echo -e "  ${GREEN} 4${NC}) CUDA 12.1 explizit"
    echo ""
    read -rp "$(echo -e "  ${YELLOW}→ Auswahl (1–4):${NC} ")" cuda_choice
    cuda_choice="${cuda_choice:-1}"
    case "$cuda_choice" in
        1) cuda="$cuda_recommended" ;;
        2) cuda="" ;;
        3) cuda="12.4" ;;
        4) cuda="12.1" ;;
        *) cuda="$cuda_recommended" ;;
    esac
    log_info_quiet "Benutzer-Wahl CUDA (Eingabe $cuda_choice): ${cuda:-CPU}"
    case "$cuda" in
        12.8) INSTALL_GPU_TYPE="nvidia"; INSTALL_CUDA_VERSION="12.8"
              log_run_cmd_spinner "pip install torch torchaudio (CUDA 12.8, cu128)" "PyTorch + CUDA 12.8 installieren…" "$SCRIPT_DIR/venv/bin/pip" install torch torchaudio --index-url https://download.pytorch.org/whl/cu128 ;;
        12.4) INSTALL_GPU_TYPE="nvidia"; INSTALL_CUDA_VERSION="12.4"
              log_run_cmd_spinner "pip install torch torchaudio (CUDA 12.4, cu124)" "PyTorch + CUDA 12.4 installieren…" "$SCRIPT_DIR/venv/bin/pip" install torch torchaudio --index-url https://download.pytorch.org/whl/cu124 ;;
        12.1) INSTALL_GPU_TYPE="nvidia"; INSTALL_CUDA_VERSION="12.1"
              log_run_cmd_spinner "pip install torch torchaudio (CUDA 12.1, cu121)" "PyTorch + CUDA 12.1 installieren…" "$SCRIPT_DIR/venv/bin/pip" install torch torchaudio --index-url https://download.pytorch.org/whl/cu121 ;;
        *)    log_info_quiet "PyTorch aus requirements.txt (CPU, keine CUDA-Installation)."
              ui_log "PyTorch ohne CUDA (CPU)." ;;
    esac
elif command -v rocm-smi &>/dev/null && rocm-smi &>/dev/null; then
    log_info_quiet "AMD (ROCm) erkannt – installiere PyTorch mit ROCm."
    ui_info "AMD (ROCm) erkannt – installiere PyTorch mit ROCm..."
    INSTALL_GPU_TYPE="rocm"
    log_run_cmd_spinner "pip install torch torchaudio (ROCm)" "PyTorch + ROCm installieren…" "$SCRIPT_DIR/venv/bin/pip" install torch torchaudio --index-url https://download.pytorch.org/whl/rocm6.0
else
    ui_log "Keine GPU erkannt → PyTorch ohne CUDA (CPU)."
fi

echo ""
log_info_quiet "Installation requirements.txt (WhisperX, ffmpeg-python, tqdm...)"
# Bei CUDA: gleichen PyTorch-Index mitgeben, damit pip torch~=2.8.0 als cu128/cu124/cu121 löst (nicht CPU von PyPI).
pip_extra_index=""
case "${INSTALL_CUDA_VERSION:-}" in
    12.8) pip_extra_index="--extra-index-url https://download.pytorch.org/whl/cu128" ;;
    12.4) pip_extra_index="--extra-index-url https://download.pytorch.org/whl/cu124" ;;
    12.1) pip_extra_index="--extra-index-url https://download.pytorch.org/whl/cu121" ;;
esac
if ! log_run_cmd_spinner "pip install -r requirements.txt (WhisperX und Abhängigkeiten)" "WhisperX und Abhängigkeiten installieren…" "$SCRIPT_DIR/venv/bin/pip" install $pip_extra_index -r "$SCRIPT_DIR/requirements.txt"; then
    ui_warn "Details in den Logs: $(get_log_path 2>/dev/null || echo "$SCRIPT_DIR/logs/whisper.log")"
    exit 1
fi
# Veraltetes youtube-dl entfernen (wir nutzen nur noch yt-dlp)
"$SCRIPT_DIR/venv/bin/pip" uninstall -y youtube-dl 2>/dev/null || true

# Lightning-Checkpoint einmal upgraden, damit die Meldung nicht bei jeder Transkription erscheint
pyver=$("$SCRIPT_DIR/venv/bin/python3" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null) || true
if [ -n "$pyver" ]; then
    ckpt="$SCRIPT_DIR/venv/lib/python${pyver}/site-packages/whisperx/assets/pytorch_model.bin"
    if [ -f "$ckpt" ]; then
        log_run_cmd_spinner "Lightning-Checkpoint upgraden" "Checkpoint upgraden…" "$SCRIPT_DIR/venv/bin/python3" -m lightning.pytorch.utilities.upgrade_checkpoint "$ckpt" 2>/dev/null || true
    fi
fi

# State-Datei schreiben (System + installierte Versionen)
get_venv_versions || true
installed_at=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S)
log_info_quiet "State-Datei wird geschrieben (WhisperX ${VENV_WHISPERX_VERSION:-?}, torch ${VENV_TORCH_VERSION:-?})"
write_state_file \
    "$installed_at" \
    "$PY" \
    "${VENV_PYTHON_VERSION:-$SYS_PYTHON_VERSION}" \
    "$INSTALL_GPU_TYPE" \
    "$INSTALL_CUDA_VERSION" \
    "${VENV_WHISPERX_VERSION:-}" \
    "${VENV_TORCH_VERSION:-}" \
    "false"

echo ""
ui_step 4 4 "Kurztest (optional)"
echo ""
first_test_done="false"
if [ -f "$SCRIPT_DIR/test.mp4" ]; then
    log_info_quiet "Starte Kurztest: transcribe.py test.mp4 ./txt tiny de"
    if log_run_cmd_spinner "Kurztest transcribe.py test.mp4" "Kurztest läuft…" "$SCRIPT_DIR/venv/bin/python3" "$SCRIPT_DIR/transcribe.py" "$SCRIPT_DIR/test.mp4" "$SCRIPT_DIR/txt" tiny de; then
        log_info_quiet "Kurztest erfolgreich. Ausgabe in txt/test.txt"
        echo ""
        ui_ok "Test erfolgreich. Ausgabe: txt/test.txt"
        first_test_done="true"
        write_state_file \
            "$installed_at" \
            "$PY" \
            "${VENV_PYTHON_VERSION:-$SYS_PYTHON_VERSION}" \
            "$INSTALL_GPU_TYPE" \
            "$INSTALL_CUDA_VERSION" \
            "${VENV_WHISPERX_VERSION:-}" \
            "${VENV_TORCH_VERSION:-}" \
            "true"
    else
        log_warn "Kurztest fehlgeschlagen (transcribe.py Exit != 0)."
    fi
else
    log_info_quiet "test.mp4 nicht gefunden – Kurztest übersprungen."
    ui_warn "test.mp4 nicht gefunden – übersprungen. Später: ./start.sh"
fi

# Install-Manifest schreiben (logs/install.json) für Uninstall-Referenz
log_info_quiet ">>> Schreibe install.json (Manifest)"
manifest_path=""
if write_install_manifest; then
    manifest_path="${SCRIPT_DIR}/logs/install.json"
    log_info_quiet "<<< install.json geschrieben: $manifest_path"
else
    log_warn "Schreiben des Install-Manifests fehlgeschlagen (logs/install.json)."
fi

echo ""
ui_divider
log_info_quiet "Installation abgeschlossen. Log: $(get_log_path 2>/dev/null || echo 'logs/whisper.log')"
ui_ok "Fertig. Zum Transkribieren: ./start.sh"
ui_log "Updates:  ./scripts/update.sh"
ui_log "Log:      ${LOG_FILE:-logs/whisper.log}"
[ -n "$manifest_path" ] && ui_log "Manifest: logs/install.json"
echo ""
