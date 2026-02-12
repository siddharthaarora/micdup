#!/usr/bin/env python3
"""
MicDup Whisper Service
Transcribes audio files using OpenAI Whisper model
"""

import sys
import argparse
import warnings
from pathlib import Path

# Suppress FP16 warnings if running on CPU
warnings.filterwarnings("ignore", message="FP16 is not supported on CPU")


def detect_device(requested: str = "auto"):
    """
    Detect the best available device for inference.
    Returns (device, use_fp16) tuple.
    Priority: DirectML > CUDA > CPU
    """
    if requested == "cpu":
        return "cpu", False

    if requested == "cuda":
        import torch
        if torch.cuda.is_available():
            print(f"Using CUDA: {torch.cuda.get_device_name(0)}", file=sys.stderr)
            return "cuda", True
        print("CUDA requested but not available, falling back to CPU", file=sys.stderr)
        return "cpu", False

    if requested == "directml":
        try:
            import torch_directml
            device = torch_directml.device()
            print("Using DirectML device", file=sys.stderr)
            return device, False
        except ImportError:
            print("DirectML requested but torch-directml not installed, falling back to CPU", file=sys.stderr)
            return "cpu", False

    # Auto-detect: try DirectML first (widest Windows NPU/GPU support), then CUDA, then CPU
    try:
        import torch_directml
        device = torch_directml.device()
        print("Auto-detected DirectML device", file=sys.stderr)
        return device, False
    except (ImportError, Exception):
        pass

    try:
        import torch
        if torch.cuda.is_available():
            print(f"Auto-detected CUDA: {torch.cuda.get_device_name(0)}", file=sys.stderr)
            return "cuda", True
    except Exception:
        pass

    print("No GPU/NPU detected, using CPU", file=sys.stderr)
    return "cpu", False


def load_model(model_name: str, device, use_fp16: bool):
    """Load Whisper model onto the specified device"""
    import whisper

    try:
        print(f"Loading Whisper model: {model_name}...", file=sys.stderr)

        if isinstance(device, str) and device in ("cpu", "cuda"):
            model = whisper.load_model(model_name, device=device)
        else:
            # DirectML or other torch device object
            model = whisper.load_model(model_name)
            model = model.to(device)

        print(f"Model loaded successfully", file=sys.stderr)
        return model
    except Exception as e:
        print(f"Error loading model: {e}", file=sys.stderr)
        sys.exit(1)


def transcribe_audio(model, audio_path: str, language: str = None, use_fp16: bool = False):
    """Transcribe audio file"""
    import whisper

    try:
        if not Path(audio_path).exists():
            print(f"Error: Audio file not found: {audio_path}", file=sys.stderr)
            sys.exit(1)

        print(f"Transcribing: {audio_path}...", file=sys.stderr)

        options = {
            "fp16": use_fp16,
            "language": language if language else None
        }

        result = model.transcribe(audio_path, **options)
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
    parser.add_argument("--device", default="auto",
                       choices=["auto", "cpu", "cuda", "directml"],
                       help="Device for inference (default: auto)")

    args = parser.parse_args()

    # Detect device
    device, use_fp16 = detect_device(args.device)

    # Load model
    model = load_model(args.model, device, use_fp16)

    # Transcribe
    transcription = transcribe_audio(model, args.audio_file, args.language, use_fp16)

    # Output transcription to stdout (C# will read this)
    print(transcription)


if __name__ == "__main__":
    main()
