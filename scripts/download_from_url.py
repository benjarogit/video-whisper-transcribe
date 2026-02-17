#!/usr/bin/env python3
"""
Lädt ein Video oder nur Audio (MP3) von einer URL (YouTube u. a. via youtube-dl)
und gibt den Pfad der heruntergeladenen Datei auf stdout aus.
Aufruf: download_from_url.py <url> <video|mp3> [ausgabe_verzeichnis]
"""
import sys
import os
from pathlib import Path

def main():
    if len(sys.argv) < 3:
        print("Aufruf: download_from_url.py <url> <video|mp3> [ausgabe_verzeichnis]", file=sys.stderr)
        sys.exit(1)
    url = sys.argv[1].strip()
    mode = sys.argv[2].strip().lower()
    out_dir = Path(sys.argv[3]) if len(sys.argv) > 3 else Path.cwd()
    out_dir = out_dir / "downloads"
    out_dir.mkdir(parents=True, exist_ok=True)

    if mode not in ("video", "mp3"):
        print("Modus muss 'video' oder 'mp3' sein.", file=sys.stderr)
        sys.exit(1)

    try:
        import youtube_dl
    except ImportError:
        print("youtube-dl ist nicht installiert. Bitte: pip install youtube-dl", file=sys.stderr)
        sys.exit(1)

    # Ausgabepfad: downloads/%(id)s.%(ext)s (id ist stabil, title kann Sonderzeichen haben)
    outtmpl = str(out_dir / "%(id)s.%(ext)s")
    downloaded_path = [None]

    def progress_hook(d):
        if d.get("status") == "finished" and d.get("filename"):
            downloaded_path[0] = d["filename"]

    if mode == "mp3":
        ydl_opts = {
            "format": "bestaudio/best",
            "outtmpl": outtmpl,
            "postprocessors": [{
                "key": "FFmpegExtractAudio",
                "preferredcodec": "mp3",
                "preferredquality": "192",
            }],
            "quiet": True,
            "no_warnings": True,
            "progress_hooks": [progress_hook],
        }
    else:
        ydl_opts = {
            "format": "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best",
            "outtmpl": outtmpl,
            "merge_output_format": "mp4",
            "quiet": True,
            "no_warnings": True,
            "progress_hooks": [progress_hook],
        }

    try:
        with youtube_dl.YoutubeDL(ydl_opts) as ydl:
            ydl.download([url])
        path = downloaded_path[0]
        if path and os.path.isfile(path):
            path = Path(path).resolve()
        else:
            # Fallback: neueste Datei im downloads-Ordner
            files = [f for f in out_dir.iterdir() if f.is_file()]
            if not files:
                print("Download fehlgeschlagen oder keine Datei erzeugt.", file=sys.stderr)
                sys.exit(1)
            path = max(files, key=lambda p: p.stat().st_mtime)
        print(str(path))
    except Exception as e:
        print(f"Fehler: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
