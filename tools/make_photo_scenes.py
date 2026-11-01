"""Same-camera-photo regression fixtures; not held-out validation."""
from pathlib import Path
import json
import numpy as np
from PIL import Image,ImageEnhance
from build_references import categories,sample,cost
from make_test_vectors import golden
from foreground_model import clean_runs
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'sim/vectors';OUT.mkdir(exist_ok=True)
m=json.loads((ROOT/'reference/manifest.json').read_text())
refs=np.loadtxt(ROOT/'reference/all_templates.hex',dtype=np.uint8).reshape(236,16,16)
cares=np.loadtxt(ROOT/'reference/all_care.hex',dtype=np.uint8).reshape(236,16,16)>0
results=[]
placements=[[(i,20,25,72)] for i in range(53)]+[[(0,10,16,100),(14,15,135,100),(32,210,115,95)],[(0,150,60,100)]]
placements += [[(i,110,65,72)] for i in [0,14,32] for _ in range(2)]
# Thirty noisy/shifted front and rear calibration perturbations.
front_indices=[1,3,15,17,33,36]
placements += [[(i,35+j%3,35+j%2,[56,72,88,72,72][j])] for i in front_indices for j in range(5)]
placements += [[(i,40,40,w)] for i in range(53,59) for w in [20,28,40,72]]
def class_for(k):return 1 if k<56 else 2 if k<128 else 3 if k<212 else 2 if k<220 else 1 if k<228 else 3
for n,places in enumerate(placements):
 im=Image.new('RGB',(320,240),(33,32,33))
 for cls,x,y,w in places:
  crop=Image.open(ROOT/'reference'/(m['sources'][cls]['label']+'.png')).convert('RGB')
  h=round(w*crop.height/crop.width);part=crop.resize((w,h),Image.Resampling.BILINEAR)
  if n==54:part=part.transpose(Image.Transpose.ROTATE_270)
  if 55<=n<61:part=ImageEnhance.Brightness(part).enhance(.60 if (n-55)%2==0 else 1.35)
  im.paste(part,(x,y))
 if 61<=n<91:
  rng=np.random.default_rng(6100+n)
  aa=np.array(im)
  # Isolated colour speckles over the neutral background and 2% body dropouts.
  body=np.zeros((240,320),dtype=bool)
  for cls,x,y,w in places:body[y:y+part.height,x:x+part.width]=True
  speckles=(rng.random((240,320))<.06)&~body
  aa[speckles]=[255,255,0]
  holes=(rng.random((240,320))<.02)&body
  aa[holes]=[33,32,33]
  im=Image.fromarray(aa)
 a=np.asarray(im,dtype=np.int32)
 pix=((a[:,:,0]>>3)<<11)|((a[:,:,1]>>2)<<5)|(a[:,:,2]>>3)
 r=(pix>>11)&31;r=(r<<3)|(r>>2);g=(pix>>5)&63;g=(g<<2)|(g>>4);b=pix&31;b=(b<<3)|(b>>2)
 gray=(r+2*g+b)//4;cat=categories(im);changed=clean_runs(cat==1);tiles=[]
 for ty in range(30):
  for tx in range(40):
   yy,xx=np.where(changed[ty*8:ty*8+8,tx*8:tx*8+8]);count=len(xx)
   tiles.append(0 if not count else (count<<12)|(int(yy.max())<<9)|(int(yy.min())<<6)|(int(xx.max())<<3)|int(xx.min()))
 candidates=golden(tiles,minhits=8,minpixels=16,minwidth=4,minheight=4)
 bs=[(candidates>>(35*i))&((1<<35)-1) for i in range(3)]
 def unpack(b):return [(b>>25)&511,(b>>16)&511,(b>>8)&255,b&255]
 for repeat in range(2):
  for i in range(3):
   for j in range(i+1,3):
    if not (bs[i]>>34 and bs[j]>>34):continue
    a=unpack(bs[i]);b=unpack(bs[j]);xo=a[0]<=b[1] and b[0]<=a[1];yo=a[2]<=b[3] and b[2]<=a[3]
    if (xo and a[2]<=b[3]+17 and b[2]<=a[3]+17) or (yo and a[0]<=b[1]+17 and b[0]<=a[1]+17):
     bs[i]=(1<<34)|(min(a[0],b[0])<<25)|(max(a[1],b[1])<<16)|(min(a[2],b[2])<<8)|max(a[3],b[3]);bs[j]=0
 candidates=sum(b<<(35*i) for i,b in enumerate(bs));accepted=0;ids=0;details=[]
 for slot in range(3):
  box=(candidates>>(35*slot))&((1<<35)-1)
  if not box>>34:continue
  x0=(box>>25)&511;x1=(box>>16)&511;y0=(box>>8)&255;y1=box&255;w=x1-x0+1;h=y1-y0+1
  q=sample(cat[y0:y1+1,x0:x1+1]);best=1023;bk=None
  for k,(_,flip,limit,amin,amax,variant,rotation) in enumerate(m['templates']):
   d=cost(q,refs[k],cares[k])
   if h*amin<=w*100<=h*amax and d<=limit and d<best:best=d;bk=k
  if bk is not None:
   rot=0;pad=(w if rot%2 else h)//4
   dl=max(0,x0-2-(pad if rot==1 else 0));dr=min(319,x1+2+(pad if rot==3 else 0))
   dt=max(0,y0-2-(pad if rot==2 else 0));db=min(239,y1+2+(pad if rot==0 else 0))
   draw=(1<<34)|(dl<<25)|(dr<<16)|(dt<<8)|db
   accepted|=draw<<(slot*35);ids|=class_for(bk)<<(slot*2)
  details.append({'raw_box':[x0,x1,y0,y1],'class':None if bk is None else class_for(bk),'cost':best})
 (OUT/f'photo_scene_{n}.hex').write_text(''.join(f'{int(v):04x}\n' for v in pix.ravel()))
 im.save(OUT/f'photo_scene_{n}.png')
 results.append({'scene':n,'boxes':f'{accepted:027x}','ids':ids,'details':details})
(OUT/'photo_expected.hex').write_text(''.join(x['boxes']+'\n' for x in results))
(OUT/'photo_ids.hex').write_text(''.join(f'{x["ids"]:02x}\n' for x in results))
(OUT/'photo_scene_results.json').write_text(json.dumps(results,indent=2)+'\n')
print(json.dumps(results,indent=2))
