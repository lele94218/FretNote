#!/usr/bin/env python3
"""Smooth traced vector contours in world units, without rasterizing the artwork.
Run after trace-neck.py / trace-body.py using the same Python environment.
"""
import json, math
from pathlib import Path
import numpy as np
from scipy.ndimage import gaussian_filter1d

root = Path(__file__).resolve().parents[1] / 'Sources/FretNoteApp/Resources'

def smooth(points, spacing=1.2, radius=0.85):
    points = np.asarray(points, dtype=float)
    closed = np.vstack([points, points[0]])
    lengths = np.linalg.norm(np.diff(closed, axis=0), axis=1)
    distance = np.r_[0, np.cumsum(lengths)]
    if distance[-1] < 10: return points
    count = max(8, math.ceil(distance[-1] / spacing))
    samples = np.linspace(0, distance[-1], count, endpoint=False)
    uniform = np.column_stack([np.interp(samples, distance, closed[:, i]) for i in range(2)])
    filtered = gaussian_filter1d(uniform, radius / (distance[-1] / count), axis=0, mode='wrap')
    return filtered[::2] if len(filtered) > 16 else filtered

def contour(values):
    start = np.array(values[:2])
    samples = []
    for offset in range(2, len(values), 6):
        c1, c2, end = np.array(values[offset:offset+6]).reshape(3, 2)
        length = sum(np.linalg.norm(b-a) for a,b in [(start,c1),(c1,c2),(c2,end)])
        for t in np.linspace(0, 1, max(2, math.ceil(length / 1.2)), endpoint=False):
            samples.append((1-t)**3*start + 3*(1-t)**2*t*c1 + 3*(1-t)*t*t*c2 + t**3*end)
        start = end
    if len(samples) < 4: return values
    nodes = smooth(samples)
    result = list(nodes[0])
    for i, a in enumerate(nodes):
        b = nodes[(i+1) % len(nodes)]
        c1 = a + (b-nodes[i-1])/6
        c2 = b - (nodes[(i+2) % len(nodes)]-a)/6
        result.extend([*c1, *c2, *b])
    return [round(float(v), 3) for v in result]

for name in ['NeckArtwork', 'BodyArtwork']:
    target = root / (name + '.json')
    data = json.loads(target.read_text())
    for layer in data['layers']:
        layer['contours'] = [contour(c) for c in layer['contours'] if len(c) >= 8]
    if data['outline']:
        data['outline'] = np.round(smooth(data['outline']), 3).tolist()
    target.write_text(json.dumps(data, separators=(',', ':')) + '\n')
    print(name, target.stat().st_size)
