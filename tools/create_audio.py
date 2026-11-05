"""Original 48 kHz stereo effects with physical resonances and short room tails."""
from pathlib import Path
import math, random, struct, wave
ROOT = Path(__file__).resolve().parents[1] / "assets" / "audio"
ROOT.mkdir(parents=True, exist_ok=True)
RATE = 48000
rng = random.Random(73)

def sine(t, f): return math.sin(math.tau * t * f)
def chirp(t, f, slope): return math.sin(math.tau * (f*t + slope*t*t*.5))
def metal(t):
    return sum(sine(t,f)*math.exp(-t*d)*a for f,d,a in [(713,22,.3),(1183,16,.2),(1777,25,.14),(2731,33,.1)])

def make(name, length, kind, power=1.0):
    samples=[]; low=0.; previous=0.
    for i in range(int(length*RATE)):
        t=i/RATE
        noise=rng.uniform(-1,1); low=.94*low+.06*noise; high=noise-previous;previous=noise
        if kind=="bow":
            value=(sine(t,164)+.5*sine(t,329)+.2*sine(t,659))*math.exp(-t*32)*.4 + high*math.exp(-t*70)*.18 + low*math.exp(-t*13)*1.3
        elif kind=="blade":
            value=metal(t)+high*math.exp(-t*70)*.22+low*math.exp(-t*14)*1.5+chirp(t,110,-180)*math.exp(-t*25)*.28
        elif kind=="fire":
            value=low*2.8*math.exp(-t*5)+noise*.18*math.exp(-t*8)+chirp(t,80,-50)*math.exp(-t*12)*.5
        elif kind=="frost":
            value=metal(t)*.7+chirp(t,1600,-2200)*math.exp(-t*15)*.15+high*math.exp(-t*23)*.1+low*1.2*math.exp(-t*7)
        elif kind in ("magic","spirit","light"):
            root={"magic":196,"spirit":220,"light":261.63}[kind]
            value=sum(chirp(t,root*r,root*.7)*a for r,a in [(1,.23),(1.5,.14),(2,.09),(3,.05)])*math.exp(-t*7)+low*math.exp(-t*9)*1.3
        elif kind in ("impact","hurt"):
            value=chirp(t,100,-350)*math.exp(-t*25)*.55+low*math.exp(-t*28)*2.4+high*math.exp(-t*90)*.15
        elif kind=="dash": value=low*math.sin(math.pi*min(1,t/.22))*1.8+high*math.exp(-t*25)*.09
        elif kind=="coin": value=metal(t)*.4+sum(sine(t,f)*math.exp(-t*25) for f in [1837,2491,3203])*.08
        else: value=low*math.exp(-t*40)*.8+sine(t,200)*math.exp(-t*50)*.16
        if power>1:
            value += chirp(t,60,-25)*math.exp(-t*5)*.35+low*math.exp(-t*4)*1.5
        samples.append(math.tanh(value*power)*.75*min(1,t/.003)*min(1,(length-t)/.05))
    write(name,samples)

def write(name, samples):
    # Decorrelated early reflections give width without drowning fast combat.
    out=[]
    for i,value in enumerate(samples):
        left=value;right=value
        for delay,gain in [(.031,.13),(.063,.09),(.109,.045)]:
            j=i-int(delay*RATE)
            if j>=0:left+=samples[j]*gain
            j=i-int((delay+.007)*RATE)
            if j>=0:right+=samples[j]*gain
        out.append(struct.pack("<hh",int(max(-.95,min(.95,left))*32767),int(max(-.95,min(.95,right))*32767)))
    with wave.open(str(ROOT/(name+".wav")),"wb") as output:
        output.setnchannels(2);output.setsampwidth(2);output.setframerate(RATE);output.writeframes(b"".join(out))

for key,length in [("bow",.3),("blade",.4),("fire",.65),("frost",.55),("magic",.5),("spirit",.55),("light",.6),("impact",.22),("hurt",.3),("dash",.3),("coin",.35),("click",.10)]:make(key,length,key)
for key in ["blade","fire","frost","magic","spirit","light"]:make(key+"_ultimate",1.05,key,1.6)
for name,notes in [("level",[392,494,587,784]),("kill",[330,494,659]),("death",[220,175,131]),("victory",[262,330,392,523,659]),("defeat",[294,262,220,147])]:
    length=1.7 if name in ("victory","defeat") else .9
    data=[]
    for i in range(int(length*RATE)):
        t=i/RATE;value=0.
        for index,f in enumerate(notes):
            age=t-index*.13
            if age>=0:value+=(sine(age,f)+.22*sine(age,f*2)+.12*sine(age,f*3))*math.exp(-age*7)*.25
        data.append(value*min(1,t/.004)*min(1,(length-t)/.06))
    write(name,data)
print("Created 23 original stereo effects in",ROOT)
