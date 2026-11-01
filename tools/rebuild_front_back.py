from pathlib import Path
import sys,json,io,hashlib
import numpy as np
from PIL import Image
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'tools'))
from build_references import categories,sample,cost,yellow_box
from foreground_model import body_patch
m=json.loads((root/'reference/v6_1_baseline/manifest.json').read_text()); refs=np.loadtxt(root/'reference/v6_1_baseline/all_templates.hex',dtype=np.uint8).reshape(212,16,16);care=np.loadtxt(root/'reference/v6_1_baseline/all_care.hex',dtype=np.uint8).reshape(212,16,16).astype(bool)
refs=list(refs);care=list(care)
rois=[(.30,.27,.63,.57),(.30,.26,.62,.53),(.38,.20,.70,.59),(.43,.23,.74,.61),(.26,.19,.66,.60),(.36,.16,.85,.64)]
classes=[2,2,1,1,3,3]
for i,(roi,cls) in enumerate(zip(rois,classes)):
 name=f'front_back_{i+1}';src=root/'reference'/f'front_back_source_{i+1}.png';im=Image.open(src).convert('RGB');box=tuple(round(v*(im.width if j%2==0 else im.height)) for j,v in enumerate(roi));im=im.crop(box);bb=yellow_box(im);im=im.crop(bb)
 b=io.BytesIO();im.save(b,format='PNG');(root/'reference'/f'{name}.png').write_bytes(b.getvalue())
 r=sample(body_patch(im,categories,72));c=np.zeros((16,16),bool);c[3:14,1:15]=True
 solid=cost(np.ones((16,16),np.uint8),r,c);limit=max(0,min(100,solid-24));aspect=100*im.width/im.height;lo=max(20,round(aspect*.65));hi=min(500,round(aspect*1.4))
 for rot in range(4):
  refs.append(np.rot90(r,-rot));care.append(np.rot90(c,-rot));amin,amax=(max(20,10000//hi),min(500,(10000+lo-1)//lo)) if rot%2 else (lo,hi)
  m['templates'].append([name,False,limit,amin,amax,0,rot])
 m['sources'].append({'label':name,'source':src.name,'sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'class_id':cls,'limit':limit,'solid_yellow_min_cost':solid,'coarse_roi':box,'yellow_body_crop_xyxy':bb})
 (root/'reference'/f'{name}_categories.hex').write_text(''.join(f'{v:x}\n' for v in r.ravel()))
 print(name,im.size,'solid',solid,'limit',limit)
n=len(refs);m.update(calibration_images=59,method='V6.2 preserves all 212 V6.1 descriptors; adds six front/back photos with four rotations each',held_out_images=0)
(root/'reference/manifest.json').write_text(json.dumps(m,indent=2)+'\n')
for name,a in [('all_templates',refs),('all_care',care)]: (root/'reference'/f'{name}.hex').write_text(''.join(f'{int(v):x}\n' for r in a for v in r.ravel()))
lines=['`timescale 1ns/1ps',f'module vehicle_template_rom(input [7:0] index,output reg [{n-1}:0] yellow,dark,dark_care);','always @* begin yellow=0;dark=0;dark_care=0;case(index)']
for i in range(256):
 vals=[sum(int((r.ravel()[i]==c) if c else ca.ravel()[i])<<k for k,(r,ca) in enumerate(zip(refs,care))) for c in [1,2,0]]
 lines.append(f"8'd{i}:begin yellow={n}'h{vals[0]:059x};dark={n}'h{vals[1]:059x};dark_care={n}'h{vals[2]:059x};end")
lines+=['default:begin yellow=0;dark=0;dark_care=0;end','endcase end endmodule'];(root/'rtl/vehicle_template_rom.v').write_text('\n'.join(lines)+'\n')
p=root/'rtl/vehicle_match_limits.v';s=(root/'reference/v6_1_baseline/vehicle_match_limits.v').read_text();added='\n'.join(f"8'd{i}:begin max_cost=10'd{t[2]};aspect_min=9'd{t[3]};aspect_max=9'd{t[4]};end" for i,t in enumerate(m['templates']) if i>=212);p.write_text(s.replace('default:begin',added+'\ndefault:begin'))
