#!/usr/bin/env python3
"""
MicDup Whisper Service
Transcribes audio files using OpenAI Whisper model
"""

import sys
import argparse
import whisper
import warnings
from pathlib import Path

# Suppress FP16 warnings if running on CPU
warnings.filterwarnings("ignore", message="FP16 is not supported on CPU")


def load_model(model_name: str = "base"):
    """Load Whisper model"""
    try:
        print(f"Loading Whisper model: {model_name}...", file=sys.stderr)
        model = whisper.load_model(model_name)
        print(f"Model loaded successfully", file=sys.stderr)
        return model
    except Exception as e:
        print(f"Error loading model: {e}", file=sys.stderr)
        sys.exit(1)


def transcribe_audio(model, audio_path: str, language: str = None):
    """Transcribe audio file"""
    try:
        # Check if file exists
        if not Path(audio_path).exists():
            print(f"Error: Audio file not found: {audio_path}", file=sys.stderr)
            sys.exit(1)

        print(f"Transcribing: {audio_path}...", file=sys.stderr)

        # Transcribe
        options = {
            "fp16": False,  # Use FP32 for CPU compatibility
            "language": language if language else None
        }

        result = model.transcribe(audio_path, **options)

        # Return only the text to stdout
        return result["text"].strip()

    except Exception as e:
        print(f"Error during transcription: {e}", file=sys.stderr)
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description="Transcribe audio using Whisper")
    parser.add_argument("audio_file", help="Path to audio file (WAV, MP3, etc.)")
    parser.add_argument("--model", default="base",
                       choices=["tiny", "base", "small", "medium", "large"],
                       help="Whisper model size (default: base)")
    parser.add_argument("--language", default=None,
                       help="Audio language (e.g., 'en', 'es', 'fr'). Auto-detect if not specified.")

    args = parser.parse_args()

    # Load model
    model = load_model(args.model)

    # Transcribe
    transcription = transcribe_audio(model, args.audio_file, args.language)

    # Output transcription to stdout (C# will read this)
    print(transcription)


if __name__ == "__main__":
    main()
