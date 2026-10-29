#!/usr/bin/env python3
import subprocess,sys
from pathlib import Path
root=Path(__file__).resolve().parent
if len(sys.argv) not in (3,4):sys.exit('Expected audio, output directory and optional mode')
audio=Path(sys.argv[1]);out=Path(sys.argv[2]);mode=sys.argv[3] if len(sys.argv)==4 else '--summary'
if mode not in ('--transcribe-only','--summary','--full'):sys.exit('Unknown mode')
script='transcribe_full.py' if mode=='--full' else 'transcribe.py'
result=subprocess.run([str(root/'.venv/bin/python'),'-u',str(root/script),str(audio),'--output-dir',str(out)])
if result.returncode:sys.exit(1)
if mode=='--transcribe-only':print('Transcription finished; summary skipped.',flush=True);sys.exit(0)
print('Starting local summary...',flush=True)
result=subprocess.run([str(root/'.summary-venv/bin/python'),'-u',str(root/'summarize.py'),str(out/(audio.stem+'.md')),str(out/(audio.stem+'-lecture-summary.md'))])
if result.returncode:print('Transcription succeeded, but summary failed. Transcript files are preserved.',flush=True);sys.exit(2)
print('All finished.',flush=True)
