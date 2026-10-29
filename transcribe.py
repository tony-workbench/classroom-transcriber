#!/usr/bin/env python3
import os, sys, argparse, getpass, subprocess, tempfile, gc
from pathlib import Path
ROOT = Path(__file__).resolve().parent
os.environ['HF_HOME'] = str(ROOT / 'cache' / 'huggingface')
os.environ['TORCH_HOME'] = str(ROOT / 'cache' / 'torch')
os.environ['XDG_CACHE_HOME'] = str(ROOT / 'cache' / 'xdg')
os.environ['PYANNOTE_METRICS_ENABLED'] = '0'
os.environ['HF_HUB_DISABLE_TELEMETRY'] = '1'
os.environ['DO_NOT_TRACK'] = '1'
os.environ['PYTORCH_ENABLE_MPS_FALLBACK'] = '1'

def stamp(seconds, srt=False):
    ms = max(0, round(seconds * 1000)); h, ms = divmod(ms, 3600000); m, ms = divmod(ms, 60000); s, ms = divmod(ms, 1000)
    return f'{h:02}:{m:02}:{s:02}{"," if srt else "."}{ms:03}'

def main():
    p = argparse.ArgumentParser(description='Local English transcription and speaker diarization')
    p.add_argument('audio', type=Path); p.add_argument('--output-dir', type=Path, default=ROOT/'transcripts')
    p.add_argument('--download', action='store_true', help='Allow initial model downloads; prompts for HF token')
    p.add_argument('--no-diarize', action='store_true', help='Diagnostic only: skip speaker labels')
    p.add_argument('--device', choices=['cpu','mps'], default='cpu', help='Alignment and diarization device; CPU is safer')
    args = p.parse_args()
    if not args.audio.is_file(): p.error('Audio file does not exist')
    if not args.download:
        os.environ['HF_HUB_OFFLINE'] = '1'; os.environ['TRANSFORMERS_OFFLINE'] = '1'
        # English torchaudio model does not honor HF offline mode; fail before it tries to download.
        if not list((ROOT/'cache'/'torch').rglob('wav2vec2_fairseq_base_ls960_asr_ls960.pth')):
            sys.exit('Alignment model is not cached. Run once with --download.')
    import imageio_ffmpeg, numpy as np, torch, whisperx
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    token = getpass.getpass('Hugging Face read token (input hidden): ') if args.download and not args.no_diarize else None
    if args.download and not args.no_diarize and not token: sys.exit('Token required for initial model download.')
    if args.device == 'mps' and not torch.backends.mps.is_available(): sys.exit('MPS is unavailable; use --device cpu.')
    print('Decoding audio locally...', flush=True)
    with tempfile.TemporaryDirectory(prefix='classroom-audio-', dir=ROOT) as temp:
        wav = Path(temp)/'audio.wav'
        subprocess.run([ffmpeg, '-nostdin','-v','error','-i',str(args.audio),'-ac','1','-ar','16000','-c:a','pcm_s16le',str(wav)],check=True)
        import wave
        with wave.open(str(wav),'rb') as w:
            audio = np.frombuffer(w.readframes(w.getnframes()), dtype='<i2').astype(np.float32)/32768.0
        print(f'Audio duration: {len(audio)/16000:.1f}s. Transcribing on CPU...', flush=True)
        model = whisperx.load_model('large-v3-turbo','cpu',compute_type='int8',language='en',download_root=str(ROOT/'cache'/'huggingface'/'hub'),local_files_only=not args.download)
        result = model.transcribe(audio,batch_size=4,language='en')
        del model; gc.collect()
        print('Aligning words...', flush=True)
        align, meta = whisperx.load_align_model(language_code='en',device=args.device,model_dir=str(ROOT/'cache'/'torch'/'hub'/'checkpoints'))
        result = whisperx.align(result['segments'],align,meta,audio,args.device,return_char_alignments=False)
        del align; gc.collect()
        if not args.no_diarize:
            print('Detecting speakers...', flush=True)
            from whisperx.diarize import DiarizationPipeline
            diarizer = DiarizationPipeline(token=token,device=args.device,cache_dir=str(ROOT/'cache'/'huggingface'/'hub'))
            diarization = diarizer(audio)
            result = whisperx.assign_word_speakers(diarization,result)
        segments = [s for s in result['segments'] if s.get('text','').strip() and 'start' in s and 'end' in s]
        if not segments: sys.exit('No aligned speech found; no transcript written.')
        args.output_dir.mkdir(parents=True,exist_ok=True)
        stem = args.audio.stem
        destinations = [args.output_dir/f'{stem}{ext}' for ext in ('.txt','.srt','.md')]
        if any(x.exists() for x in destinations): sys.exit('Output already exists. Choose another --output-dir to avoid overwriting.')
        txt = '\n'.join(s['text'].strip() for s in segments)+'\n'
        srt = '\n\n'.join(f"{i}\n{stamp(s['start'],True)} --> {stamp(s['end'],True)}\n{s['text'].strip()}" for i,s in enumerate(segments,1))+'\n'
        md = '# Transcript\n\n'+'\n\n'.join(f"**[{stamp(s['start'])}–{stamp(s['end'])}] {s.get('speaker','UNKNOWN')}**\n\n{s['text'].strip()}" for s in segments)+'\n'
        for path, content in zip(destinations,(txt,srt,md)): path.write_text(content,encoding='utf-8')
        print('Saved:', *(str(x) for x in destinations), sep='\n', flush=True)
if __name__ == '__main__': main()
