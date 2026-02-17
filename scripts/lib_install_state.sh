#!/usr/bin/env bash
# Video Whisper – Gemeinsame Bibliothek für Installations- und Kompatibilitäts-State.
# Von start.sh, scripts/install.sh, scripts/update.sh zu sourcen.
# Voraussetzung: SCRIPT_DIR (Projektroot) und ggf. VENV_PATH sind gesetzt.
# State-Datei: ${SCRIPT_DIR}/.video_whisper_state (key=value, eine Zeile pro Key).

# State-Datei-Pfad (Projektroot)
get_state_path() {
    echo "${SCRIPT_DIR}/.video_whisper_state"
}

# Prüft, ob Video Whisper installiert ist (venv existiert + whisperx importierbar).
# Rückgabe: 0 = installiert, 1 = nicht installiert
is_installed() {
    local venv_path="${VENV_PATH:-${SCRIPT_DIR}/venv}"
    if [ ! -d "$venv_path" ] || [ ! -x "${venv_path}/bin/python3" ]; then
        return 1
    fi
    if ! "${venv_path}/bin/python3" -c "import whisperx" 2>/dev/null; then
        return 1
    fi
    return 0
}

# WhisperX-Anforderungen (zentral, laut README github.com/m-bain/whisperX)
# Python 3.10–3.13, FFmpeg erforderlich, CUDA 12.8 optional
whisperx_requirements() {
    echo "WX_PYTHON_MIN=3.10"
    echo "WX_PYTHON_MAX=3.13"
    echo "WX_FFMPEG_REQUIRED=1"
    echo "WX_CUDA_OPTIONAL=12.8"
}

# Prüft, ob eine Python-Version (major.minor) im WhisperX-Bereich liegt
# Aufruf: python_version_in_range "3.12"  -> 0 wenn 3.10<=x<=3.13
python_version_in_range() {
    local ver="$1"
    local major minor
    major="${ver%%.*}"; minor="${ver#*.}"
    [ "$major" -eq 3 ] 2>/dev/null || return 1
    [ "$minor" -ge 10 ] 2>/dev/null || return 1
    [ "$minor" -le 13 ] 2>/dev/null || return 1
    return 0
}

# Liest Systeminfos (nur lesend). Setzt globale Variablen:
# SYS_OS_ID, SYS_OS_VERSION, SYS_PYTHON_USED, SYS_PYTHON_VERSION, SYS_FFMPEG_VERSION,
# SYS_GPU_TYPE, SYS_CUDA_VERSION (nur bei NVIDIA)
read_system_info() {
    SYS_OS_ID=""
    SYS_OS_VERSION=""
    SYS_PYTHON_USED=""
    SYS_PYTHON_VERSION=""
    SYS_FFMPEG_VERSION=""
    SYS_GPU_TYPE="none"
    SYS_CUDA_VERSION=""

    if [ -f /etc/os-release ]; then
        SYS_OS_ID=$(grep -E '^ID=' /etc/os-release 2>/dev/null | head -1 | cut -d= -f2 | tr -d '"') || SYS_OS_ID=""
        SYS_OS_VERSION=$(grep -E '^VERSION_ID=' /etc/os-release 2>/dev/null | head -1 | cut -d= -f2 | tr -d '"') || SYS_OS_VERSION=""
    fi

    if command -v ffmpeg &>/dev/null; then
        SYS_FFMPEG_VERSION=$(ffmpeg -version 2>/dev/null | head -1 | sed 's/^ffmpeg version //' | cut -d' ' -f1) || SYS_FFMPEG_VERSION=""
        [ -z "$SYS_FFMPEG_VERSION" ] && SYS_FFMPEG_VERSION="unknown"
    fi

    for py in python3.13 python3.12 python3.11 python3.10 python3; do
        if command -v "$py" &>/dev/null; then
            local v
            v=$("$py" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null) || true
            if [ -n "$v" ] && python_version_in_range "$v"; then
                SYS_PYTHON_USED="$py"
                SYS_PYTHON_VERSION="$v"
                break
            fi
        fi
    done

    if command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null; then
        SYS_GPU_TYPE="nvidia"
        SYS_CUDA_VERSION=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1) || SYS_CUDA_VERSION="unknown"
        [ -z "$SYS_CUDA_VERSION" ] && SYS_CUDA_VERSION="unknown"
    elif command -v rocm-smi &>/dev/null && rocm-smi &>/dev/null; then
        SYS_GPU_TYPE="rocm"
    fi
    return 0
}

