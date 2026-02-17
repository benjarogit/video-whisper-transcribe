#!/usr/bin/env bash
# Video Whisper – Launcher (Menü: Datei, Modell, Sprache → Transkription).
# Wann: Immer zum Transkribieren. Prüft, ob installiert (sonst startet scripts/install.sh) und ob Updates verfügbar.

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly VENV_PATH="${SCRIPT_DIR}/venv"
readonly OUTPUT_PATH="${SCRIPT_DIR}/txt"
readonly DEFAULT_MODEL="small"

# shellcheck source=scripts/ui.sh
source "${SCRIPT_DIR}/scripts/ui.sh"
# Gemeinsame State-Lib (optional: State-Info anzeigen)
# shellcheck source=scripts/lib_install_state.sh
source "${SCRIPT_DIR}/scripts/lib_install_state.sh" 2>/dev/null || true
# Log-System (optional). Bei Start: aktuelles whisper.log → whisper.old.log, dann neues whisper.log
mkdir -p "${SCRIPT_DIR}/logs"
[ -f "${SCRIPT_DIR}/logs/whisper.log" ] && mv -f "${SCRIPT_DIR}/logs/whisper.log" "${SCRIPT_DIR}/logs/whisper.old.log" 2>/dev/null || true
export VIDEO_WHISPER_LOG_ROTATED=1
# shellcheck source=scripts/lib_log.sh
source "${SCRIPT_DIR}/scripts/lib_log.sh" 2>/dev/null || true
if type log_init &>/dev/null; then
    log_init "start.sh"
fi

# Supported file extensions
readonly AUDIO_VIDEO_EXTENSIONS="mp3|wav|m4a|flac|aac|ogg|opus|mp4|mkv|avi|mov|webm|wmv"

# Welches Python für die venv nutzen. Mehrere Python-Versionen systemweit sind üblich – wir nutzen 3.10–3.13 (WhisperX: github.com/m-bain/whisperX).
get_venv_python() {
    if [ -n "${VIDEO_WHISPER_PYTHON:-}" ]; then
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
    ui_fail "Kein kompatibles Python. WhisperX benötigt 3.10–3.13 (nicht 3.14+)."
    ui_info "Python 3.12 oder 3.13 systemweit installieren:"
    ui_log "Arch (AUR):  yay -S python312"
    ui_log "Debian:      sudo apt install python3.12 python3.12-venv"
    ui_log "Danach erneut: ./start.sh"
    exit 1
}

# Check Python version nur wenn venv existiert (WhisperX 3.10–3.13).
# Ohne venv startet require_installed() → install.sh, der Python findet oder anbietet.
check_python_version() {
    if [ ! -d "$VENV_PATH" ] || [ ! -x "${VENV_PATH}/bin/python3" ]; then
        return 0
    fi
    local v
    v=$("${VENV_PATH}/bin/python3" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null) || true
    if [ -z "$v" ]; then return 0; fi
    local major minor
    major="${v%%.*}"; minor="${v#*.}"
    if [ "$major" -eq 3 ] && [ "$minor" -ge 14 ]; then
        ui_fail "Python $v (in venv) wird nicht unterstützt. WhisperX benötigt 3.10–3.13."
        ui_log "venv löschen und mit kompatiblem Python neu anlegen: rm -rf venv && ./start.sh"
        ui_log "Vorher z.B. python3.12 systemweit: yay -S python312"
        exit 1
    fi
}

# Check dependencies: nur FFmpeg (Pflicht). Python 3.10–3.13 prüfen wir nur bei bestehender venv;
# ohne venv übernimmt install.sh das (findet oder bietet Installation an).
check_dependencies() {
    if ! command -v ffmpeg &>/dev/null; then
        ui_fail "FFmpeg fehlt. WhisperX benötigt FFmpeg."
        ui_info "sudo pacman -S ffmpeg (Arch) bzw. sudo apt install ffmpeg (Debian/Ubuntu)"
        exit 1
    fi
    check_python_version
}

