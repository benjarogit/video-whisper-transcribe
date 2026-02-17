#!/usr/bin/env python3
"""
Video Whisper - Modern Audio/Video Transcription Tool
Uses WhisperX for accurate transcription with word-level timestamps
"""

import os
import sys
import logging
import traceback
import warnings
from pathlib import Path
from typing import Optional, Dict, Any, List
from dataclasses import dataclass

# Bekannte harmlose Warnungen unterdrücken (Ausgabe ruhiger halten)
# – torchcodec: pyannote nutzt es optional; WhisperX lädt Audio per FFmpeg
# – TF32/Reproducibility: pyannote schaltet TF32 für Reproduzierbarkeit aus
# – Lightning checkpoint upgrade: nur Hinweis, keine Aktion nötig
warnings.filterwarnings("ignore", message=".*torchcodec.*", category=UserWarning)
warnings.filterwarnings("ignore", message=".*TensorFloat-32.*", category=UserWarning)
warnings.filterwarnings("ignore", message=".*TF32.*", category=UserWarning)
warnings.filterwarnings("ignore", message=".*Lightning automatically upgraded.*", category=UserWarning)

import torch
import whisperx
from tqdm import tqdm

# ANSI-Farben für Konsolen-Ausgabe (nur wenn stdout ein Terminal ist)
if sys.stdout.isatty():
    C_GRN = "\033[0;32m"
    C_RED = "\033[0;31m"
    C_YEL = "\033[1;33m"
    C_CYN = "\033[0;36m"
    C_BLD = "\033[1m"
    C_DIM = "\033[2m"
    C_OFF = "\033[0m"
else:
    C_GRN = C_RED = C_YEL = C_CYN = C_BLD = C_DIM = C_OFF = ""


# ============================================================================
# Configuration and Types
# ============================================================================

@dataclass
class TranscriptionConfig:
    """Configuration for transcription process"""
    file_path: Path
    output_path: Path
    model_size: str = "small"
    language: Optional[str] = None
    device: str = "auto"
    compute_type: str = "auto"
    batch_size: int = 16
    
    SUPPORTED_MODELS = {"tiny", "base", "small", "medium", "large", "large-v2", "large-v3"}
    SUPPORTED_LANGUAGES = {"en", "fr", "de", "es", "it", "pt", "ru", "ja", "zh"}
    
    def validate(self) -> None:
        """Validate configuration parameters"""
        if not self.file_path.exists():
            raise FileNotFoundError(f"Input file not found: {self.file_path}")
        
        if self.model_size not in self.SUPPORTED_MODELS:
            raise ValueError(f"Unsupported model: {self.model_size}")
        
        if self.language and self.language not in self.SUPPORTED_LANGUAGES:
            raise ValueError(f"Unsupported language: {self.language}")


# ============================================================================
# Logging Setup
# ============================================================================

def setup_logging() -> logging.Logger:
    """Setup logging: nur in logs/whisper.log (keine Flut auf der Konsole). Fortschritt nur via tqdm + kurze Prints."""
    log_dir = Path(__file__).resolve().parent / "logs"
    log_dir.mkdir(exist_ok=True)
    log_file = log_dir / "whisper.log"

    log_format = "[%(asctime)s] [%(levelname)s] [transcribe.py] %(message)s"
    date_fmt = "%Y-%m-%d %H:%M:%S"

    logging.basicConfig(
        level=logging.INFO,
        format=log_format,
        datefmt=date_fmt,
        handlers=[logging.FileHandler(log_file, mode="a", encoding="utf-8")],
    )
    # Kein StreamHandler – Details nur in der Log-Datei, Konsole bleibt ruhig (nur tqdm + Abschluss)

    logger = logging.getLogger(__name__)
    logger.info(f"Log-Datei: {log_file}")
    return logger


# ============================================================================
# Device Detection
# ============================================================================

def detect_device() -> tuple[str, str]:
    """
    Detect optimal device and compute type for transcription
    Returns: (device, compute_type)
    """
    logger = logging.getLogger(__name__)
    
    # Check for CUDA (NVIDIA GPU)
    if torch.cuda.is_available():
        device = "cuda"
        compute_type = "float16"
        gpu_name = torch.cuda.get_device_name(0)
        logger.info(f"🚀 CUDA detected: {gpu_name}")
        logger.info(f"   VRAM: {torch.cuda.get_device_properties(0).total_memory / 1e9:.1f} GB")
        return device, compute_type
    
    # Check for ROCm (AMD GPU)
    try:
        if torch.version.hip and torch.cuda.is_available():
            device = "cuda"  # ROCm uses 'cuda' backend in PyTorch
            compute_type = "float16"
            logger.info("🚀 ROCm detected (AMD GPU)")
            return device, compute_type
    except AttributeError:
        pass
    
    # Fallback to CPU (WhisperX README: "run on CPU: --compute_type int8 --device cpu")
    device = "cpu"
    compute_type = "int8"
    logger.info("💻 Using CPU (slower, but works)")
    
    # Check if running on modern CPU with AVX2
    try:
        import cpuinfo
        info = cpuinfo.get_cpu_info()
        if 'avx2' in info.get('flags', []):
            logger.info(f"   CPU: {info.get('brand_raw', 'Unknown')}")
            logger.info("   AVX2 acceleration available")
    except Exception:
        pass
    
    return device, compute_type


