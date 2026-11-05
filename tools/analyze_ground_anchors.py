"""Analyze alpha silhouettes without altering the generated artwork."""
from pathlib import Path
from PIL import Image
import numpy as np
import json
ROOT=Path(__file__).resolve().parents[1]
anchors={}
def record(key,image):
 a=np.array(image.convert("RGBA"))[:,:,3]>48
 coverage=a.sum(axis=1)
 rows=np.flatnonzero(coverage>=max(3,image.width*0.008))
 if not len(rows): raise ValueError(key)
 bottom=int(rows[-1])+1
 feet=a[max(int(rows[0]),bottom-max(3,int((bottom-rows[0])*0.10))):bottom]
 weights=feet.sum(axis=0)
 x=float(np.sum((np.arange(image.width)+.5)*weights)/weights.sum())
 anchors[key]=[x/image.width,bottom/image.height]
for key in ["ashe","annie","garen","lux","ahri","ezreal"]:
 record("hero_"+key,Image.open(ROOT/f"assets/champions/{key}-painted.png"))
im=Image.open(ROOT/"assets/champions/extended-roster.png")
for i,key in enumerate(["yasuo","leesin","zed","jinx","katarina","kayle"]):
 w,h=im.width/3,im.height/2
 record("hero_"+key,im.crop((int(i%3*w),int(i//3*h),int((i%3+1)*w),int((i//3+1)*h))))
im=Image.open(ROOT/"assets/minions/minion-roster-v2.png")
for row,key in enumerate(["melee","caster","siege","super","tibbers"]):
 for col in range(4):
  w,h=im.width/4,im.height/5
  record(f"minion_{key}_{col}",im.crop((int(col*w),int(row*h),int((col+1)*w),int((row+1)*h))))
im=Image.open(ROOT/"assets/structures/rift-structures.png")
for team,col in [(0,0),(1,512)]:
 for key,box in [("turret",(64,0,464,576)),("inhibitor",(24,576,488,952)),("nexus",(8,952,512,1536))]:
  box=(box[0]+col,box[1],box[2]+col,box[3])
  record(f"structure_{team}_{key}",im.crop(box))
(ROOT/"assets/ground-anchors.json").write_text(json.dumps(anchors,indent=2),encoding="utf-8")
print(f"Analyzed {len(anchors)} ground anchors")
