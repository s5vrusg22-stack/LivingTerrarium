"""Regenerate 512px approximate PBR normal/roughness maps from albedo PNGs.
Requires numpy and Pillow: python tools/generate_pbr_maps.py
"""
from pathlib import Path
import numpy as np
from PIL import Image
root = Path(__file__).resolve().parents[1] / 'assets' / 'textures'
for name, strength, base in [('mantis_cuticle',2.4,.47),('mantis_eye',1.2,.24),('bark',4.5,.86),('substrate',3.5,.93),('stone',2.,.78)]:
    rgb = np.asarray(Image.open(root / f'{name}_albedo.png').convert('RGB'), dtype=np.float32) / 255
    gray = rgb[:,:,0]*.2126 + rgb[:,:,1]*.7152 + rgb[:,:,2]*.0722
    gy, gx = np.gradient(gray)
    normals = np.stack([-gx*strength,-gy*strength,np.ones_like(gray)],axis=-1)
    normals /= np.maximum(np.linalg.norm(normals,axis=2,keepdims=True),1e-5)
    Image.fromarray(np.uint8(np.clip(normals*.5+.5,0,1)*255),'RGB').save(root / f'{name}_normal.png')
    rough = np.clip(base+(gray-gray.mean())*.30,.08,.98)
    Image.fromarray(np.uint8(rough*255),'L').save(root / f'{name}_roughness.png')
