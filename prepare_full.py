#!/usr/bin/env python3
"""Download models needed for the optional alignment and diarization mode."""
import getpass
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parent
os.environ['HF_HOME'] = str(ROOT / 'cache' / 'huggingface')
os.environ['TORCH_HOME'] = str(ROOT / 'cache' / 'torch')
os.environ['XDG_CACHE_HOME'] = str(ROOT / 'cache' / 'xdg')
os.environ['PYANNOTE_METRICS_ENABLED'] = '0'
os.environ['HF_HUB_DISABLE_TELEMETRY'] = '1'
os.environ['DO_NOT_TRACK'] = '1'


def main():
    token = getpass.getpass('Hugging Face read token (input hidden): ')
    if not token:
        raise SystemExit('A read token is required for Community-1.')
    import whisperx
    from whisperx.diarize import DiarizationPipeline

    print('Downloading/loading Community-1...', flush=True)
    diarizer = DiarizationPipeline(token=token, device='cpu',
        cache_dir=str(ROOT / 'cache' / 'huggingface' / 'hub'))
    del diarizer, token
    print('Downloading/loading the English alignment model...', flush=True)
    model, _ = whisperx.load_align_model(language_code='en', device='cpu',
        model_dir=str(ROOT / 'cache' / 'torch' / 'hub' / 'checkpoints'))
    del model
    print('Full-mode models are available in this project.', flush=True)


if __name__ == '__main__':
    main()
