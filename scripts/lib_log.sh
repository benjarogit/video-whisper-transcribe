#!/usr/bin/env bash
# Video Whisper – Gemeinsames Log-System für Shell-Skripte.
# Voraussetzung: SCRIPT_DIR (Projektroot) ist gesetzt.
# Nutzung: source lib_log.sh; log_init "start.sh"; log_info "Nachricht"

# Log-Verzeichnis und -Datei (eine gemeinsame Datei, alle Skripte hängen an)
LOG_DIR="${SCRIPT_DIR:-.}/logs"
LOG_FILE=""
LOG_SCRIPT_NAME=""

# Optional: Farben für Konsolen-Ausgabe (falls nicht gesetzt)
[ -z "${LOG_NC:-}" ] && LOG_NC='\033[0m'
[ -z "${LOG_RED:-}" ] && LOG_RED='\033[0;31m'
[ -z "${LOG_GREEN:-}" ] && LOG_GREEN='\033[0;32m'
[ -z "${LOG_YELLOW:-}" ] && LOG_YELLOW='\033[1;33m'
[ -z "${LOG_BLUE:-}" ] && LOG_BLUE='\033[0;34m'

# Initialisiert das Log-System. Aufruf: log_init "Skriptname" (z. B. "start.sh", "install.sh")
# Vor dem ersten Schreiben: vorhandenes whisper.log → whisper.old.log (nur wenn nicht schon in diesem Lauf rotiert).
log_init() {
    LOG_SCRIPT_NAME="${1:-shell}"
    LOG_FILE="${LOG_DIR}/whisper.log"
    mkdir -p "$LOG_DIR"
    if [ -z "${VIDEO_WHISPER_LOG_ROTATED:-}" ] && [ -f "$LOG_FILE" ]; then
        mv -f "$LOG_FILE" "${LOG_DIR}/whisper.old.log" 2>/dev/null || true
        export VIDEO_WHISPER_LOG_ROTATED=1
    fi
    _log_write "INFO" "--- Log gestartet: $LOG_SCRIPT_NAME ---"
}

# Schreibt eine Zeile in die Log-Datei (Timestamp, Level, Skript, Nachricht)
_log_write() {
    local level="$1"
    shift
    local msg="$*"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${ts}] [${level}] [${LOG_SCRIPT_NAME}] ${msg}" >> "${LOG_FILE}" 2>/dev/null || true
}

# Info: in Log-Datei + optional auf stdout (mit Farbe)
log_info() {
    _log_write "INFO" "$@"
    echo -e "${LOG_BLUE}ℹ${LOG_NC} $*"
}

# Wie log_info, aber ohne Echo (nur in Datei) – für viele Zeilen, die nur protokolliert werden sollen
log_info_quiet() {
    _log_write "INFO" "$@"
}

# Warnung: in Log-Datei + stderr
log_warn() {
    _log_write "WARN" "$@"
    echo -e "${LOG_YELLOW}⚠${LOG_NC} $*" >&2
}

# Fehler: in Log-Datei + stderr
log_error() {
    _log_write "ERROR" "$@"
    echo -e "${LOG_RED}✗${LOG_NC} $*" >&2
}

# Nur in Datei schreiben (z. B. für Debug oder mehrzeilige Ausgaben)
log_write() {
    local level="${1:-INFO}"
    shift
    _log_write "$level" "$@"
}

# Gibt den Pfad zur aktuellen Log-Datei zurück (für Hinweise an den User)
get_log_path() {
    echo "${LOG_FILE}"
}

# Führt einen Befehl aus und schreibt die komplette Ausgabe (stdout+stderr) zeilenweise ins Log (Level INSTALL).
# Aufruf: log_run_cmd "Kurzbeschreibung" cmd arg1 arg2 ...
# Gibt Exit-Code des Befehls zurück. Ausgabe erscheint weiterhin auf der Konsole.
log_run_cmd() {
    local desc="$1"
    shift
    [ $# -eq 0 ] && return 0
    _log_write "INFO" ">>> $desc"
    local tmp
    tmp=$(mktemp 2>/dev/null) || tmp="/tmp/vw_log_$$.tmp"
    "$@" 2>&1 | tee "$tmp"
    local ec=${PIPESTATUS[0]}
    while IFS= read -r line; do
        _log_write "INSTALL" "$line"
    done < "$tmp" 2>/dev/null
    rm -f "$tmp" 2>/dev/null
    _log_write "INFO" "<<< Ende: $desc (Exit: $ec)"
    return $ec
}

# Wie log_run_cmd, aber mit Spinner: Ausgabe nur ins Log, auf der Konsole nur Spinner + abschließend ✓/Fehler.
# Für längere Aktionen (Installieren, Download, Entpacken). Erfordert ui_spinner (scripts/ui.sh).
# Aufruf: log_run_cmd_spinner "Kurzbeschreibung für Log" "Spinner-Text (z.B. Pakete installieren…)" cmd arg1 arg2 ...
log_run_cmd_spinner() {
    local desc="$1" msg="$2"
    shift 2
    [ $# -eq 0 ] && return 0
    _log_write "INFO" ">>> $desc"
    local tmp tmp_ec
    tmp=$(mktemp 2>/dev/null) || tmp="/tmp/vw_log_$$.tmp"
    tmp_ec="${tmp}.ec"
    ( "$@" 2>&1; echo $? > "$tmp_ec" ) > "$tmp" &
    local pid=$!
    if type ui_spinner &>/dev/null; then
        ui_spinner "$pid" "$msg" "$tmp"
    else
        wait "$pid" 2>/dev/null || true
        echo -e "  ${LOG_GREEN}✓${LOG_NC} $msg"
    fi
    local ec=1
    [ -f "$tmp_ec" ] && ec=$(cat "$tmp_ec" 2>/dev/null) || true
    while IFS= read -r line; do
        _log_write "INSTALL" "$line"
    done < "$tmp" 2>/dev/null
    rm -f "$tmp" "$tmp_ec" 2>/dev/null
    _log_write "INFO" "<<< Ende: $desc (Exit: $ec)"
    return $ec
}
