#!/usr/bin/env python3
"""
Lädt ein Video oder nur Audio (MP3) von einer URL (YouTube u. a. via yt-dlp)
und gibt den Pfad der heruntergeladenen Datei auf stdout aus.
Dateiname: standardmäßig Videotitel (bereinigt); bei Kollision "Titel (2).ext" …
  Optional eigener Titel (Einzel-URL) oder Basis-Titel für Bulk → "Basis 1", "Basis 2", …
yt-dlp erkennt automatisch Einzelvideo vs. Playlist; bei Playlist-URL wird nur ein Video geladen (noplaylist).
Aufruf: download_from_url.py <url> <video|mp3> [ausgabe_verzeichnis] [fortschrittsdatei] [titel_suffix] [basis_titel]
  titel_suffix: für Bulk z. B. " 1", " 2" → "Basis 1.mp4", "Basis 2.mp4".
  basis_titel: wenn gesetzt, wird dieser statt Videotitel verwendet (Einzel-URL oder Bulk).
"""
import re
import sys
import os
from pathlib import Path


def _sanitize_filename(s: str, max_len: int = 200) -> str:
    """Titel für Dateisystem: Sonderzeichen ersetzen, Länge begrenzen."""
    if not s or not s.strip():
        return "video"
    s = s.strip()
    s = re.sub(r'[<>:"/\\|?*]', " ", s)
    s = re.sub(r"\s+", " ", s).strip()
    return s[:max_len] if len(s) > max_len else s


def _next_free_path(out_dir: Path, base: str, ext: str) -> Path:
    """Nächsten freien Pfad finden: base.ext, base (2).ext, base (3).ext …"""
    cand = out_dir / f"{base}.{ext}"
    if not cand.exists():
        return cand
    n = 2
    while True:
        cand = out_dir / f"{base} ({n}).{ext}"
        if not cand.exists():
            return cand
        n += 1


def main():
    if len(sys.argv) < 3:
        print(
            "Aufruf: download_from_url.py <url> <video|mp3> [ausgabe_verzeichnis] [fortschrittsdatei] [titel_suffix] [basis_titel]",
            file=sys.stderr,
        )
        sys.exit(1)
    url = sys.argv[1].strip()
    mode = sys.argv[2].strip().lower()
    out_dir = Path(sys.argv[3]) if len(sys.argv) > 3 else Path.cwd()
    progress_file = sys.argv[4] if len(sys.argv) > 4 else None
    title_suffix = (sys.argv[5] or "").strip() if len(sys.argv) > 5 else ""
    base_override = (sys.argv[6] or "").strip() if len(sys.argv) > 6 else ""
    out_dir.mkdir(parents=True, exist_ok=True)

    if mode not in ("video", "mp3"):
        print("Modus muss 'video' oder 'mp3' sein.", file=sys.stderr)
        sys.exit(1)

    try:
        import yt_dlp as ydl_module
    except ImportError:
        print("yt-dlp fehlt. Bitte: pip install yt-dlp", file=sys.stderr)
        sys.exit(1)

    ext = "mp4" if mode == "video" else "mp3"
    if base_override:
        base_from_title = _sanitize_filename(base_override)
    else:
        base_from_title = "video"
        try:
            with ydl_module.YoutubeDL({"quiet": True, "no_warnings": True, "extract_flat": False}) as ydl:
                info = ydl.extract_info(url, download=False)
                if info and info.get("title"):
                    base_from_title = _sanitize_filename(info["title"])
        except Exception:
            pass

    base_name = base_from_title + title_suffix
    if not base_name.strip():
        base_name = "video"
    out_path = _next_free_path(out_dir, base_name, ext)
    outtmpl = str(out_path)
    downloaded_path = [None]

    def progress_hook(d):
        if d.get("status") == "finished" and d.get("filename"):
            downloaded_path[0] = d["filename"]
        if progress_file and d.get("status") == "downloading":
            total = d.get("total_bytes") or d.get("total_bytes_estimate")
            done = d.get("downloaded_bytes") or 0
            if total and total > 0:
                pct = min(100.0, 100.0 * done / total)
                try:
                    with open(progress_file, "w", encoding="utf-8") as f:
                        f.write(" {:5.1f}%\n".format(pct))
                except OSError:
                    pass
            else:
                try:
                    with open(progress_file, "w", encoding="utf-8") as f:
                        mb = done / (1024 * 1024)
                        f.write(" {:.1f} MB\n".format(mb))
                except OSError:
                    pass
        elif progress_file and d.get("status") == "finished":
            try:
                with open(progress_file, "w", encoding="utf-8") as f:
                    f.write(" 100%\n")
            except OSError:
                pass

    # noplaylist: Bei Playlist-URL nur ein Video laden (Einzel-URL = eine Datei)
    if mode == "mp3":
        ydl_opts = {
            "format": "bestaudio/best",
            "outtmpl": outtmpl,
            "noplaylist": True,
            "postprocessors": [
                {
                    "key": "FFmpegExtractAudio",
                    "preferredcodec": "mp3",
                    "preferredquality": "192",
                }
            ],
            "quiet": True,
            "no_warnings": True,
            "progress_hooks": [progress_hook],
        }
    else:
        ydl_opts = {
            "format": "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best",
            "outtmpl": outtmpl,
            "merge_output_format": "mp4",
            "noplaylist": True,
            "quiet": True,
            "no_warnings": True,
            "progress_hooks": [progress_hook],
        }

    try:
        with ydl_module.YoutubeDL(ydl_opts) as ydl:
            ydl.download([url])
        path = _resolve_path(downloaded_path[0], out_path)
        if path:
            print(str(path), flush=True)
            sys.exit(0)
        print("Download fehlgeschlagen oder keine Datei erzeugt.", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Fehler: {e}", file=sys.stderr)
        path = _resolve_path(downloaded_path[0], out_path)
        if path:
            print(str(path), file=sys.stderr)
            print(str(path), flush=True)
            sys.exit(0)
        sys.exit(1)


def _resolve_path(downloaded_path, expected_path):
    """Absoluten Pfad zur Datei: zuerst erwarteter Pfad, sonst neueste Datei im Ordner."""
    if isinstance(expected_path, Path) and expected_path.is_file():
        return str(expected_path.resolve())
    if downloaded_path and os.path.isfile(downloaded_path):
        return str(Path(downloaded_path).resolve())
    out_dir = Path(expected_path).parent if isinstance(expected_path, Path) else Path(downloaded_path or ".").parent
    if not out_dir.is_dir():
        return None
    files = [f for f in out_dir.iterdir() if f.is_file()]
    if not files:
        return None
    return str(max(files, key=lambda p: p.stat().st_mtime).resolve())


if __name__ == "__main__":
    main()
