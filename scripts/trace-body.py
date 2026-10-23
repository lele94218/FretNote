#!/usr/bin/env python3
"""Trace the real upper body, aligned to the existing neck; requires trace-neck deps."""
import json, re, sys, tempfile
from pathlib import Path
from xml.etree import ElementTree as ET
from PIL import Image
import vtracer
from svgpathtools import parse_path, CubicBezier, QuadraticBezier, Line

root = Path(__file__).resolve().parents[1]
original = Image.open(sys.argv[1]).convert('RGBA')
source = original.convert('RGB')
assert source.size == (1000, 1000)
image = source.convert('RGBA')
neck_outline = json.loads((root / 'Sources/FretNoteApp/Resources/NeckArtwork.json').read_text())['outline']
neck_edges = list(zip(neck_outline, neck_outline[1:] + neck_outline[:1]))
# Neutral body finish; retain the photographic contours, pickguard and hardware.
# Remove only the backdrop and the old neck, which is replaced by our 21-fret neck.
for y in range(1000):
    world_x = 865 + y - 345
    crossings = []
    for a, b in neck_edges:
        if min(a[0], b[0]) <= world_x < max(a[0], b[0]):
            t = (world_x - a[0]) / (b[0] - a[0])
            crossings.append(a[1] + t * (b[1] - a[1]))
    for x in range(1000):
        rgb = source.getpixel((x, y))
        gray = round(sum(rgb) / 3)
        covered_by_neck = bool(crossings) and min(crossings) + 1 < 498 - x < max(crossings) - 1
        old_neck_only = world_x < 790 and 452 - y * 0.022 <= x <= 545 + y * 0.014
        alpha = 0 if covered_by_neck or old_neck_only else original.getpixel((x, y))[3]
        image.putpixel((x, y), (gray, gray, gray, alpha))
with tempfile.TemporaryDirectory() as tmp:
    png, svg = Path(tmp) / 'body.png', Path(tmp) / 'body.svg'
    image.save(png)
    vtracer.convert_image_to_svg_py(str(png), str(svg), colormode='color',
        hierarchical='stacked', mode='spline', filter_speckle=10,
        color_precision=5, layer_difference=16, corner_threshold=60,
        length_threshold=2.0, splice_threshold=45, path_precision=2)
    layers = []
    def point(z, dx, dy):
        return [round(865 + (z.imag + dy - 345), 3), round(498 - z.real - dx, 3)]
    for element in ET.parse(svg).getroot():
        if not element.tag.endswith('path'): continue
        color = element.attrib['fill']
        rgb = [int(color[i:i+2], 16) for i in (1, 3, 5)]
        translate = re.search(r'translate\(([-\d.]+)[ ,]+([-\d.]+)\)', element.attrib.get('transform', ''))
        dx, dy = map(float, translate.groups()) if translate else (0, 0)
        contours = []
        for sub in parse_path(element.attrib['d']).continuous_subpaths():
            if not sub: continue
            points = point(sub[0].start, dx, dy)
            for seg in sub:
                if isinstance(seg, CubicBezier): controls = [seg.control1, seg.control2, seg.end]
                elif isinstance(seg, QuadraticBezier): controls = [seg.start + (seg.control-seg.start)*2/3, seg.end + (seg.control-seg.end)*2/3, seg.end]
                elif isinstance(seg, Line): controls = [seg.start, seg.end, seg.end]
                else: raise ValueError(type(seg))
                for z in controls: points.extend(point(z, dx, dy))
            contours.append(points)
        layers.append({'color': rgb, 'contours': contours})
    target = root / 'Sources/FretNoteApp/Resources/BodyArtwork.json'
    target.write_text(json.dumps({'outline': [], 'layers': layers}, separators=(',', ':')) + '\n')
    print(f'{len(layers)} body paths, {target.stat().st_size:,} bytes')
