#!/usr/bin/env python3
"""Convert a front-facing 21-fret neck photograph into native vector paths.

Usage: .build/neck-trace-py311/bin/python scripts/trace-neck.py /tmp/neck-source.jpg
Requires Pillow, vtracer, svgpathtools. Source/photo calibration is documented in
Sources/FretNoteApp/Resources/NeckArtwork-SOURCE.md. No photograph is bundled.
"""
import bisect, json, math, re, sys, tempfile
from statistics import median
from pathlib import Path
from xml.etree import ElementTree as ET
from PIL import Image
import vtracer
from svgpathtools import parse_path, CubicBezier, QuadraticBezier, Line

root = Path(__file__).resolve().parents[1]
image = Image.open(sys.argv[1]).convert('RGB')
assert image.size == (2000, 2000), 'Calibration expects the 2000 × 2000 source'
# Omit printed branding, preserving the actual headstock outline and wood grain.
# Dark ink in this measured interior region is replaced with nearby wood tones.
source = image.copy()
for y in range(42, 414):
    samples = [source.getpixel((x, y)) for x in range(1016, 1110)]
    wood = [rgb for rgb in samples if rgb[0] > 230 and rgb[2] < 200]
    tone = tuple(round(median(c[i] for c in wood)) for i in range(3)) if wood else (244, 193, 126)
    for x in range(1016, 1110):
        if min(source.getpixel((x, y))) < 225:
            image.putpixel((x, y), tone)
# A limited palette makes paths compact while retaining real fingerboard grain.
image = image.crop((850, 0, 1150, 2000))
with tempfile.TemporaryDirectory() as tmp:
    png, svg = Path(tmp) / 'neck.png', Path(tmp) / 'neck.svg'
    image.save(png)
    vtracer.convert_image_to_svg_py(str(png), str(svg), colormode='color',
        hierarchical='stacked', mode='spline', filter_speckle=6,
        color_precision=6, layer_difference=8, corner_threshold=60,
        length_threshold=2.0, splice_threshold=45, path_precision=2)
    paths = []
    # Measured fret centers rectify the small photographic perspective error.
    rows = [559, 670, 775, 875, 969, 1058, 1142, 1221, 1296, 1366,
            1433, 1496, 1555, 1612, 1665, 1714, 1762, 1807, 1849, 1889, 1926, 1962]
    frets = [1200 * (1 - 2 ** (-f / 12)) for f in range(22)]
    factor = 600 / (1555 - 559)
    def world_x(y):
        if y < rows[0]: return (y - rows[0]) * factor
        if y >= rows[-1]: return frets[-1] + (y - rows[-1]) * factor
        i = bisect.bisect_right(rows, y) - 1
        t = (y - rows[i]) / (rows[i + 1] - rows[i])
        return frets[i] + t * (frets[i + 1] - frets[i])
    def point(z, dx, dy):
        return [round(world_x(z.imag + dy), 3),
                round((970 - (z.real + dx + 850)) * factor, 3)]
    for element in ET.parse(svg).getroot():
        if not element.tag.endswith('path'): continue
        color = element.attrib['fill']
        rgb = [int(color[i:i+2], 16) for i in (1, 3, 5)]
        bounds = parse_path(element.attrib['d']).bbox()
        if min(rgb) > 225 and bounds[1] - bounds[0] > 290 and bounds[3] - bounds[2] > 1900:
            continue  # Only the white backdrop; retain metallic fret highlights.
        translate = re.search(r'translate\(([-\d.]+)[ ,]+([-\d.]+)\)', element.attrib.get('transform', ''))
        dx, dy = map(float, translate.groups()) if translate else (0, 0)
        contours = []
        for sub in parse_path(element.attrib['d']).continuous_subpaths():
            points = point(sub[0].start, dx, dy)
            for seg in sub:
                if isinstance(seg, CubicBezier): controls = [seg.control1, seg.control2, seg.end]
                elif isinstance(seg, QuadraticBezier): controls = [seg.start + (seg.control-seg.start)*2/3, seg.end + (seg.control-seg.end)*2/3, seg.end]
                elif isinstance(seg, Line): controls = [seg.start, seg.end, seg.end]
                else: raise ValueError(type(seg))
                for z in controls: points.extend(point(z, dx, dy))
            contours.append(points)
        paths.append({'color': rgb, 'contours': contours})
    # Trace the photograph's outer silhouette separately. This clips away any
    # white backdrop islands while preserving white fret highlights inside it.
    edges = {}
    for y in range(2000):
        xs = [x for x in range(850, 1150)
              if min(source.getpixel((x, y))) < 190]
        if xs: edges[y] = (min(xs), max(xs))
    left, right = [], []
    for y in range(min(edges), max(edges) + 1, 3):
        near = [edges[k] for k in range(max(0, y - 5), min(2000, y + 6)) if k in edges]
        if not near: continue
        lo = median(e[0] for e in near)
        hi = median(e[1] for e in near)
        left.append(point(complex(lo - 850, y), 0, 0))
        right.append(point(complex(hi - 850, y), 0, 0))
    outline = left + list(reversed(right))
    target = root / 'Sources/FretNoteApp/Resources/NeckArtwork.json'
    target.write_text(json.dumps({'outline': outline, 'layers': paths}, separators=(',', ':')) + '\n')
    print(f'{len(paths)} vector paths, {target.stat().st_size:,} bytes')