# Prüft, ob Video Whisper installiert ist (venv + WhisperX). Wenn nicht: install.sh ausführen, dann weitermachen.
# Setzt JUST_RAN_INSTALL=1, wenn in diesem Lauf install.sh ausgeführt wurde (für Unterdrückung des "Updates verfügbar"-Hinweises).
require_installed() {
    if [ ! -d "$VENV_PATH" ] || [ ! -x "${VENV_PATH}/bin/python3" ]; then
        ui_info "Noch nicht installiert. Starte Installation (scripts/install.sh)..."
        log_info_quiet "Nicht installiert (kein venv). Starte install.sh" 2>/dev/null || true
        echo ""
        if ! "${SCRIPT_DIR}/scripts/install.sh"; then
            log_error "Installation fehlgeschlagen." 2>/dev/null || true
            ui_fail "Installation fehlgeschlagen."
            ui_warn "Details in den Logs: $(get_log_path 2>/dev/null || echo "${SCRIPT_DIR}/logs/whisper.log")"
            exit 1
        fi
        log_info_quiet "Installation abgeschlossen, weiter mit Menü." 2>/dev/null || true
        ui_ok "Installation abgeschlossen. Weiter mit Transkription."
        JUST_RAN_INSTALL=1
        echo ""
        return 0
    fi
    if ! "${VENV_PATH}/bin/python3" -c "import whisperx" 2>/dev/null; then
        ui_info "WhisperX fehlt in der venv. Starte Installation (scripts/install.sh)..."
        log_info_quiet "WhisperX fehlt in venv. Starte install.sh" 2>/dev/null || true
        echo ""
        if ! "${SCRIPT_DIR}/scripts/install.sh"; then
            log_error "Installation fehlgeschlagen (WhisperX)." 2>/dev/null || true
            ui_fail "Installation fehlgeschlagen."
            ui_warn "Details in den Logs: $(get_log_path 2>/dev/null || echo "${SCRIPT_DIR}/logs/whisper.log")"
            exit 1
        fi
        ui_ok "Installation abgeschlossen. Weiter mit Transkription."
        JUST_RAN_INSTALL=1
        echo ""
        return 0
    fi
}

# Zeigt einen Hinweis nur bei für uns relevanten Updates (WhisperX, ffmpeg-python, tqdm).
# torch/torchaudio bewusst nicht: Version hängt an WhisperX; neuere PyPI-Version wäre für unseren Stack nicht passend.
check_updates_available() {
    local outdated
    outdated=$("${VENV_PATH}/bin/pip" list --outdated 2>/dev/null | grep -iE "^(whisperx|ffmpeg-python|tqdm)[[:space:]]" || true)
    if [ -n "$outdated" ]; then
        ui_warn "Updates verfügbar (WhisperX/Zusätze). Führe ./scripts/update.sh aus."
        echo ""
    fi
}

# Find media files (one path per line for correct readarray)
find_media_files() {
    local -a files
    mapfile -t files < <(find "$SCRIPT_DIR" -maxdepth 1 -type f -regextype posix-extended \
        -iregex ".*\.(${AUDIO_VIDEO_EXTENSIONS})$" | sort)
    
    printf '%s\n' "${files[@]}"
}

