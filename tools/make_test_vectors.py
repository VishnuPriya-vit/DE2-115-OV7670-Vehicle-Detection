from pathlib import Path
import random,json
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'sim/vectors';OUT.mkdir(exist_ok=True)
rng=random.Random(73017)
def packed(b):
 x0,x1,y0,y1=b;return (1<<34)|(x0<<25)|(x1<<16)|(y0<<8)|y1
def golden(tiles,minhits=4,minpixels=48,minwidth=12,minheight=10):
 seen=set();comps=[]
 for i in range(1200):
  if i in seen or tiles[i]>>12<minhits:continue
  todo=[i];seen.add(i);area=0;xs=[];ys=[]
  while todo:
   j=todo.pop();d=tiles[j];x=j%40;y=j//40;area+=d>>12
   xs.extend([x*8+(d&7),x*8+((d>>3)&7)]);ys.extend([y*8+((d>>6)&7),y*8+((d>>9)&7)])
   for nx,ny in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
    k=ny*40+nx
    if 0<=nx<40 and 0<=ny<30 and k not in seen and tiles[k]>>12>=minhits:seen.add(k);todo.append(k)
  if area>=minpixels and max(xs)-min(xs)+1>=minwidth and max(ys)-min(ys)+1>=minheight:comps.append((area,(min(xs),max(xs),min(ys),max(ys))))
 comps.sort(key=lambda p:-p[0]);return sum(packed(b)<<(35*i) for i,(_,b) in enumerate(comps[:3]))
def main():
 cases=[]
 cases.append([0]*1200)
 cases.append([(64<<12)|(7<<9)|(7<<3)]*1200)
 a=[0]*1200
 for x0,y0,w,h in [(0,0,2,2),(5,5,4,3),(5,15,5,4),(36,27,4,3)]:
  for y in range(y0,y0+h):
   for x in range(x0,x0+w):a[y*40+x]=(64<<12)|(7<<9)|(7<<3)
 cases.append(a)
 for test in range(5):
  a=[0]*1200
  for j in range(1200):
   if rng.random()<.18:a[j]=(rng.randrange(4,65)<<12)|(rng.randrange(4,8)<<9)|(rng.randrange(0,3)<<6)|(rng.randrange(4,8)<<3)|rng.randrange(0,3)
  cases.append(a)
 (OUT/'tiles.hex').write_text(''.join(f'{v:05x}\n' for a in cases for v in a))
 (OUT/'tile_expected.hex').write_text(''.join(f'{golden(a):027x}\n' for a in cases))
 print('Generated',len(cases),'independent flood-fill test cases')

if __name__=="__main__":main()
