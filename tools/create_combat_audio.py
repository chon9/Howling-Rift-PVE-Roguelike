"""Grounded 48 kHz effects and processed local speech; no external samples/APIs."""
from pathlib import Path
import wave, subprocess, sys
import numpy as np
ROOT=Path(__file__).resolve().parents[1]/"assets/audio/combat-v2"
ROOT.mkdir(parents=True,exist_ok=True)
RATE=48000
rng=np.random.default_rng(912)
REPORT=[]
def band_noise(n,low=80,high=6000):
    x=rng.normal(0,1,n)
    f=np.fft.rfftfreq(n,1/RATE)
    weight=(f/(f+low+1))**2/(1+(f/high)**4)
    x=np.fft.irfft(np.fft.rfft(x)*weight,n)
    return x/max(0.001,np.std(x))
def tone(t,f,fall=0):
    return np.sin(2*np.pi*(f*t-fall*t*t/2))
def write(name,x,peak=.78):
    x=np.asarray(x,dtype=float)
    x=np.tanh(x*1.15)
    x*=peak/max(.001,np.max(np.abs(x)))
    # Short asymmetric early reflections; no long cartoon ringing.
    l=x.copy();r=x.copy()
    for delay,gain in [(.023,.06),(.047,.035)]:
        d=int(delay*RATE);dr=d+int(.004*RATE)
        l[d:]+=x[:-d]*gain
        r[dr:]+=x[:-dr]*gain
    stereo=np.clip(np.stack([l,r],axis=1),-.95,.95)
    with wave.open(str(ROOT/(name+".wav")),"wb") as out:
        out.setnchannels(2);out.setsampwidth(2);out.setframerate(RATE)
        out.writeframes((stereo*32767).astype('<i2').tobytes())
    REPORT.append((name,len(x)/RATE,float(np.sqrt(np.mean(stereo**2)))))
def make(name,duration,kind):
    n=int(duration*RATE);t=np.arange(n)/RATE
    air=band_noise(n,120,4300);low=band_noise(n,30,350)
    attack=np.minimum(1,t/.002)*np.minimum(1,(duration-t)/.035)
    impact=low*.34*np.exp(-t*24)+tone(t,82,180)*.42*np.exp(-t*26)
    metal=sum(np.sin(2*np.pi*f*t)*np.exp(-t*d)*a for f,d,a in [(463,38,.2),(917,48,.10),(1531,62,.07),(2477,75,.03)])
    if kind=='blade': x=air*.34*np.exp(-t*15)+metal*.8+impact*.7
    elif kind=='bow': x=air*.3*np.exp(-t*22)+tone(t,138)*.22*np.exp(-t*34)+low*.25*np.exp(-t*18)
    elif kind in ['fist','impact','hurt']: x=impact*1.4+air*.2*np.exp(-t*55)
    elif kind=='gun': x=impact*2+air*.7*np.exp(-t*70)+metal*.22
    elif kind in ['wind','dash']:
        envelope=np.sin(np.pi*np.clip(t/(duration*.7),0,1))**.8*np.exp(-t*3)
        x=air*.45*envelope+low*.20*envelope
    elif kind=='fire': x=low*.62*np.exp(-t*5)+air*.18*np.exp(-t*10)+tone(t,65,30)*.3*np.exp(-t*8)
    elif kind=='frost': x=air*.18*np.exp(-t*17)+metal*.35+low*.3*np.exp(-t*8)
    elif kind in ['magic','spirit','light']: x=air*.3*np.exp(-t*8)+low*.3*np.exp(-t*7)+tone(t,139 if kind=='magic' else 174,65)*.18*np.exp(-t*10)
    elif kind=='coin': x=metal*.25+air*.05*np.exp(-t*65)
    elif kind=='click': x=low*.15*np.exp(-t*80)+air*.08*np.exp(-t*100)
    elif kind in ['kill','death']: x=impact*.8+low*.3*np.exp(-t*9)+metal*.08
    elif kind=='level': x=air*.15*np.sin(np.pi*t/duration)+tone(t,162,38)*.10*np.exp(-t*6)
    else: x=low*.3*np.exp(-t*3)+tone(t,58 if kind=='victory' else 49,5)*.27*np.exp(-t*3)+air*.12*np.sin(np.pi*t/duration)
    if name.endswith('_ultimate'): x=x*.9+low*.38*np.exp(-t*5)+tone(t,54,12)*.35*np.exp(-t*8)
    write(name,x*attack,.73)
