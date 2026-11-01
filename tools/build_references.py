#!/usr/bin/env python3
"""V6: monitor-photo references for yellow-body candidate boxes.
These images are calibration data, not held-out validation.
"""
from pathlib import Path
import json,hashlib,argparse,io
import numpy as np
from PIL import Image,ImageFilter,ImageEnhance
from foreground_model import body_patch
ROOT=Path(__file__).resolve().parents[1]
# Coarse manual ROIs exclude the desk outside each toy; automatic yellow-body
# bounds within these ROIs exclude most black wheels and grey surroundings.
SPECS=[('dump_page_12', 'source_dump_page_12.png', (0, 0, 1639, 782)), ('dump_page_13', 'source_dump_page_13.png', (0, 0, 1639, 782)), ('dump_page_14', 'source_dump_page_14.png', (0, 0, 1639, 782)), ('dump_page_15', 'source_dump_page_15.png', (0, 0, 1639, 782)), ('dump_page_16', 'source_dump_page_16.png', (0, 0, 1639, 782)), ('dump_page_17', 'source_dump_page_17.png', (0, 0, 1639, 782)), ('dump_page_18', 'source_dump_page_18.png', (0, 0, 1639, 782)), ('dump_page_19', 'source_dump_page_19.png', (0, 0, 1639, 782)), ('dump_page_20', 'source_dump_page_20.png', (0, 0, 1639, 782)), ('dump_page_42', 'source_dump_page_42.png', (0, 0, 1639, 782)), ('dump_page_43', 'source_dump_page_43.png', (0, 0, 1639, 782)), ('dump_page_44', 'source_dump_page_44.png', (0, 0, 1639, 782)), ('dump_page_45', 'source_dump_page_45.png', (0, 0, 1639, 782)), ('dump_page_46', 'source_dump_page_46.png', (0, 0, 1639, 782)), ('van_page_01', 'source_van_page_01.png', (0, 0, 1639, 782)), ('van_page_02', 'source_van_page_02.png', (0, 0, 1093, 656)), ('van_page_03', 'source_van_page_03.png', (0, 0, 1066, 591)), ('van_page_04', 'source_van_page_04.png', (0, 0, 950, 546)), ('van_page_05', 'source_van_page_05.png', (0, 0, 1014, 611)), ('van_page_06', 'source_van_page_06.png', (0, 0, 1076, 612)), ('van_page_07', 'source_van_page_07.png', (0, 0, 1052, 619)), ('van_page_08', 'source_van_page_08.png', (0, 0, 1049, 615)), ('van_page_09', 'source_van_page_09.png', (0, 0, 1034, 582)), ('van_page_10', 'source_van_page_10.png', (0, 0, 1639, 782)), ('van_page_11', 'source_van_page_11.png', (0, 0, 1639, 782)), ('van_page_47', 'source_van_page_47.png', (0, 0, 1639, 782)), ('van_page_48', 'source_van_page_48.png', (0, 0, 1639, 782)), ('van_page_49', 'source_van_page_49.png', (0, 0, 1639, 782)), ('van_page_50', 'source_van_page_50.png', (0, 0, 1639, 782)), ('van_page_51', 'source_van_page_51.png', (0, 0, 1639, 782)), ('van_page_52', 'source_van_page_52.png', (0, 0, 1639, 782)), ('van_page_53', 'source_van_page_53.png', (0, 0, 1639, 782)), ('construction_page_21', 'source_construction_page_21.png', (0, 0, 1639, 782)), ('construction_page_22', 'source_construction_page_22.png', (0, 0, 1639, 782)), ('construction_page_23', 'source_construction_page_23.png', (0, 0, 1639, 782)), ('construction_page_24', 'source_construction_page_24.png', (0, 0, 1639, 782)), ('construction_page_25', 'source_construction_page_25.png', (0, 0, 1639, 782)), ('construction_page_26', 'source_construction_page_26.png', (0, 0, 1639, 782)), ('construction_page_27', 'source_construction_page_27.png', (0, 0, 1639, 782)), ('construction_page_28', 'source_construction_page_28.png', (0, 0, 1639, 782)), ('construction_page_29', 'source_construction_page_29.png', (0, 0, 1639, 782)), ('construction_page_30', 'source_construction_page_30.png', (0, 0, 1639, 782)), ('construction_page_31', 'source_construction_page_31.png', (0, 0, 1639, 782)), ('construction_page_32', 'source_construction_page_32.png', (0, 0, 1639, 782)), ('construction_page_33', 'source_construction_page_33.png', (0, 0, 1639, 782)), ('construction_page_34', 'source_construction_page_34.png', (0, 0, 1639, 782)), ('construction_page_35', 'source_construction_page_35.png', (0, 0, 1639, 782)), ('construction_page_36', 'source_construction_page_36.png', (0, 0, 1639, 782)), ('construction_page_37', 'source_construction_page_37.png', (0, 0, 1639, 782)), ('construction_page_38', 'source_construction_page_38.png', (0, 0, 1639, 782)), ('construction_page_39', 'source_construction_page_39.png', (0, 0, 1639, 782)), ('construction_page_40', 'source_construction_page_40.png', (0, 0, 1639, 782)), ('construction_page_41', 'source_construction_page_41.png', (0, 0, 1639, 782))]
def categories(im):
 a=np.asarray(im.convert('RGB'),dtype=np.int32)
 r=a[:,:,0]>>3;r=(r<<3)|(r>>2)
 g=a[:,:,1]>>2;g=(g<<2)|(g>>4)
 b=a[:,:,2]>>3;b=(b<<3)|(b>>2)
 yellow=(5*b<=3*g)&(r>=32)&(g>=24)&(r>=b+16)&(g>=b+12)&(4*r>=3*g)
 dark=(r<96)&(g<96)&(b<96)
 return np.where(yellow,1,np.where(dark,2,0)).astype(np.uint8)
