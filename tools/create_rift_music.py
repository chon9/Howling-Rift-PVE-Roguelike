"""Original restrained ambient score. No external recordings or samples.
Long harmonic phrases, softly damped piano resonances, no busy string ostinato.
"""
from pathlib import Path
import subprocess, wave, json
import numpy as np
ROOT=Path(__file__).resolve().parents[1]/"assets/audio/music"
RATE=48000
rng=np.random.default_rng(71205)
REPORT={}
def freq(note): return 440*2**((note-69)/12)
def pad(note,duration):
 t=np.arange(int(RATE*duration),dtype=np.float64)/RATE
 f=freq(note)
 # Rounded fundamental and a faint second partial, with slow envelope changes.
 x=np.sin(2*np.pi*f*t)*.62+np.sin(2*np.pi*f*1.0009*t+.6)*.23
 x+=np.sin(2*np.pi*f*2.0004*t+1.1)*.035
 attack=np.sin(np.clip(t/3.5,0,1)*np.pi/2)**2
 release=np.sin(np.clip((duration-t)/5,0,1)*np.pi/2)**2
 return (x*attack*release).astype(np.float32)
def piano(note,duration):
 t=np.arange(int(RATE*duration),dtype=np.float64)/RATE
 f=freq(note)
 x=np.zeros_like(t)
 # Slightly inharmonic string modes with damped upper partials, soft felt attack.
 for h in range(1,8):
  mode=f*h*np.sqrt(1+.00012*h*h)
  decay=np.exp(-t*(.32+.22*h))
  detuned=np.sin(2*np.pi*mode*t)+.25*np.sin(2*np.pi*mode*1.0008*t+.3)
  x+=detuned*decay/(h**2.6)
 attack=1-np.exp(-t/0.018)
 release=np.clip((duration-t)/1.2,0,1)
 return (x*attack*release).astype(np.float32)
def drum():
 t=np.arange(int(RATE*1.2))/RATE
 x=np.sin(2*np.pi*(62*t+1.3*(1-np.exp(-t*8))))*np.exp(-t*8)
 return (x*np.minimum(1,t/.012)*np.clip((1.2-t)/.1,0,1)).astype(np.float32)
def add(track,x,start,gain,pan=0):
 start=int(start*RATE)%len(track)
 stereo=x[:,None]*np.array([np.cos((pan+1)*np.pi/4),np.sin((pan+1)*np.pi/4)],dtype=np.float32)*gain
 count=min(len(x),len(track)-start)
 track[start:start+count]+=stereo[:count]
 if len(x)>count: track[:len(x)-count]+=stereo[count:]
def render(name,seconds,battle):
 track=np.zeros((seconds*RATE,2),dtype=np.float32)
 phrase=15.0
 chords=[[50,57,65],[46,53,62],[48,55,64],[43,58,62],
         [50,60,65],[45,57,64],[46,60,65],[48,57,62],
         [50,57,64],[43,53,62],[46,57,65],[50,57,65],
         [48,55,62],[45,57,64],[46,53,62],[50,57,65]]
 for i in range(int(seconds/phrase)):
  chord=chords[i]
  start=i*phrase
  energy=[.65,.8,.55,.9,.65,.75,.5,.8][i%8]
  for j,note in enumerate(chord):
   add(track,pad(note,phrase+7),start+j*.21,.06*energy,(j-1)/1.5)
  # Uneven pauses, varied registers and voicings; no constant arpeggio or beat.
  times=[2.7,8.8] if not battle else [1.8,6.4,11.2]
  for j,offset in enumerate(times):
   note=chord[(i+j)%3]+12+(12 if i in [5,11] and j==0 else 0)
   add(track,piano(note,6.5),start+offset,.12 if j==0 else .07,(-.22 if j%2 else .24))
  if battle and i%3==1:
   add(track,drum(),start+4.2,.022,0)
   add(track,drum(),start+10.6,.012,.12)
  if battle and i%4==0:
   add(track,pad(chord[0]-12,11),start+1,.018,-.1)
 # Diffuse circular stereo reflections, creating soft space without sharp echoes.
 dry=track.copy()
 for delay,gain in [(.193,.11),(.317,.095),(.487,.08),(.719,.06),(.983,.035), (1.271,.025)]:
  reflected=np.roll(dry,int(delay*RATE),axis=0)
  track+=reflected[:,::-1]*gain
 peak=float(np.max(np.abs(track)));rms=float(np.sqrt(np.mean(track**2)))
 # Use a restrained loudness target with generous headroom for piano accents.
 track*=min(.45/max(peak,.001),.075/max(rms,.001))
 REPORT[name]={"arrangement":"ambient-v2","seconds":seconds,"phrase_seconds":phrase,
  "peak":float(np.max(np.abs(track))),"rms":float(np.sqrt(np.mean(track**2))),
  "seam_delta":float(np.max(np.abs(track[0]-track[-1]))),"piano_notes":int(seconds/phrase)*(3 if battle else 2)}
 return track
def wave_file(path,x):
 with wave.open(str(path),"wb") as file:
  file.setnchannels(2);file.setsampwidth(2);file.setframerate(RATE)
  file.writeframes((np.clip(x,-1,1)*32767).astype("<i2").tobytes())
def ogg(name,x):
 intermediate=ROOT/(name+".render.wav")
 wave_file(intermediate,x)
 subprocess.run(["ffmpeg","-hide_banner","-loglevel","error","-y","-i",str(intermediate),"-c:a","libvorbis","-q:a","5",str(ROOT/(name+".ogg"))],check=True)
 intermediate.unlink()
if __name__=="__main__":
 ROOT.mkdir(parents=True,exist_ok=True)
 menu=render("oath-of-the-rift",180,False)
 battle=render("bridge-of-embers",240,True)
 ogg("oath-of-the-rift",menu);ogg("bridge-of-embers",battle)
 preview=np.concatenate([menu[RATE*2:RATE*17],np.zeros((RATE,2),dtype=np.float32),battle[RATE*17:RATE*37]])
 fade=int(RATE*.7)
 preview[:fade]*=np.linspace(0,1,fade)[:,None];preview[-fade:]*=np.linspace(1,0,fade)[:,None]
 wave_file(ROOT/"rift-music-preview.wav",preview)
 (ROOT/"MUSIC_REPORT.json").write_text(json.dumps(REPORT,indent=2),encoding="utf-8")
 print(json.dumps(REPORT))
