"""Independent Python model of tile flood fill and fragment merging."""
import numpy as np
from make_test_vectors import golden

def clean_runs(mask):
 # Qualify complete horizontal runs of >=3 within each tile row.
 # This independently models run-length crediting in the RTL.
 out=np.zeros_like(mask,dtype=bool)
 for y in range(mask.shape[0]):
  for tile in range(mask.shape[1]//8):
   start=tile*8;run=[]
   for x in range(start,start+8):
    if mask[y,x]:run.append(x)
    else:
     if len(run)>=3:out[y,run]=True
     run=[]
   if len(run)>=3:out[y,run]=True
 return out

def boxes_from_categories(cat,origin=(0,0)):
 mask=clean_runs(cat==1)
 tiles=[]
 for ty in range(30):
  for tx in range(40):
   yy,xx=np.where(mask[ty*8:ty*8+8,tx*8:tx*8+8]);count=len(xx)
   tiles.append(0 if not count else (count<<12)|(int(yy.max())<<9)|(int(yy.min())<<6)|(int(xx.max())<<3)|int(xx.min()))
 packed=golden(tiles,minhits=8,minpixels=16,minwidth=4,minheight=4)
 boxes=[]
 for i in range(3):
  b=(packed>>(35*i))&((1<<35)-1)
  boxes.append(None if not b>>34 else [(b>>25)&511,(b>>16)&511,(b>>8)&255,b&255])
 for _ in range(2):
  for i in range(3):
   for j in range(i+1,3):
    a,b=boxes[i],boxes[j]
    if a is None or b is None:continue
    xo=a[0]<=b[1] and b[0]<=a[1];yo=a[2]<=b[3] and b[2]<=a[3]
    if (xo and a[2]<=b[3]+17 and b[2]<=a[3]+17) or (yo and a[0]<=b[1]+17 and b[0]<=a[1]+17):
     boxes[i]=[min(a[0],b[0]),max(a[1],b[1]),min(a[2],b[2]),max(a[3],b[3])];boxes[j]=None
 return boxes

def body_patch(crop,categories,width=72):
 from PIL import Image
 h=max(16,round(width*crop.height/crop.width))
 small=crop.resize((width,h),Image.Resampling.BILINEAR)
 cat=np.zeros((240,320),dtype=np.uint8);cat[25:25+h,20:20+width]=categories(small)
 b=boxes_from_categories(cat)[0]
 if b is None:raise ValueError('Reference has no usable foreground body')
 x0,x1,y0,y1=b
 return cat[y0:y1+1,x0:x1+1]
