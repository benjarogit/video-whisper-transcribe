**English** | [Deutsch](README_DE.md)

---

# 🎙️ Video Whisper – Audio/Video Transcription Tool

A modern, user-friendly tool for automatic transcription of audio and video files using WhisperX and OpenAI Whisper.

**Linux only** – Windows/macOS are not supported.

## ✨ Features

- 🎯 **Automatic speech recognition** – Supports 10+ languages
- 📝 **Timestamps** – Precise segment-level timestamps
- 🚀 **GPU acceleration** – Automatic CUDA/ROCm detection
- 💻 **CPU fallback** – Works without a GPU
- 🎨 **Modern CLI** – Coloured, interactive interface
- 📊 **Progress display** – Real-time transcription status
- 📁 **Batch processing** – Transcribe multiple files in sequence
- 🔗 **URL download** – Enter a YouTube (or other) URL; download as video or MP3, then transcribe (via [youtube-dl](https://github.com/ytdl-org/youtube-dl))

## 🎬 Supported formats

**Audio:** MP3, WAV, M4A, FLAC, AAC, OGG, OPUS  
**Video:** MP4, MKV, AVI, MOV, WebM, WMV

## 📋 Requirements (Linux)

See [WhisperX README – Setup](https://github.com/m-bain/whisperX) (CUDA 12.8 optional; FFmpeg required).

- **Python 3.10–3.13** (WhisperX does not support 3.14+). Having multiple system Python versions (e.g. 3.12 or 3.13 alongside the default) is common.
- **FFmpeg** (system package; must be installed)
- Optional: **CUDA 12.8** for GPU

### Multiple Python versions (coexisting)

On Linux you can have several Python versions installed (e.g. `python3` = 3.14 and `python3.12` = 3.12). The **venv** uses only a compatible version; your system Python is unchanged.

**If no compatible Python (3.10–3.13) is installed:** Run `./start.sh` (starts installation if needed) or `./scripts/install.sh`. The script detects your distro (Arch, Debian/Ubuntu, Fedora, OpenSUSE) and can offer to install a compatible version **system-wide**; for NVIDIA/AMD it can install PyTorch with CUDA/ROCm.

**Manual install (optional):**

```bash
# Arch Linux / CachyOS (AUR)
yay -S python312

# Debian / Ubuntu
sudo apt install python3.12 python3.12-venv
```

Then run `./start.sh` or `./scripts/install.sh` again in the project folder; it will detect `python3.12` or `python3.13`.

### System packages

```bash
# Arch Linux / CachyOS
yay -S python312 ffmpeg
# or minimal
sudo pacman -S python ffmpeg

# Debian / Ubuntu
sudo apt install python3.12 python3.12-venv ffmpeg

# Fedora
sudo dnf install python3 python3-pip ffmpeg
```

### Optional: GPU support

**NVIDIA CUDA (WhisperX: CUDA 12.8):**
```bash
# https://docs.nvidia.com/cuda/cuda-installation-guide-linux/
# Arch/CachyOS example
sudo pacman -S nvidia cuda
```
The install script offers PyTorch with CUDA 12.8 / 12.4 / 12.1 (cu128/cu124/cu121).

**AMD ROCm:** See AMD ROCm documentation.

## Scripts overview

| Script | Purpose | When to use |
|--------|---------|-------------|
| **scripts/install.sh** | **One-time setup:** Checks system (Python 3.10–3.13, optional system install), creates venv, asks for PyTorch with CUDA/ROCm on NVIDIA/AMD, installs all packages (WhisperX, torch, …), writes `logs/install.json`. | First install or full reset. |
| **scripts/update.sh** | **Not an installer.** Expects existing venv. Shows status, updates packages only (`pip install -r requirements.txt`). | Regular updates or after install. |
| **scripts/uninstall.sh** | **Full teardown:** Removes venv, state, txt, logs (reads `logs/install.json`); optionally removes install-time system packages. Logged in whisper.log. | Factory reset / uninstall. |
| **start.sh** | **Daily use:** Checks if installed; if not, runs `scripts/install.sh`. Shows update hint. Menu for file, model, language; starts transcription. | Always use for transcribing. |

**Recommended first-time flow:**
1. **Install** – `./start.sh` (runs install if needed) or `./scripts/install.sh`.
2. **Update** – `./scripts/update.sh`.
3. **First run** – `./start.sh` and pick a file (or `./venv/bin/python3 transcribe.py test.mp4 ./txt small en`).

---

## 🚀 Installation

1. Install **Python 3.12 or 3.13** (see above, e.g. `yay -S python312` or `apt install python3.12 python3.12-venv`).

2. **Change to project directory**
```bash
cd "/path/to/Video Whisper"
```

3. **Create venv and install dependencies** (once)
```bash
./scripts/install.sh
```
Detects `python3.12`/`python3.13`; on NVIDIA/AMD you get a prompt for PyTorch with CUDA or ROCm.

**Manual (if desired):**
```bash
./venv/bin/pip install --upgrade pip
./venv/bin/pip install -r requirements.txt
# With NVIDIA GPU: install torch/torchaudio for cu128/cu124/cu121 first, then requirements.txt
```

**For AMD GPU (ROCm):**
```bash
./venv/bin/pip install --upgrade pip
./venv/bin/pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.0
./venv/bin/pip install -r requirements.txt
```

**Note:** `./start.sh` checks if already installed; if not, it runs `scripts/install.sh` automatically.

## 🎯 Usage

### Interactive mode (recommended)

```bash
./start.sh
```

The script runs in Bash and guides you through:
1. **File or URL:** Pick a local file, or enter a URL (e.g. YouTube) to download as video (MP4) or audio (MP3), then transcribe it
2. Model choice (tiny to large-v3)
3. Language choice (or auto-detect)

### Direct call (without activating venv)

```bash
./venv/bin/python3 transcribe.py <input_file> <output_dir> [model] [language]
```

**Examples:**
```bash
# Defaults (small model, auto-detect)
./venv/bin/python3 transcribe.py video.mp4 ./txt

# Specific model
./venv/bin/python3 transcribe.py audio.mp3 ./txt medium

# Model and language
./venv/bin/python3 transcribe.py interview.mp4 ./txt large-v3 en
```

## 🧠 Model overview

| Model | Size | VRAM | Speed | Quality |
|-------|------|------|-------|---------|
| `tiny` | ~1GB | ~1GB | ⚡⚡⚡⚡⚡ | ⭐⭐ |
| `base` | ~1GB | ~1GB | ⚡⚡⚡⚡ | ⭐⭐⭐ |
| `small` | ~2GB | ~2GB | ⚡⚡⚡ | ⭐⭐⭐⭐ |
| `medium` | ~5GB | ~5GB | ⚡⚡ | ⭐⭐⭐⭐⭐ |
| `large` | ~10GB | ~10GB | ⚡ | ⭐⭐⭐⭐⭐ |
| `large-v2` | ~10GB | ~10GB | ⚡ | ⭐⭐⭐⭐⭐ |
| `large-v3` | ~10GB | ~10GB | ⚡ | ⭐⭐⭐⭐⭐⭐ |

**Recommendations:**
- **CPU:** `tiny` or `base`
- **GPU 4–6GB VRAM:** `small` or `medium`
- **GPU 12GB+ VRAM:** `large-v3` (best quality)

## 🌍 Supported languages

- 🇩🇪 German (`de`)
- 🇬🇧 English (`en`)
- 🇫🇷 French (`fr`)
- 🇪🇸 Spanish (`es`)
- 🇮🇹 Italian (`it`)
- 🇵🇹 Portuguese (`pt`)
- 🇷🇺 Russian (`ru`)
- 🇯🇵 Japanese (`ja`)
- 🇨🇳 Chinese (`zh`)
- … and many more (auto-detect)

## 📊 Output format

Transcription is saved as `.txt` with segment timestamps:

```
[0.00s - 3.45s] First sentence of the transcript.

[3.45s - 7.20s] Second sentence with precise timestamps.

[7.20s - 12.80s] And so on...
```

## 🐛 Troubleshooting

### "FFmpeg not found"
```bash
sudo pacman -S ffmpeg   # Arch/CachyOS
sudo apt install ffmpeg # Debian/Ubuntu
```

### "CUDA out of memory"
- Use a smaller model
- Close other GPU-heavy apps
- Use CPU mode

### "No module named 'whisperx'"
```bash
./venv/bin/pip install -r requirements.txt
```
Or run `./start.sh` once – it installs dependencies if needed.

### Full reinstall (factory reset)

**Recommended:** Run `./scripts/uninstall.sh`, then `./start.sh`.

**Manual:**
```bash
rm -rf venv
rm -f .video_whisper_state
./start.sh
```

## 📝 Logging

All scripts and transcribe.py write to `logs/whisper.log`. On the next start of start.sh, the current log is rotated to `logs/whisper.old.log`.

## 🔄 Updates

```bash
./scripts/update.sh
```

## 📁 Project structure

- `transcribe.py` – Main script (WhisperX transcription)
- `start.sh` – Interactive launcher (Bash)
- `scripts/install.sh` – One-time install (venv + WhisperX + packages; writes logs/install.json)
- `scripts/update.sh` – Update packages
- `scripts/uninstall.sh` – Full teardown (venv, state, txt, logs; optional system packages)
- `requirements.txt` – Python dependencies
- `venv/` – Virtual environment (local, not in repo)
- `txt/` – Output folder for transcripts (not in repo)

## 📋 Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and new features.

## 📜 License

This tool uses: **WhisperX** (BSD), **OpenAI Whisper** (MIT), **FFmpeg** (GPL/LGPL).

## 📚 Further reading

- [WhisperX (m-bain/whisperX)](https://github.com/m-bain/whisperX)
- [OpenAI Whisper](https://github.com/openai/whisper)
- [FFmpeg Documentation](https://ffmpeg.org/documentation.html)

---

**Happy transcribing! 🎉**
