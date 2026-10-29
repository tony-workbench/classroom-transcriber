import json,os,sys,wave,time
from pathlib import Path
root=Path(__file__).resolve().parent
os.environ['HF_HUB_OFFLINE']='1';os.environ['HF_HUB_DISABLE_TELEMETRY']='1';os.environ['HF_HOME']=str(root/'cache'/'whisper-mlx-hf')
import numpy as np,mlx_whisper
with wave.open(sys.argv[1],'rb') as w: audio=np.frombuffer(w.readframes(w.getnframes()),dtype='<i2').astype(np.float32)/32768
parts=json.loads(Path(sys.argv[2]).read_text());segments=[]
for i,part in enumerate(parts,1):
 a=max(0,float(part['start']));b=min(len(audio)/16000,float(part['end']))
 if b<=a:continue
 print(f'GPU transcription: {i}/{len(parts)}',flush=True)
 r=mlx_whisper.transcribe(audio[int(a*16000):int(b*16000)],path_or_hf_repo=str(root/'cache'/'whisper-mlx'),language='en',verbose=None,condition_on_previous_text=False)
 if r.get('text','').strip():segments.append({'start':a,'end':b,'text':r['text']})
Path(sys.argv[3]).write_text(json.dumps({'segments':segments,'language':'en'},ensure_ascii=False),encoding='utf8')
