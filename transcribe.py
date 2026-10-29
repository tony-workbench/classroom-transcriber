#!/usr/bin/env python3
"""Local GPU transcription with speech-region timestamps, without alignment or diarization."""
import argparse, gc, json, os, subprocess, sys, tempfile, wave
from pathlib import Path
ROOT=Path(__file__).resolve().parent
os.environ['HF_HOME']=str(ROOT/'cache'/'huggingface')
os.environ['TORCH_HOME']=str(ROOT/'cache'/'torch')
os.environ['XDG_CACHE_HOME']=str(ROOT/'cache'/'xdg')
os.environ['HF_HUB_OFFLINE']='1'
os.environ['TRANSFORMERS_OFFLINE']='1'
os.environ['PYANNOTE_METRICS_ENABLED']='0'
os.environ['HF_HUB_DISABLE_TELEMETRY']='1'
os.environ['DO_NOT_TRACK']='1'
os.environ['PYTORCH_ENABLE_MPS_FALLBACK']='1'

def stamp(seconds,srt=False):
    ms=max(0,round(seconds*1000)); h,ms=divmod(ms,3600000); m,ms=divmod(ms,60000); s,ms=divmod(ms,1000)
    return f'{h:02}:{m:02}:{s:02}{"," if srt else "."}{ms:03}'

def main():
    p=argparse.ArgumentParser(); p.add_argument('audio',type=Path); p.add_argument('--output-dir',type=Path,required=True)
    args=p.parse_args()
    if not args.audio.is_file():p.error('Audio file does not exist')
    import imageio_ffmpeg, numpy as np, torch
    from whisperx.vads.pyannote import Pyannote
    if not torch.backends.mps.is_available():sys.exit('Apple GPU (MPS) is unavailable.')
    expected=[args.output_dir/(args.audio.stem+ext) for ext in ('.txt','.srt','.md')]
    if any(x.exists() for x in expected):sys.exit('Output already exists; refusing to overwrite.')
    print('Decoding audio locally...',flush=True)
    with tempfile.TemporaryDirectory(prefix='classroom-audio-',dir=ROOT) as temp:
        wav=Path(temp)/'audio.wav'; part_file=Path(temp)/'speech-segments.json'; result_file=Path(temp)/'asr-result.json'
        subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(),'-nostdin','-v','error','-i',str(args.audio),'-ac','1','-ar','16000','-c:a','pcm_s16le',str(wav)],check=True)
        with wave.open(str(wav),'rb') as w:audio=np.frombuffer(w.readframes(w.getnframes()),dtype='<i2').astype(np.float32)/32768
        print(f'Audio duration: {len(audio)/16000:.1f}s. Detecting speech...',flush=True)
        vad=Pyannote(torch.device('mps'),vad_onset=0.5,vad_offset=0.363,chunk_size=30)
        scores=vad({'waveform':vad.preprocess_audio(audio),'sample_rate':16000})
        parts=vad.merge_chunks(scores,30,onset=0.5,offset=0.363)
        del vad,scores,audio; gc.collect()
        if not parts:sys.exit('No speech detected; no transcript written.')
        part_file.write_text(json.dumps(parts),encoding='utf8')
        print('Transcribing speech using Apple GPU...',flush=True)
        subprocess.run([str(ROOT/'.whisper-mlx-venv/bin/python'),'-u',str(ROOT/'mlx_transcribe.py'),str(wav),str(part_file),str(result_file)],check=True)
        segments=json.loads(result_file.read_text(encoding='utf8'))['segments']
        if not segments:sys.exit('No speech transcribed; no transcript written.')
        args.output_dir.mkdir(parents=True,exist_ok=True)
        txt='\n\n'.join(x['text'].strip() for x in segments)+'\n'
        md='# Transcript\n\n> Timestamps indicate approximate detected speech sections; word-level alignment was not performed.\n\n'+'\n\n'.join(f"**[{stamp(x['start'])}–{stamp(x['end'])}]**\n\n{x['text'].strip()}" for x in segments)+'\n'
        srt='\n\n'.join(f"{i}\n{stamp(x['start'],True)} --> {stamp(x['end'],True)}\n{x['text'].strip()}" for i,x in enumerate(segments,1))+'\n'
        for path,content in zip(expected,(txt,srt,md)):path.write_text(content,encoding='utf8')
        print('Saved:',*(str(x) for x in expected),sep='\n',flush=True)
if __name__=='__main__':main()