# Schreibt die State-Datei. Argumente: installed_at, python_used, python_version,
# gpu_type, cuda_version, whisperx_version, torch_version, (optional) first_test_done
# Vor dem Aufruf sollten read_system_info und die installierten Versionen (aus venv) bekannt sein.
# Aufruf: write_state_file "2025-02-17T12:00:00" "python3.12" "3.12" "nvidia" "12.8" "3.8.0" "2.5.0"
write_state_file() {
    local installed_at="$1"
    local python_used="$2"
    local python_version="$3"
    local gpu_type="${4:-none}"
    local cuda_version="${5:-}"
    local whisperx_version="${6:-}"
    local torch_version="${7:-}"
    local first_test_done="${8:-false}"
    local state_path
    state_path=$(get_state_path)
    cat > "$state_path" << EOF
installed_at=$installed_at
system_os_id=$SYS_OS_ID
system_os_version=$SYS_OS_VERSION
system_python_used=$python_used
system_python_version=$python_version
system_ffmpeg_version=$SYS_FFMPEG_VERSION
system_gpu_type=$gpu_type
system_cuda_version=$cuda_version
installed_whisperx_version=$whisperx_version
installed_torch_version=$torch_version
installed_python_version=$python_version
first_test_done=$first_test_done
EOF
}

# Liest die State-Datei und setzt globale Variablen mit Präfix STATE_
# STATE_installed_at, STATE_system_os_id, ... (Key ohne "STATE_" wird zu STATE_key)
read_state_file() {
    local state_path
    state_path=$(get_state_path)
    STATE_installed_at=""
    STATE_system_os_id=""
    STATE_system_os_version=""
    STATE_system_python_used=""
    STATE_system_python_version=""
    STATE_system_ffmpeg_version=""
    STATE_system_gpu_type=""
    STATE_system_cuda_version=""
    STATE_installed_whisperx_version=""
    STATE_installed_torch_version=""
    STATE_installed_python_version=""
    STATE_first_test_done=""
    [ ! -f "$state_path" ] && return 1
    while IFS= read -r line; do
        [[ "$line" =~ ^#.*$ ]] && continue
        [[ ! "$line" =~ = ]] && continue
        local key="${line%%=*}"
        local val="${line#*=}"
        key="${key//-/_}"
        case "$key" in
            installed_at) STATE_installed_at="$val" ;;
            system_os_id) STATE_system_os_id="$val" ;;
            system_os_version) STATE_system_os_version="$val" ;;
            system_python_used) STATE_system_python_used="$val" ;;
            system_python_version) STATE_system_python_version="$val" ;;
            system_ffmpeg_version) STATE_system_ffmpeg_version="$val" ;;
            system_gpu_type) STATE_system_gpu_type="$val" ;;
            system_cuda_version) STATE_system_cuda_version="$val" ;;
            installed_whisperx_version) STATE_installed_whisperx_version="$val" ;;
            installed_torch_version) STATE_installed_torch_version="$val" ;;
            installed_python_version) STATE_installed_python_version="$val" ;;
            first_test_done) STATE_first_test_done="$val" ;;
        esac
    done < "$state_path"
    return 0
}

