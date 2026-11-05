"""Read generated alpha silhouettes to map real action cells; never alter artwork."""
from pathlib import Path
from PIL import Image
import numpy as np, json, argparse
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/"assets/animations"
HERO_ACTIONS=["idle","run","attack","q","w","e","r","hit","death","recall"]
MINION_ACTIONS=["idle","run","attack","hit","death"]
# Visually inspected omissions are supplied by a separate generated action strip.
OVERRIDES={
 "sivir":{"actions":["idle","run","attack","q","w","e","r","death","recall"],"extra":("hit",0),"extra_path":"zephyr-hit-v1.png","extra_actions":["hit"]},
 "yasuo":{"skip":["r"],"extra":("r",0),"extra_path":"yasuo-ultimate-v1.png","extra_actions":["r"]},
 "katarina":{"actions":["idle","run","attack","q","w","r","hit","death","recall"],"cuts":[0,178,327,495,656,831,999,1180,1376,1619],"extra":("e",0)},
 "annie":{"actions":["idle","run","attack","q","w","e","r","death","recall"],"cuts":[0,171,325,493,646,802,973,1145,1320,1540],"extra":("hit",1)},
 "lux":{"actions":["idle","run","attack","q","w","e","hit","death","recall"],"cuts":[0,170,329,497,668,819,1020,1202,1380,1619],"extra":("r",2)}
}
parser=argparse.ArgumentParser();parser.add_argument('--heroes',nargs='*');selected=parser.parse_args().heroes
manifest=json.loads((OUT/'manifest.json').read_text(encoding='utf-8')) if selected else {}
reports=json.loads((OUT/'ATLAS_REPORT.json').read_text(encoding='utf-8')) if selected else {}
def cuts_for(im,rows,manual=None):
 if manual is not None: return [round(y*im.height/1619) for y in manual]
 alpha=np.array(im.getchannel('A'))>144
 coverage=alpha.sum(axis=1).astype(float)
 smooth=np.convolve(coverage,np.ones(5)/5,mode='same')
 cuts=[0]
 for i in range(1,rows):
  target=im.height*i/rows
  radius=im.height/rows*.19
  points=np.arange(max(cuts[-1]+20,int(target-radius)),min(im.height-1,int(target+radius)))
  # Prefer actual empty gutters near the nominal cut, not rigid assumed dimensions.
  score=smooth[points]+np.abs(points-target)*.3
  cuts.append(int(points[np.argmin(score)]))
 cuts.append(im.height)
 return cuts
def main_component_bounds(alpha):
 # Read-only connected-component analysis: exclude neighbor fragments that
 # share a grid cell. The actual generated PNGs are kept untouched.
 runs=[];parents=[];previous=[]
 def root(i):
  while parents[i]!=i:
   parents[i]=parents[parents[i]];i=parents[i]
  return i
 for y,row in enumerate(alpha):
  edges=np.diff(np.pad(row.astype(np.int8),(1,1)))
  current=[]
  for x0,x1 in zip(np.where(edges==1)[0],np.where(edges==-1)[0]):
   i=len(runs);parents.append(i);runs.append((int(x0),int(x1),y));current.append(i)
   for j in previous:
    px0,px1,_=runs[j]
    if px0>x1:break
    if px1>=x0:parents[root(j)]=root(i)
  previous=current
 groups={}
 for i,(x0,x1,y) in enumerate(runs):
  k=root(i)
  if k not in groups:groups[k]=[x1-x0,x0,y,x1,y+1]
  else:
   g=groups[k];g[0]+=x1-x0;g[1]=min(g[1],x0);g[2]=min(g[2],y);g[3]=max(g[3],x1);g[4]=y+1
 largest=max(groups,key=lambda k:groups[k][0])
 mask=np.zeros_like(alpha)
 for i,(x0,x1,y) in enumerate(runs):
  if root(i)==largest:mask[y,x0:x1]=True
 exclusions=[]
 for k,g in groups.items():
  if k==largest or g[0]<8:continue
  _,x0,y0,x1,y1=g
  x0=max(0,x0-1);y0=max(0,y0-1);x1=min(alpha.shape[1],x1+1);y1=min(alpha.shape[0],y1+1)
  # Exclude only isolated scraps; never cut the actual actor silhouette.
  if not mask[y0:y1,x0:x1].any():exclusions.append([x0,y0,x1,y1])
 exclusions.sort(key=lambda b:(b[2]-b[0])*(b[3]-b[1]),reverse=True)
 return groups[largest][1:],mask,exclusions[:8]

def inspect(im,box,key):
 x0,y0,x1,y1=box
 raw=np.array(im.crop(box).getchannel('A'))>96
 (left,top,right,bottom),main_mask,exclusions=main_component_bounds(raw)
 original_x,original_y=x0,y0
 exclusions=[[x0+b[0],y0+b[1],x0+b[2],y0+b[3]] for b in exclusions]
 box=(max(x0,x0+left-2),max(y0,y0+top-2),min(x1,x0+right+2),min(y1,y0+bottom+2))
 x0,y0,x1,y1=box
 a=np.array(im.crop(box).convert('RGBA'))[:,:,3]>144
 a &= main_mask[y0-original_y:y1-original_y,x0-original_x:x1-original_x]
 yy,xx=np.nonzero(a)
 if len(xx)<60: raise ValueError('Empty action cell: '+key)
 left,right=int(xx.min()),int(xx.max())+1
 top,bottom=int(yy.min()),int(yy.max())+1
 feet=a[max(top,bottom-max(3,int((bottom-top)*.10))):bottom]
 weights=feet.sum(axis=0)
 px=float(np.sum((np.arange(a.shape[1])+.5)*weights)/max(1,weights.sum()))
 return {"region":[x0,y0,x1-x0,y1-y0],"pivot":[px,float(bottom)],"body":[left,top,right-left,bottom-top],"opaque_pixels":int(len(xx)),"exclusions":exclusions}
