# Neck geometry source

NeckArtwork.json contains native vector curves traced from the front elevation of a
21-fret Fender Made in Japan Traditional II ’60s replacement neck:

- Reference page: https://www.musicarts.com/fender-made-in-japan-traditional-ii-60s-stratocaster-replacement-neck-main0531272
- Reference image: https://media.musicarts.com/is/image/MMGS7/M08265000001000-00-2000x2000.jpg
- Retrieved: 2026-10-23. Original product photography belongs to its respective owner.

The photograph is not bundled. Printed branding is omitted. The headstock outline,
neck taper, frets, inlays and rosewood grain are converted to Bézier paths with
`scripts/trace-neck.py`. Hardware and live note markers are separate native layers.

Calibration in the original 2000 × 2000 photo: nut at y=559, twelfth fret at y=1555;
600 world units between them. The neck center is x=970. Rotation maps the headstock
to the left, with the first string at the top. Each measured fret center is rectified to equal-temperament geometry;
intermediate photo coordinates are interpolated between adjacent frets. The photo is a geometric/artwork
reference, not an endorsement or affiliation with Fender or Music & Arts.

Reproducible conversion uses Python 3.11 with Pillow 13.0.0, vtracer 0.6.15 and
svgpathtools 1.8.0. Install these in a local environment under `.build/`, then run
`python scripts/trace-neck.py /path/to/2000x2000-source.jpg`. The generated resource
contains a separately traced outer clipping contour and color Bézier layers;
no image processing or network access happens at app runtime.