# Liest aus der venv die Versionen von whisperx und torch (für State-Aktualisierung)
get_venv_versions() {
    local venv_path="${VENV_PATH:-${SCRIPT_DIR}/venv}"
    VENV_WHISPERX_VERSION=""
    VENV_TORCH_VERSION=""
    VENV_PYTHON_VERSION=""
    [ ! -x "${venv_path}/bin/python3" ] && return 1
    VENV_WHISPERX_VERSION=$("${venv_path}/bin/pip" show whisperx 2>/dev/null | grep -E '^Version:' | cut -d' ' -f2)
    VENV_TORCH_VERSION=$("${venv_path}/bin/pip" show torch 2>/dev/null | grep -E '^Version:' | cut -d' ' -f2)
    VENV_PYTHON_VERSION=$("${venv_path}/bin/python3" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null)
    return 0
}

# Schreibt das Install-Manifest nach logs/install.json (Meta, System, system_packages_installed, Projektpfade, pip_freeze).
# Voraussetzung: SCRIPT_DIR, VENV_PATH, SYS_* gesetzt; optional INSTALLED_SYSTEM_PACKAGES_JSON (z.B. '[{"manager":"pacman","packages":["python312"]}]').
# Wird von install.sh am Ende der Installation aufgerufen. Logging erfolgt im Aufrufer.
write_install_manifest() {
    local venv_path="${VENV_PATH:-${SCRIPT_DIR}/venv}"
    local log_dir="${SCRIPT_DIR}/logs"
    local manifest_file="${log_dir}/install.json"
    mkdir -p "$log_dir"

    [ ! -x "${venv_path}/bin/python3" ] && return 1

    CREATED_AT=$(date -Iseconds 2>/dev/null) || CREATED_AT=$(date +%Y-%m-%dT%H:%M:%S 2>/dev/null)
    MANIFEST_FILE="$manifest_file"
    export SCRIPT_DIR VENV_PATH CREATED_AT MANIFEST_FILE
    export SYS_OS_ID SYS_OS_VERSION SYS_FFMPEG_VERSION SYS_GPU_TYPE SYS_CUDA_VERSION
    export INSTALLED_SYSTEM_PACKAGES_JSON="${INSTALLED_SYSTEM_PACKAGES_JSON:-[]}"

    "${venv_path}/bin/python3" << 'PYEOF'
import json
import os
import subprocess

script_dir = os.environ.get("SCRIPT_DIR", "")
venv_path = os.environ.get("VENV_PATH", script_dir + "/venv") if script_dir else os.environ.get("VENV_PATH", "")
created_at = os.environ.get("CREATED_AT", "")
sys_packages_raw = os.environ.get("INSTALLED_SYSTEM_PACKAGES_JSON", "[]")

try:
    system_packages_installed = json.loads(sys_packages_raw)
except json.JSONDecodeError:
    system_packages_installed = []

pip_freeze_out = subprocess.run(
    [os.path.join(venv_path, "bin", "pip"), "freeze"],
    capture_output=True, text=True, timeout=60, cwd=script_dir or None
)
pip_freeze_lines = pip_freeze_out.stdout.strip().split("\n") if pip_freeze_out.stdout else []

data = {
    "created_at": created_at,
    "script_version": "install.sh",
    "project_dir": script_dir,
    "system_os_id": os.environ.get("SYS_OS_ID", ""),
    "system_os_version": os.environ.get("SYS_OS_VERSION", ""),
    "system_ffmpeg_version": os.environ.get("SYS_FFMPEG_VERSION", ""),
    "system_gpu_type": os.environ.get("SYS_GPU_TYPE", ""),
    "system_cuda_version": os.environ.get("SYS_CUDA_VERSION", ""),
    "system_packages_installed": system_packages_installed,
    "venv_path": venv_path,
    "state_path": script_dir + "/.video_whisper_state",
    "requirements_path": script_dir + "/requirements.txt",
    "paths_created": ["venv", "logs", "txt", ".video_whisper_state"],
    "pip_freeze": pip_freeze_lines,
}

with open(os.environ.get("MANIFEST_FILE", ""), "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
PYEOF
    local ec=$?
    [ $ec -eq 0 ] && echo "$manifest_file" || return $ec
}