# Select file interactively; write selected path to SELECTED_FILE (temp file path)
select_file() {
    local selected_out="$1"
    local -a files
    readarray -t files <<< "$(find_media_files)"
    
    if [ ${#files[@]} -eq 0 ] || [ -z "${files[0]:-}" ]; then
        ui_fail "Keine Audio- oder Videodateien gefunden"
        ui_log "Unterstützte Formate: ${AUDIO_VIDEO_EXTENSIONS}"
        exit 1
    fi

    echo -e "${BOLD}${YELLOW}Datei wählen${NC}" >&2
    echo -e "${DIM}Nummer eingeben (1–${#files[@]}). Bereits vorhandene Transkription (txt/) wird überschrieben.${NC}" >&2
    echo "" >&2
    for i in "${!files[@]}"; do
        local filename
        filename=$(basename "${files[$i]}")
        local base="${filename%.*}"
        local filesize
        filesize=$(du -h "${files[$i]}" | cut -f1)
        local suffix=""
        [ -f "$OUTPUT_PATH/${base}.txt" ] && suffix=" ${DIM}[bereits transkribiert]${NC}"
        printf "  ${GREEN}%2d${NC}) %-50s ${DIM}%s${NC}%b\n" $((i + 1)) "$filename" "[$filesize]" "$suffix" >&2
    done
    echo "" >&2
    while true; do
        read -rp "$(echo -e "${YELLOW}→ Auswahl (1–${#files[@]}):${NC} ")" selection
        if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#files[@]}" ]; then
            printf '%s\n' "${files[$((selection - 1))]}" > "$selected_out"
            return 0
        fi
        ui_fail "Ungültige Auswahl. Bitte Zahl zwischen 1 und ${#files[@]} eingeben."
    done
}

# Select model
select_model() {
    local models=("tiny" "base" "small" "medium" "large" "large-v2" "large-v3")
    local descriptions=(
        "Sehr schnell, niedrige Qualität (~1GB VRAM)"
        "Schnell, okay Qualität (~1GB VRAM)"
        "Ausgewogen (Standard) (~2GB VRAM)"
        "Langsam, gute Qualität (~5GB VRAM)"
        "Sehr langsam, beste Qualität (~10GB VRAM)"
        "Large V2 - verbessert (~10GB VRAM)"
        "Large V3 - neueste Version (~10GB VRAM)"
    )
    
    echo -e "${BOLD}${YELLOW}Modell wählen${NC}" >&2
    echo -e "${DIM}Nummer (1–${#models[@]}), Enter = Standard ($DEFAULT_MODEL)${NC}" >&2
    echo "" >&2
    for i in "${!models[@]}"; do
        local marker=""
        [ "${models[$i]}" = "$DEFAULT_MODEL" ] && marker=" ${GREEN}[Standard]${NC}"
        printf "  ${GREEN}%d${NC}) %-12s  ${DIM}%s${NC}%s\n" $((i + 1)) "${models[$i]}" "${descriptions[$i]}" "$marker" >&2
    done
    echo "" >&2
    read -rp "$(echo -e "${YELLOW}→ Auswahl (1–${#models[@]}):${NC} ")" selection
    
    if [ -z "$selection" ]; then
        echo "$DEFAULT_MODEL"
    elif [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#models[@]}" ]; then
        echo "${models[$((selection - 1))]}"
    else
        ui_warn "Ungültige Auswahl, verwende Standard: $DEFAULT_MODEL"
        echo "$DEFAULT_MODEL"
    fi
}

# Select language
select_language() {
    local languages=("auto" "de" "en" "fr" "es" "it" "pt" "ru" "ja" "zh")
    local descriptions=(
        "Automatische Erkennung"
        "Deutsch"
        "Englisch"
        "Französisch"
        "Spanisch"
        "Italienisch"
        "Portugiesisch"
        "Russisch"
        "Japanisch"
        "Chinesisch"
    )
    
    echo -e "${BOLD}${YELLOW}Sprache wählen${NC}" >&2
    echo -e "${DIM}Nummer (1–${#languages[@]}), Enter = automatische Erkennung${NC}" >&2
    echo "" >&2
    for i in "${!languages[@]}"; do
        local marker=""
        [ "${languages[$i]}" = "auto" ] && marker=" ${GREEN}[Standard]${NC}"
        printf "  ${GREEN}%2d${NC}) %-6s  ${DIM}%s${NC}%s\n" $((i + 1)) "${languages[$i]}" "${descriptions[$i]}" "$marker" >&2
    done
    echo "" >&2
    read -rp "$(echo -e "${YELLOW}→ Auswahl (1–${#languages[@]}):${NC} ")" selection
    
    if [ -z "$selection" ]; then
        echo ""  # auto = empty string for Python script
    elif [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#languages[@]}" ]; then
        local lang="${languages[$((selection - 1))]}"
        [ "$lang" = "auto" ] && echo "" || echo "$lang"
    else
        ui_warn "Ungültige Auswahl, verwende automatische Erkennung"
        echo ""
    fi
}

# Main function
main() {
    local selected_file
    selected_file=$(mktemp)
    trap 'rm -f "'"$selected_file"'"' EXIT

    ui_header "Video Whisper – Transkriptions-Tool"

    # Check dependencies (FFmpeg, Python systemweit)
    check_dependencies

    # Muss bereits installiert sein (venv + WhisperX)
    require_installed

    # Optional: kurze State-Info anzeigen (Installation vom …, Python, WhisperX)
    state_path=""
    if type get_state_path &>/dev/null; then
        state_path=$(get_state_path)
    fi
    if [ -n "$state_path" ] && [ -f "$state_path" ]; then
        read_state_file 2>/dev/null || true
        if [ -n "${STATE_installed_at:-}" ]; then
            ui_log "Installation vom ${STATE_installed_at%%T*} · Python ${STATE_installed_python_version:-?} · WhisperX ${STATE_installed_whisperx_version:-?}"
            echo ""
        fi
    fi

    # Hinweis, falls Paket-Updates verfügbar (nicht direkt nach gerade durchgeführter Installation)
    if [ -z "${JUST_RAN_INSTALL:-}" ]; then
        check_updates_available
    fi

    # Create output directory
    mkdir -p "$OUTPUT_PATH"

    # Interactive selections (write path to temp file to avoid stdout/stderr mixing)
    ui_section "Schritt 1: Datei"
    select_file "$selected_file"
    local file_path
    file_path=$(cat "$selected_file")
    ui_ok "$(basename "$file_path")"
    echo ""

    ui_section "Schritt 2: Modell"
    local model
    model=$(select_model)
    ui_ok "$model"
    echo ""

    ui_section "Schritt 3: Sprache"
    local language
    language=$(select_language)
    if [ -z "$language" ]; then
        ui_ok "Automatisch"
    else
        ui_ok "$language"
    fi
    echo ""

    # Start transcription (use venv python directly)
    ui_divider
    ui_info "Transkription starten"
    ui_divider
    echo ""

    "${VENV_PATH}/bin/python3" "${SCRIPT_DIR}/transcribe.py" "$file_path" "$OUTPUT_PATH" "$model" "$language"

    local exit_code=$?
    echo ""
    if [ $exit_code -eq 0 ]; then
        ui_ok "Transkription abgeschlossen."
        ui_log "Ausgabe: ${OUTPUT_PATH}/"
    else
        ui_fail "Transkription fehlgeschlagen (Exit: $exit_code)"
    fi
    echo ""

    # Keep terminal open if running in terminal
    if [ -t 0 ]; then
        read -rp "$(echo -e "${DIM}Drücke Enter zum Beenden…${RESET}")"
        echo ""
    fi
}

# Run main function
main "$@"

