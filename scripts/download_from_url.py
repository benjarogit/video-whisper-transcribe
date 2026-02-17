#!/usr/bin/env python3
"""
Lädt ein Video oder nur Audio (MP3) von einer URL (YouTube u. a. via yt-dlp)
und gibt den Pfad der heruntergeladenen Datei auf stdout aus.
Aufruf: download_from_url.py <url> <video|mp3> [ausgabe_verzeichnis] [fortschrittsdatei]
  ausgabe_verzeichnis: Ordner für Downloads (z. B. medien/). Standard: aktuelles Verzeichnis.
  fortschrittsdatei: optional; eine Zeile mit Fortschritt (z. B. " 45.2%") wird dort geschrieben (für Spinner).
"""
import sys
import os
from pathlib import Path

def main():
    if len(sys.argv) < 3:
        print("Aufruf: download_from_url.py <url> <video|mp3> [ausgabe_verzeichnis] [fortschrittsdatei]", file=sys.stderr)
        sys.exit(1)
    url = sys.argv[1].strip()
    mode = sys.argv[2].strip().lower()
    out_dir = Path(sys.argv[3]) if len(sys.argv) > 3 else Path.cwd()
    progress_file = sys.argv[4] if len(sys.argv) > 4 else None
    out_dir.mkdir(parents=True, exist_ok=True)

    if mode not in ("video", "mp3"):
        print("Modus muss 'video' oder 'mp3' sein.", file=sys.stderr)
        sys.exit(1)

    # yt-dlp ist aktiv gewartet und umgeht typische YouTube-Fehler („The page needs to be reloaded“ etc.)
    try:
        import yt_dlp as ydl_module
    except ImportError:
        print("yt-dlp fehlt. Bitte: pip install yt-dlp", file=sys.stderr)
        sys.exit(1)

    # Ausgabepfad: medien/%(id)s.%(ext)s (id ist stabil, title kann Sonderzeichen haben)
    outtmpl = str(out_dir / "%(id)s.%(ext)s")
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
                    with open(progress_file, "w") as f:
                        f.write(" {:5.1f}%\n".format(pct))
                except OSError:
                    pass
            else:
                try:
                    with open(progress_file, "w") as f:
                        mb = done / (1024 * 1024)
                        f.write(" {:.1f} MB\n".format(mb))
                except OSError:
                    pass
        elif progress_file and d.get("status") == "finished":
            try:
                with open(progress_file, "w") as f:
                    f.write(" 100%\n")
            except OSError:
                pass

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
        with ydl_module.YoutubeDL(ydl_opts) as ydl:
            ydl.download([url])
        path = _resolve_path(downloaded_path[0], out_dir)
        if path:
            print(str(path))
            sys.exit(0)
        print("Download fehlgeschlagen oder keine Datei erzeugt.", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Fehler: {e}", file=sys.stderr)
        # Trotzdem prüfen, ob eine Datei heruntergeladen wurde (z. B. Post-Processing fehlgeschlagen)
        path = _resolve_path(downloaded_path[0], out_dir)
        if path:
            print(str(path), file=sys.stderr)  # Pfad auch bei Fehler ausgeben
            print(str(path))  # stdout für Shell
            sys.exit(0)
        sys.exit(1)


def _resolve_path(downloaded_path, out_dir):
    """Ergibt absoluten Pfad zur Datei oder None."""
    if downloaded_path and os.path.isfile(downloaded_path):
        return str(Path(downloaded_path).resolve())
    files = [f for f in out_dir.iterdir() if f.is_file()]
    if not files:
        return None
    return str(max(files, key=lambda p: p.stat().st_mtime).resolve())

if __name__ == "__main__":
    main()
