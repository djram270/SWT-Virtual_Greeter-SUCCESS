import asyncio
import tempfile
import os
import wave
import logging
from pathlib import Path
from typing import Optional
from app.utils import color_style
from faster_whisper import WhisperModel

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize model once (GPU if available)
model = WhisperModel("small", device="cpu")


async def transcribe_audio(audio_bytes: bytes, audio_format: str = "wav") -> str:
    """Transcribe raw audio bytes using faster-whisper.

    The library expects a filename or a numpy array. To keep this async-friendly
    we write bytes to a temporary file and run the (blocking) transcribe call
    in a thread using asyncio.to_thread.

    Args:
        audio_bytes: Raw audio file bytes (wav, mp3, etc.).
        suffix: File suffix to hint the audio format (default: .wav).

    Returns:
        The concatenated transcription string.
    """

    def _sync_transcribe(tmp_path: str) -> tuple[str, Optional[str]]:
        # Blocking call to faster-whisper
        segments, info = model.transcribe(tmp_path)
        text = " ".join(segment.text for segment in segments)
        lang = getattr(info, "language", None)
        return text, lang

    # Write bytes to a temporary file so ffmpeg / faster-whisper can read it
    tmp_path = None
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=f".{audio_format}") as tmp:
            tmp.write(audio_bytes)
            tmp.flush()
            tmp_path = tmp.name
            
        # Para WAV, validar el formato
        if audio_format.lower() == "wav":
            try:
                with wave.open(tmp_path, 'rb') as wav:
                    print(f"{color_style.LOGGER} "
                          f"WAV info: channels={wav.getnchannels()}, "
                          f"width={wav.getsampwidth()}, "
                          f"rate={wav.getframerate()}, "
                          f"frames={wav.getnframes()}"
                    )
            except Exception as e:
                print(f"{color_style.ERROR}Invalid WAV file: {e}")
                raise ValueError(f"Invalid WAV file: {e}")

        # Run the blocking transcription in a thread to avoid blocking the event loop
        text, lang = await asyncio.to_thread(_sync_transcribe, tmp_path)
        if lang:
            print(f"{color_style.LOGGER} Language detected: {lang}")
        return text
    except Exception as e:
        print(f"{color_style.ERROR} Transcription error: {e}")
        raise
    finally:
        if tmp_path and os.path.exists(tmp_path):
            try:
                os.remove(tmp_path)
            except Exception:
                print(f"{color_style.WARNING} Could not remove temp file {tmp_path}")