# ============================================================================
# Transcription Functions
# ============================================================================

def load_model(config: TranscriptionConfig, logger: logging.Logger) -> Any:
    """Load WhisperX model with automatic device detection"""
    logger.info(f"Loading model: {config.model_size}")
    logger.info(f"Device: {config.device}, Compute type: {config.compute_type}")
    
    try:
        model = whisperx.load_model(
            config.model_size,
            device=config.device,
            compute_type=config.compute_type,
            language=config.language
        )
        logger.info("✓ Model loaded successfully")
        return model
    except Exception as e:
        logger.error(f"Failed to load model: {e}")
        logger.debug(traceback.format_exc())
        raise


def transcribe_audio(
    model,
    config: TranscriptionConfig,
    logger: logging.Logger
) -> Dict[str, Any]:
    """Transcribe audio/video file (API wie WhisperX README: load_audio → transcribe)."""
    logger.info(f"Starting transcription: {config.file_path.name}")
    logger.info(f"Language: {'Auto-detect' if not config.language else config.language}")
    logger.info(f"Batch size: {config.batch_size}")

    try:
        logger.info(f"Lade Audio: whisperx.load_audio({config.file_path.name})")
        audio = whisperx.load_audio(str(config.file_path))
        if hasattr(audio, "shape") and len(audio.shape) >= 1:
            logger.info(f"Audio geladen: {audio.shape[0]} Samples (ca. {audio.shape[0] / 16000:.1f} s bei 16 kHz)")
        else:
            logger.info("Audio geladen (WhisperX load_audio).")

        logger.info(f"Starte model.transcribe (batch_size={config.batch_size}, language={config.language or 'auto'})")
        result = model.transcribe(
            audio,
            batch_size=config.batch_size,
            language=config.language
        )

        detected_language = result.get("language", "unknown")
        segments = result.get("segments", [])
        logger.info(f"Transkription fertig: Sprache={detected_language}, Segmente={len(segments)}")
        if segments:
            total_dur = sum(s.get("end", 0) - s.get("start", 0) for s in segments)
            logger.info(f"Gesamtdauer der Segmente: {total_dur:.1f} s")

        return result
    except Exception as e:
        logger.error(f"Transcription failed: {e}")
        logger.debug(traceback.format_exc())
        raise


def align_segments(
    segments: List[Dict[str, Any]],
    audio_path: Path,
    language: str,
    device: str,
    logger: logging.Logger
) -> Optional[Dict[str, Any]]:
    """
    Align segments for word-level timestamps (optional enhancement)
    Returns aligned result or None if alignment fails
    """
    try:
        logger.info("Aligning segments for word-level timestamps...")
        model_a, metadata = whisperx.load_align_model(
            language_code=language,
            device=device
        )
        
        result_aligned = whisperx.align(
            segments,
            model_a,
            metadata,
            str(audio_path),
            device
        )
        
        logger.info("✓ Alignment completed")
        return result_aligned
    except Exception as e:
        logger.warning(f"Alignment failed (continuing without): {e}")
        return None


def format_transcription(
    result: Dict[str, Any],
    include_word_timestamps: bool = False
) -> str:
    """Format transcription result as text with timestamps"""
    if 'segments' not in result or not result['segments']:
        return "No transcription data available."
    
    output_lines = []
    
    for segment in result['segments']:
        start_time = segment.get('start', 0.0)
        end_time = segment.get('end', 0.0)
        text = segment.get('text', '').strip()
        
        # Segment-level timestamp
        output_lines.append(f"[{start_time:.2f}s - {end_time:.2f}s] {text}")
        
        # Optional: Word-level timestamps
        if include_word_timestamps and 'words' in segment:
            word_lines = []
            for word_info in segment['words']:
                word = word_info.get('word', '')
                w_start = word_info.get('start', 0.0)
                w_end = word_info.get('end', 0.0)
                word_lines.append(f"  [{w_start:.2f}s] {word}")
            if word_lines:
                output_lines.extend(word_lines)
        
        output_lines.append("")  # Empty line between segments
    
    return "\n".join(output_lines)


def save_transcription(
    text: str,
    config: TranscriptionConfig,
    logger: logging.Logger
) -> Path:
    """Save transcription to output file"""
    output_file = config.output_path / f"{config.file_path.stem}.txt"
    
    try:
        output_file.parent.mkdir(parents=True, exist_ok=True)
        output_file.write_text(text, encoding='utf-8')
        logger.info(f"✓ Transcription saved: {output_file}")
        return output_file
    except Exception as e:
        logger.error(f"Failed to save transcription: {e}")
        logger.debug(traceback.format_exc())
        raise


# ============================================================================
# Main Transcription Pipeline
# ============================================================================