def sample(a):
 h,w=a.shape[:2];xs=((2*np.arange(16)+1)*w)//32;ys=((2*np.arange(16)+1)*h)//32
 center=a[np.ix_(ys,xs)];left=a[np.ix_(ys,np.maximum(0,xs-1))];right=a[np.ix_(ys,np.minimum(w-1,xs+1))]
 return np.where((center==left)|(center==right),center,np.where(left==right,left,center))
def cost(q,r,care):
 return int(2*np.count_nonzero((q==1)!=(r==1))+np.count_nonzero(((q==2)!=(r==2))&care))
def yellow_box(im):
 smooth=im.filter(ImageFilter.MedianFilter(5));mask=categories(smooth)==1
 ys=np.flatnonzero(mask.sum(axis=1)>=max(3,im.width*.025))
 xs=np.flatnonzero(mask.sum(axis=0)>=max(3,im.height*.025))
 if len(xs)==0 or len(ys)==0:raise ValueError('No usable yellow reference body')
 return int(xs[0]),int(ys[0]),int(xs[-1]+1),int(ys[-1]+1)
def main(source):
 refs=[];meta=[];sources=[]
 for name,file,coarse in SPECS:
  src=source/file;raw=src.read_bytes();full=Image.open(src).convert('RGB')
  roi=full.crop(coarse);local=yellow_box(roi)
  box=(coarse[0]+local[0],coarse[1]+local[1],coarse[0]+local[2],coarse[1]+local[3])
  crop=full.crop(box);buffer=io.BytesIO();crop.save(buffer,format='PNG');(ROOT/'reference'/(name+'.png')).write_bytes(buffer.getvalue())
  variants=[];cares=[]
  # Match the normalized body extent actually produced by tile segmentation.
  for width in [72]:
   r=sample(body_patch(crop,categories,width));variants.append(r)
   # Compare dark patterns only in the central body, not the photo background
   # near silhouette corners. Yellow shape still compares across all 256 cells.
   care=np.zeros((16,16),dtype=bool);care[3:14,1:15]=True;cares.append(care)
  scores=[]
  for brightness in [.8,1,1.2]:
   for width in [40,64,100]:
    for jitter in [-.025,0,.025]:
     dx=round(crop.width*jitter);dy=round(crop.height*jitter)
     c=full.crop((box[0]+dx,box[1]+dy,box[2]+dx,box[3]+dy))
     c=ImageEnhance.Brightness(c).enhance(brightness)
     c=c.resize((width,max(16,round(width*crop.height/crop.width))),Image.Resampling.BILINEAR)
     q=sample(categories(c));scores.append(min(cost(q,r,care) for r,care in zip(variants,cares)))
  solid_min=min(cost(np.ones((16,16),dtype=np.uint8),r,care) for r,care in zip(variants,cares))
  # Preserve V6 acceptance thresholds: fix sampling/noise rather than loosen.
  baseline=json.loads((ROOT/'reference/recognition_limits.json').read_text())
  limit=baseline[name]
  if solid_min-limit<24:raise ValueError('Reference loses solid-yellow rejection margin: '+name)
  aspect=100*crop.width/crop.height
  # Monitor photographs have unknown projective stretch. Broad, provisional
  # aspect limits are deliberate; they are not calibrated distance/pose coverage.
  amin=max(20,round(aspect*.5));amax=min(500,round(aspect*1.4))
  for variant,(r,care) in enumerate(zip(variants,cares)):
   for flip in [False]:
    rr=np.fliplr(r) if flip else r;cc=np.fliplr(care) if flip else care
    for rotation in range(4):
     refs.append((np.rot90(rr,-rotation),np.rot90(cc,-rotation)))
     lo,hi=(max(20,10000//amax),min(500,(10000+amin-1)//amin)) if rotation%2 else (amin,amax)
     meta.append((name,flip,limit,lo,hi,variant,rotation))
  sources.append({'label':name,'source':file,'sha256':hashlib.sha256(raw).hexdigest(),
    'coarse_roi':coarse,'yellow_body_crop_xyxy':box,'limit':limit,'solid_yellow_min_cost':solid_min,
    'same_photo_perturbation_costs':scores})
  (ROOT/'reference'/(name+'_categories.hex')).write_text(''.join(f'{int(v):x}\n' for v in variants[0].ravel()))
 (ROOT/'reference/all_care.hex').write_text(''.join(f'{int(v):x}\n' for _,care in refs for v in care.ravel()))
 (ROOT/'reference/all_templates.hex').write_text(''.join(f'{int(v):x}\n' for r,_ in refs for v in r.ravel()))
 lines=['`timescale 1ns/1ps','// V6 generated from monitor photographs; experimental positive-only calibration.',
 'module vehicle_template_rom(input [7:0] index,output reg [211:0] yellow,dark,dark_care);',
 'always @* begin','yellow=0;dark=0;dark_care=0;','case(index)']
 for i in range(256):
  vals=[sum(int((r.ravel()[i]==c) if c else care.ravel()[i])<<k for k,(r,care) in enumerate(refs)) for c in [1,2,0]]
  lines.append("8'd%d:begin yellow=212'h%053x;dark=212'h%053x;dark_care=212'h%053x;end"%(i,*vals))
 lines+=['default:begin yellow=0;dark=0;dark_care=0;end','endcase','end','endmodule']
 (ROOT/'rtl/vehicle_template_rom.v').write_text('\n'.join(lines)+'\n')
 lines=['`timescale 1ns/1ps','module vehicle_match_limits(input [7:0] index,output reg [9:0] max_cost,output reg [8:0] aspect_min,aspect_max);',
 'always @* begin','max_cost=0;aspect_min=0;aspect_max=0;','case(index)']
 for i,(_,_,limit,amin,amax,_,_) in enumerate(meta):
  lines.append("8'd%d:begin max_cost=10'd%d;aspect_min=9'd%d;aspect_max=9'd%d;end"%(i,limit,amin,amax))
 lines+=['default:begin max_cost=0;aspect_min=0;aspect_max=0;end','endcase','end','endmodule']
 (ROOT/'rtl/vehicle_match_limits.v').write_text('\n'.join(lines)+'\n')
 (ROOT/'reference/manifest.json').write_text(json.dumps({'method':'V6 tile-body-aligned positive-only camera-view matcher',
 'calibration_images':53,'held_out_images':0,'independent_negative_images':0,
 'sources':sources,'templates':meta,'helicopter_used':False},indent=2)+'\n')
 import shutil
 for i,alias in [(0,'dump_truck'),(14,'van'),(32,'construction_truck')]:
  for suffix in ['.png','_categories.hex']:
   shutil.copyfile(ROOT/'reference'/(sources[i]['label']+suffix),ROOT/'reference'/(alias+suffix))
 print(json.dumps(sources,indent=2))
if __name__=='__main__':
 raise SystemExit('For this release run rebuild_front_back.py. Legacy 53-image calibration is preserved in reference/v6_1_baseline.')
