"""Read-only atlas inspection; write crop metadata without editing generated PNGs."""
from pathlib import Path
import json
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
KEYS=['leona','blitzcrank','renekton','xinzhao','riven','fiora','caitlyn','lucian','sivir','brand','syndra','xerath']
crops={}
for key in KEYS:
 im=Image.open(ROOT/f'assets/vfx/{key}-skills-v1.png').convert('RGBA');a=np.array(im)[:,:,3]
 assert a.min()==0,f'{key} missing transparency'
 frames=[]
 for row in range(4):
  for col in range(4):
   x0=round(col*im.width/4)+2;y0=round(row*im.height/4)+2;x1=round((col+1)*im.width/4)-2;y1=round((row+1)*im.height/4)-2
   yy,xx=np.nonzero(a[y0:y1,x0:x1]>100)
   assert len(xx)>50,(key,row,col)
   frames.append([x0,y0,x1-x0,y1-y0])
 crops[key]=frames
(ROOT/'assets/vfx/roster12-crops.json').write_text(json.dumps(crops,indent=2)+'\n',encoding='utf-8')
icons={}
for group in range(3):
 im=Image.open(ROOT/f'assets/ui/roster12-icons-{group}-v1.png').convert('RGB');rgb=np.array(im).astype(float)
 gold=(rgb[:,:,0]>125)&(rgb[:,:,1]>100)&(rgb[:,:,2]<rgb[:,:,0]*.72)&(rgb[:,:,1]<rgb[:,:,0]*1.03)
 rows=[[(11,269),(287,522),(540,788),(806,1043),(1061,1387)],[(9,273),(289,518),(534,778),(794,1020),(1036,1350)],[(7,271),(284,521),(533,793),(806,1048),(1061,1393)]][group]
 icons[str(group)]=[]
 for top,bottom in rows:
  for col in range(4):
   icons[str(group)].append([round(col*im.width/4)+9,top+2,round(im.width/4)-18,bottom-top-4])
 edges=rows
 print('Icon borders',group,edges)
(ROOT/'assets/ui/roster12-icon-crops.json').write_text(json.dumps(icons,indent=2)+'\n',encoding='utf-8')
print('Mapped 192 VFX frames and 60 portraits/skill icons')
