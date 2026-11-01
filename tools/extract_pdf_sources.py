#!/usr/bin/env python3
"""Optional: reconstruct lossless source ROIs from the supplied 53-page PDF.
Requires PyMuPDF and Pillow. Not needed to compile or program the FPGA.
"""
from pathlib import Path
import argparse,io,fitz
from PIL import Image
from build_references import SPECS,ROOT
p=argparse.ArgumentParser();p.add_argument('pdf',type=Path);a=p.parse_args()
d=fitz.open(a.pdf)
if len(d)!=53:raise ValueError('Expected the supplied 53-page fpga vehicles PDF')
for name,file,_ in SPECS:
 i=int(name.rsplit('_',1)[1])-1;page=d[i]
 if len(page.get_images())!=1:raise ValueError('Expected one embedded photo per page')
 part=d.extract_image(page.get_images()[0][0]);im=Image.open(io.BytesIO(part['image'])).convert('RGB');w,h=im.size
 roi=(int(w*.32),int(h*.36),int(w*.72),int(h*.78))
 if 1<=i<=8:roi=(int(w*.32),int(h*.42),int(w*.72),int(h*.82))
 im=im.crop(roi);buf=io.BytesIO();im.save(buf,format='PNG');(ROOT/'reference'/file).write_bytes(buf.getvalue())
print('Extracted 53 lossless source ROIs into reference/')