def run_transcription(config: TranscriptionConfig, logger: logging.Logger) -> None:
    """Main transcription pipeline"""
    try:
        # Bibliotheken (z. B. Lightning) dürfen nicht auf die Konsole loggen – nur in Datei
        root = logging.getLogger()
        for h in root.handlers[:]:
            if isinstance(h, logging.StreamHandler) and getattr(h, "stream", None) in (sys.stdout, sys.stderr):
                root.removeHandler(h)
        logger.info("=== Pipeline start ===")
        config.validate()
        logger.info("Configuration validated")
        logger.info(f"Input: {config.file_path} ({config.file_path.stat().st_size / 1024 / 1024:.2f} MB)")
        logger.info(f"Output dir: {config.output_path}")
        logger.info(f"Model: {config.model_size}, Device: {config.device}, Compute: {config.compute_type}")

        if sys.stdout.isatty():
            print(f"  {C_CYN}⟳{C_OFF} Lade Modell …", flush=True)
        logger.info("Lade WhisperX-Modell (whisperx.load_model)...")
        model = load_model(config, logger)

        if sys.stdout.isatty():
            print(f"  {C_CYN}⟳{C_OFF} Transkribiere …", flush=True)
        logger.info("Starte Transkription (load_audio + model.transcribe)...")
        result = transcribe_audio(model, config, logger)
        
        # Optional: Align for word-level timestamps
        # Uncomment if you want word-level timestamps
        # if result.get('segments') and result.get('language'):
        #     aligned = align_segments(
        #         result['segments'],
        #         config.file_path,
        #         result['language'],
        #         config.device,
        #         logger
        #     )
        #     if aligned:
        #         result = aligned
        
        # Format output
        if result.get('segments'):
            total_segments = len(result['segments'])
            logger.info(f"Processing {total_segments} segments...")
            # Nur Fortschrittsbalken auf der Konsole (Details im Log)
            for segment in tqdm(
                result['segments'],
                desc='  Segmente',
                unit='segment',
                ncols=80,
                leave=True,
                file=sys.stdout,
            ):
                pass  # Segments already processed, just showing progress
        
        transcription_text = format_transcription(result)
        logger.info(f"Formatiert: {len(transcription_text)} Zeichen, {len(result.get('segments', []))} Segmente")

        output_file = save_transcription(transcription_text, config, logger)
        if output_file.exists():
            logger.info(f"Datei geschrieben: {output_file} ({output_file.stat().st_size} Bytes)")
        logger.info("=== Pipeline Ende (Erfolg) ===")

        print(f"\n{C_CYN}{'═'*60}{C_OFF}")
        print(f"{C_GRN}✓ Transkription fertig.{C_OFF} Gespeichert in:")
        print(f"  {C_BLD}{output_file}{C_OFF}")
        print(f"{C_CYN}{'═'*60}{C_OFF}\n")

    except Exception as e:
        logger.error(f"Transcription pipeline failed: {e}")
        logger.info("=== Pipeline Ende (Fehler) ===")
        logger.debug(traceback.format_exc())
        print(f"\n{C_RED}✗ Fehler: {e}{C_OFF}")
        print(f"{C_DIM}Details siehe Log-Datei.{C_OFF}\n")
        sys.exit(1)


# ============================================================================
# CLI Entry Point
# ============================================================================

def parse_arguments() -> TranscriptionConfig:
    """Parse command line arguments"""
    if len(sys.argv) < 3:
        print(f"{C_BLD}Verwendung:{C_OFF} transcribe.py <Eingabedatei> <Ausgabeordner> [Modell] [Sprache]")
        print(f"\n{C_DIM}Modelle:{C_OFF} tiny, base, small (Standard), medium, large, large-v2, large-v3")
        print(f"{C_DIM}Sprachen:{C_OFF} en, de, fr, es, it, pt, ru, ja, zh oder Auto (Standard)")
        sys.exit(1)
    
    file_path = Path(sys.argv[1]).resolve()
    output_path = Path(sys.argv[2]).resolve()
    model_size = sys.argv[3] if len(sys.argv) > 3 else "small"
    language = (sys.argv[4].strip() or None) if len(sys.argv) > 4 else None
    
    # Auto-detect device and compute type
    device, compute_type = detect_device()
    
    return TranscriptionConfig(
        file_path=file_path,
        output_path=output_path,
        model_size=model_size,
        language=language,
        device=device,
        compute_type=compute_type
    )


def main() -> None:
    """Main entry point"""
    logger = setup_logging()
    logger.info("="*60)
    logger.info("Video Whisper - Transcription Tool")
    logger.info("="*60)
    
    try:
        config = parse_arguments()
        run_transcription(config, logger)
    except KeyboardInterrupt:
        logger.info("\n⚠ Transcription cancelled by user")
        print(f"\n{C_YEL}⚠ Abgebrochen durch Benutzer.{C_OFF}\n")
        sys.exit(130)
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        logger.debug(traceback.format_exc())
        print(f"\n{C_RED}✗ Unerwarteter Fehler: {e}{C_OFF}\n")
        sys.exit(1)


if __name__ == "__main__":
    main()
