"""Original non-musical regression score. Requires PyGuitarPro for regeneration only.
PyGuitarPro time positions are 0..12, mapped to GP binary positions 0..60.
"""
from pathlib import Path
import guitarpro as gp
from guitarpro import models as m

out = Path(__file__).resolve().parents[2] / 'Tests/FretNoteAppTests/Fixtures'
song = m.Song(title='Original complex bend fixture', tempo=120)
song.measureHeaders = []; song.tracks = []
track = m.Track(song, name='Clean guitar', fretCount=21)
track.channel.instrument = 27
track.measures = []; song.tracks.append(track)

def note(string, fret, points=None, tie=False, vibrato=False):
    return string, fret, points, tie, vibrato

bars = [
    [(2, [note(1,5,[(0,0),(9,0),(12,4)]), note(2,7,[(0,4),(6,4),(12,0)])]),
     (2, [note(1,5,[(0,4),(6,5),(12,1)],tie=True), note(2,7,[(0,0),(12,0)],tie=True)])],
    [(4, [note(1,5,[(0,5),(6,5),(12,2)])]),
     (4, [note(1,5)]),
     (4, [note(1,7,[(0,0),(6,0),(12,2)],vibrato=True)]),
     (4, [note(1,7,tie=True,vibrato=True)])],
    [(1, [note(1,7,[(0,2),(6,2),(12,0)],tie=True)])],
]
for i, beats in enumerate(bars):
    header=m.MeasureHeader(number=i+1,start=960+i*3840)
    song.measureHeaders.append(header)
    measure=m.Measure(track,header);track.measures.append(measure)
    voice=measure.voices[0];tick=header.start
    for dur, notes in beats:
        beat=m.Beat(voice,start=tick,status=m.BeatStatus.normal,duration=m.Duration(value=dur))
        voice.beats.append(beat);tick+=beat.duration.time
        for string,fret,points,tie,vibrato in notes:
            n=m.Note(beat,string=string,value=fret,type=m.NoteType.tie if tie else m.NoteType.normal,velocity=95)
            n.effect.vibrato=vibrato
            if points:
                n.effect.bend=m.BendEffect(type=m.BendType.bend,value=max(v for _,v in points)*25,
                    points=[m.BendPoint(position=p,value=v) for p,v in points])
            beat.notes.append(n)
    assert tick==header.start+3840

gp.write(song,str(out/'complex-bends.gp5'),version=(5,1,0))
# Deliberately malformed timing must be rejected rather than spill into later notes.
track.measures[0].voices[0].beats[0].notes[0].effect.bend.points[-1].position=60
gp.write(song,str(out/'invalid-bend-timing.gp5'),version=(5,1,0))