def mapped_rows(im,path,actions,manual=None,skip=None):
 cuts=cuts_for(im,len(actions),manual)
 result={}
 for row,action in enumerate(actions):
  if action in (skip or []): continue
  frames=[]
  # Generated poses are not on mathematically uniform column boundaries.
  # Follow the per-row transparent gutters, including wide weapons and tails.
  a=np.array(im.getchannel('A'))[cuts[row]:cuts[row+1]]>144
  coverage=np.convolve(a.sum(axis=0).astype(float),np.ones(3)/3,mode='same')
  columns=[0]
  for boundary in range(1,6):
   target=im.width*boundary/6;radius=im.width/6*.32
   points=np.arange(max(columns[-1]+20,int(target-radius)),min(im.width-1,int(target+radius)))
   scores=coverage[points]+np.abs(points-target)*.12
   columns.append(int(points[np.argmin(scores)]))
  columns.append(im.width)
  for col in range(6):
   box=(columns[col],cuts[row],columns[col+1],cuts[row+1])
   frames.append(inspect(im,box,path+':'+action+':'+str(col)))
  result[action]=frames
 return result
for category in ['heroes','minions']:
 for file in sorted((OUT/category).glob('*-actions-v1.png')):
  name=file.name.split('-actions-')[0]
  if selected and (category!='heroes' or name not in selected):continue
  key=('hero_' if category=='heroes' else 'minion_')+name
  im=Image.open(file).convert('RGBA')
  if not im.getchannel('A').getextrema()[0]==0: raise ValueError('Missing alpha: '+key)
  logical=HERO_ACTIONS if category=='heroes' else MINION_ACTIONS
  override=OVERRIDES.get(name,{})
  path='res://'+file.relative_to(ROOT).as_posix()
  rows=mapped_rows(im,path,override.get('actions',logical),override.get('cuts'),override.get('skip'))
  if override.get('extra'):
   extra_action,extra_row=override['extra']
   supplemental=OUT/override.get('extra_path','hero-action-supplements-v1.png')
   supplemental_im=Image.open(supplemental).convert('RGBA')
   supplemental_path='res://'+supplemental.relative_to(ROOT).as_posix()
   all_extra=mapped_rows(supplemental_im,supplemental_path,override.get('extra_actions',['e','hit','r']))
   rows[extra_action]=all_extra[extra_action]
   for cell in rows[extra_action]:
    cell['path']=supplemental_path
    cell['relative_scale']=im.width/supplemental_im.width
  supplements={"caitlyn":["q"],"lucian":["q"],"sivir":["q"],"brand":["q","w"],"syndra":["attack"],"xerath":["q","e"]}
  if name in supplements:
   supplemental=OUT/(name+'-cast-repair-v1.png')
   supplemental_im=Image.open(supplemental).convert('RGBA')
   supplemental_path='res://'+supplemental.relative_to(ROOT).as_posix()
   extra=mapped_rows(supplemental_im,supplemental_path,supplements[name])
   for action,cells in extra.items():
    relative=float(np.median([f['body'][3] for f in rows['idle']]))/float(np.median([f['body'][3] for f in cells]))
    for cell in cells:cell['path']=supplemental_path;cell['relative_scale']=relative
    rows[action]=cells
  if name=='sivir':
   relative=float(np.median([f['body'][3] for f in rows['idle']]))/float(np.median([f['body'][3] for f in rows['hit']]))
   for cell in rows['hit']:cell['relative_scale']=relative
  body_height=float(np.median([f['body'][3] for f in rows['idle']]))
  base=np.median([[f['pivot'][0]/f['region'][2],f['pivot'][1]/f['region'][3]] for f in rows['idle']],axis=0)
  frames=[]
  for action in logical:
   for frame in rows[action]:
    # Airborne ultimate poses preserve their authored height; corpses stay grounded.
    if name=='yasuo' and action=='r':
     frame['pivot'][1]=float(np.median([f['region'][1]+f['pivot'][1] for f in rows['r'][-2:]]))-frame['region'][1]
    frames.append(frame)
  manifest[key]={"path":path,"actions":{action:i for i,action in enumerate(logical)},"columns":6,"body_height":body_height,"frames":frames}
  reports[key]={"source_size":[im.width,im.height],"actions":len(logical),"frames":len(frames),"body_height":body_height,"minimum_opaque_pixels":min(f['opaque_pixels'] for f in frames)}
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
(OUT/'ATLAS_REPORT.json').write_text(json.dumps(reports,indent=2),encoding='utf-8')
print('Mapped',len(manifest),'units and',sum(len(v['frames']) for v in manifest.values()),'real frames')
