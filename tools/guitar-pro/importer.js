// Offline parser bridge. alphaTab remains an unmodified MPL-2.0 dependency.
import { importer, midi, Settings } from './node_modules/@coderline/alphatab/dist/alphaTab.core.mjs';
export function parse(bytes) {
    const settings = new Settings();
    const score = importer.ScoreLoader.loadScoreFromBytes(new Uint8Array(bytes), settings);
    const midiFile = new midi.MidiFile();
    const generator = new midi.MidiFileGenerator(score, settings,
        new midi.AlphaSynthMidiFileHandler(midiFile));
    generator.generate();
    const bars = generator.tickLookup.masterBars;
    if (bars.length > 20000) throw new Error('Score is too large');
    const changes = bars.flatMap(b => b.tempoChanges).sort((a,b) => a.tick-b.tick);
    function seconds(tick) {
        let time=0, previous=0, tempo=score.tempo || 120;
        for (const change of changes) {
            if(change.tick > tick) break;
            time += (change.tick-previous)*60/(960*tempo);
            previous=change.tick; tempo=change.tempo;
        }
        return time+(tick-previous)*60/(960*tempo);
    }
    const tracks=[];
    for(const track of score.tracks) {
        const staff=track.staves[0];
        if(!staff || staff.isPercussion || staff.tuning.length!==6) continue;
        // This instrument currently models a standard-tuned, 21-fret guitar.
        const supported=staff.capo===0 && staff.tuning.every((v,i)=>v===[64,59,55,50,45,40][i]);
        const frames=[];
        let lastKey='';
        for(const bar of bars) {
            for(let slice=bar.firstBeat;slice;slice=slice.nextBeat) {
                const beats=slice.highlightedBeats.filter(x=>x.beat.voice.bar.staff===staff);
                const unique=new Map();
                for(const {beat} of beats) for(const n of beat.notes) {
                    if(n.string<1 || n.string>6 || n.fret<0) continue;
                    unique.set(n.id, {string:7-n.string, fret:n.fret,
                        bend:(n.bendPoints || []).map(p=>({offset:p.offset/60, semitones:p.value/2})),
                        tie:n.isTieDestination, slide:n.slideInType!==0 || n.slideOutType!==0,
                        legato:n.isHammerPullOrigin || n.isHammerPullDestination});
                }
                const notes=[...unique.values()];
                const key=bar.masterBar.index+':'+[...unique.keys()].join(',');
                const start=seconds(bar.start+slice.start), end=seconds(bar.start+slice.end);
                if(end<=start) continue;
                if(frames.length && key===lastKey) frames[frames.length-1].end=end;
                else frames.push({start,end,bar:bar.masterBar.index+1,notes});
                lastKey=key;
            }
        }
        const hasNotes=frames.some(f=>f.notes.length);
        const events = [];
        for (const event of midiFile.tracks[track.index]?.events ?? []) {
            let kind, key=0, value=0;
            if(event instanceof midi.NoteOnEvent) { kind=1; key=event.noteKey; value=event.noteVelocity; }
            else if(event instanceof midi.NoteOffEvent) { kind=2; key=event.noteKey; }
            else if(event instanceof midi.ControlChangeEvent) { kind=3; key=event.controller; value=event.value; }
            else if(event instanceof midi.ProgramChangeEvent) { kind=4; value=event.program; }
            else if(event instanceof midi.PitchBendEvent) { kind=5; value=event.value; }
            else if(event instanceof midi.NoteBendEvent) { kind=6; key=event.noteKey; value=Math.round(event.value / 262144); }
            else continue;
            events.push({time:seconds(event.tick - midiFile.tickShift),kind,channel:event.channel,key,value});
        }
        if(hasNotes) tracks.push({id:track.index,name:track.name,supported:supported && frames.every(f=>f.notes.every(n=>n.fret<=21)),frames,events});
    }
    return JSON.stringify({title:score.title || 'Guitar Pro',tempo:score.tempo,barCount:score.masterBars.length,tracks});
}