if '--announcer-only' not in sys.argv:
    for name,duration in [('bow',.25),('blade',.30),('fist',.22),('gun',.22),('wind',.42),('fire',.56),('frost',.35),('magic',.42),('spirit',.44),('light',.40),('impact',.16),('hurt',.22),('dash',.26),('coin',.16),('click',.07),('level',.48),('kill',.28),('death',.48),('victory',1.2),('defeat',1.2)]: make(name,duration,name)
    for kind in ['blade','fire','frost','magic','spirit','light','wind','fist','gun']: make(kind+'_ultimate',.85,kind)
for path in (ROOT/'voice-source').glob('*.wav'):
    with wave.open(str(path),'rb') as src:
        assert src.getsampwidth()==2 and src.getnchannels()==1
        x=np.frombuffer(src.readframes(src.getnframes()),dtype='<i2').astype(float)/32768
        rate=src.getframerate()
    active=np.flatnonzero(np.abs(x)>.008)
    if len(active): x=x[max(0,active[0]-int(.04*rate)):min(len(x),active[-1]+int(.12*rate))]
    # Preserve Zira's natural pitch; mild dynamics and filtering retain diction.
    temp=ROOT/(path.stem+'.voice-trim.wav')
    with wave.open(str(temp),'wb') as out:
        out.setnchannels(1);out.setsampwidth(2);out.setframerate(rate)
        out.writeframes((np.clip(x,-1,1)*32767).astype('<i2').tobytes())
    subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(temp),
        '-af','highpass=f=80,lowpass=f=8500,loudnorm=I=-18:TP=-2:LRA=7',
        '-ar',str(RATE),'-ac','2','-c:a','pcm_s16le',str(ROOT/(path.stem+'.wav'))],check=True)
    temp.unlink()
    with wave.open(str(ROOT/(path.stem+'.wav')),'rb') as src:
        result=np.frombuffer(src.readframes(src.getnframes()),dtype='<i2').astype(float)/32768
    REPORT.append((path.stem,len(result)/2/RATE,float(np.sqrt(np.mean(result**2)))))
# Reviewable preview: impact, kill cue, then spoken double/triple kill.
preview=[]
for name in ['blade','impact','kill','double_kill','triple_kill']:
    with wave.open(str(ROOT/(name+'.wav')),'rb') as src:
        preview.append(np.frombuffer(src.readframes(src.getnframes()),dtype='<i2').reshape(-1,2))
    preview.append(np.zeros((int(RATE*.35),2),dtype=np.int16))
with wave.open(str(ROOT/'moba-audio-preview.wav'),'wb') as out:
    out.setnchannels(2);out.setsampwidth(2);out.setframerate(RATE)
    out.writeframes(np.concatenate(preview).astype('<i2').tobytes())
# Female-only sample for checking speech without combat effects.
female_preview=[]
for name in ['first_blood','double_kill','triple_kill','killing_spree','victory_voice','defeat_voice']:
    with wave.open(str(ROOT/(name+'.wav')),'rb') as src:
        female_preview.append(np.frombuffer(src.readframes(src.getnframes()),dtype='<i2').reshape(-1,2))
    female_preview.append(np.zeros((int(RATE*.5),2),dtype=np.int16))
with wave.open(str(ROOT/'female-announcer-preview.wav'),'wb') as out:
    out.setnchannels(2);out.setsampwidth(2);out.setframerate(RATE)
    out.writeframes(np.concatenate(female_preview).astype('<i2').tobytes())
(ROOT/('ANNOUNCER_REPORT.txt' if '--announcer-only' in sys.argv else 'AUDIO_REPORT.txt')).write_text('\n'.join('%s %.3fs RMS %.3f'%row for row in REPORT),encoding='utf-8')
print('Created',len(REPORT),'audio clips in',ROOT)
