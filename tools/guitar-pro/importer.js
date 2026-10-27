// Offline parser bridge. The reproducible MPL-2.0 GPIF patch is in build.mjs.
import { importer, midi, model, Settings } from './node_modules/.fretnote/alphaTab.core.mjs';
// alphaTab 1.8.4 chooses bend OR note vibrato. Compose them in the adapter,
// keeping the library's bend timing and vibrato settings; never affect other notes.
class ExpressiveMidiGenerator extends midi.MidiFileGenerator {
    _generateBend(note, start, duration, key, channel, tempo) {
        if (!note.vibrato) return super._generateBend(note, start, duration, key, channel, tempo);
        const handler = this._handler, points = [];
        this._handler = new Proxy(handler, {get(target, property) {
            if (property === 'addNoteBend') return (track, tick, channel, key, value) => points.push({track,tick,channel,key,value});
            const value = target[property];
            return typeof value === 'function' ? value.bind(target) : value;
        }});
        try { super._generateBend(note, start, duration, key, channel, tempo); }
        finally { this._handler = handler; }
        if (!points.length) return;
        points.sort((a,b)=>a.tick-b.tick);
        const settings = this._settings.player.vibrato;
        const length = note.vibrato === 2 ? settings.noteWideLength : settings.noteSlightLength;
        const amplitude = note.vibrato === 2 ? settings.noteWideAmplitude : settings.noteSlightAmplitude;
        const begin = points[0].tick, end = Math.max(points.at(-1).tick, start + duration.noteOnly);
        const ticks = new Set(points.map(p=>p.tick));
        for(let tick=begin;tick<end;tick+=this.vibratoResolution) ticks.add(tick);
        ticks.add(end);
        let index=0;
        for(const tick of [...ticks].sort((a,b)=>a-b)) {
            while(index+1<points.length && points[index+1].tick<=tick) index++;
            const a=points[index], b=points[index+1];
            const base=b && b.tick>a.tick ? a.value+(b.value-a.value)*(tick-a.tick)/(b.tick-a.tick) : a.value;
            const wave=tick===end ? 0 : amplitude*Math.sin((tick-begin)*Math.PI*2/length);
            const value=Math.max(0,Math.min(16383,Math.round(base+midi.MidiFileGenerator.getPitchWheel(wave)-8192)));
            handler.addNoteBend(a.track,tick,a.channel,a.key,value);
        }
    }
}
// alphaTab 1.8.4 Note.finish classifies bends for engraving and removes
// intermediate points from three/four-point curves, losing their hold timing.
// Snapshot before finishing, then restore after the entire score is linked.
// Parsing is synchronous in a private JS VM; always restore the scoped hook.
function loadWithBendTiming(bytes, settings) {
    const finish = model.Note.prototype.finish;
    const curves = new Map();
    model.Note.prototype.finish = function (...args) {
        if (this.bendPoints?.length && !curves.has(this)) {
            curves.set(this, this.bendPoints.map(p => new model.BendPoint(p.offset, p.value)));
        }
        return finish.apply(this, args);
    };
    let score;
    try { score = importer.ScoreLoader.loadScoreFromBytes(new Uint8Array(bytes), settings); }
    finally { model.Note.prototype.finish = finish; }
    for (const track of score.tracks) for (const staff of track.staves)
        for (const bar of staff.bars) for (const voice of bar.voices)
            for (const beat of voice.beats) for (const note of beat.notes) {
                const points = curves.get(note) ?? note.bendPoints;
                if (!points?.length) continue;
                if (points.some((p, i) => !Number.isFinite(p.offset) || !Number.isFinite(p.value)
                    || p.offset < 0 || p.offset > model.BendPoint.MaxPosition
                    || (i > 0 && p.offset < points[i - 1].offset))) {
                    throw new Error(`Invalid bend timing in bar ${bar.index + 1}. Re-export the source score.`);
                }
                note.bendPoints = points;
            }
    return score;
}

export function parse(bytes) {
    const settings = new Settings();
    const score = loadWithBendTiming(bytes, settings);
    const midiFile = new midi.MidiFile();
    const generator = new ExpressiveMidiGenerator(score, settings,
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
    const beats=[];
    for (const bar of bars) {
        const unit=3840/bar.masterBar.timeSignatureDenominator;
        for(let tick=bar.start, index=0;tick<bar.end;tick+=unit,index++) {
            beats.push({time:seconds(tick), accent:index===0});
        }
    }
    // alphaTab defaults to format 0: every source track shares one MIDI container.
    // Route by each event's original score track, never by container index.
    const eventsByTrack=new Map();
    for(const container of midiFile.tracks) for(const event of container.events) {
        if(!eventsByTrack.has(event.track)) eventsByTrack.set(event.track,[]);
        eventsByTrack.get(event.track).push(event);
    }
    const tracks=[];
    for(const track of score.tracks) {
        const staff=track.staves[0];
        if(!staff) continue;
        // This instrument currently models a standard-tuned, 21-fret guitar.
        const supported=!staff.isPercussion && staff.tuning.length===6 && staff.capo===0 && staff.tuning.every((v,i)=>v===[64,59,55,50,45,40][i]);
        const frames=[];
        const barActivity=new Set();
        let lastKey='';
        for(const bar of bars) {
            for(let slice=bar.firstBeat;slice;slice=slice.nextBeat) {
                const beats=slice.highlightedBeats.filter(x=>x.beat.voice.bar.staff===staff);
                if(beats.some(x=>x.beat.notes.length)) barActivity.add(bar.masterBar.index+1);
                const unique=new Map();
                for(const {beat} of beats) for(const n of beat.notes) {
                    if(n.string<1 || n.string>6 || n.fret<0) continue;
                    unique.set(n.id, {string:7-n.string, fret:n.fret,
                        bend:(n.bendPoints || []).map(p=>({offset:p.offset/60, semitones:p.value/2})),
                        vibrato:Math.max(n.vibrato || 0, beat.vibrato || 0, n.isTieDestination ? (n.tieOrigin?.vibrato || 0) : 0),
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
        const events = [];
        const sourceEvents=eventsByTrack.get(track.index) ?? [];
        // alphaTab's GP playback channels may exceed the MIDI 0...15 range.
        // Each track is synthesized independently, so compact its virtual channels
        // while preserving the percussion channel and independent bend channels.
        const channels=[...new Set(sourceEvents.map(e=>e.channel).filter(c=>c!==undefined))];
        const melodicChannels=Array.from({length:16},(_,i)=>i).filter(i=>i!==9);
        const channelMap=new Map();
        for(const channel of channels) {
            const mapped=channel===9 ? 9 : melodicChannels.shift();
            if(mapped===undefined) throw new Error('Too many MIDI channels in one track');
            channelMap.set(channel,mapped);
        }
        for (const event of sourceEvents) {
            let kind, key=0, value=0;
            if(event instanceof midi.NoteOnEvent) { kind=1; key=event.noteKey; value=event.noteVelocity; }
            else if(event instanceof midi.NoteOffEvent) { kind=2; key=event.noteKey; }
            else if(event instanceof midi.ControlChangeEvent) { kind=3; key=event.controller; value=event.value; }
            else if(event instanceof midi.ProgramChangeEvent) { kind=4; value=event.program; }
            else if(event instanceof midi.PitchBendEvent) { kind=5; value=event.value; }
            else if(event instanceof midi.NoteBendEvent) { kind=6; key=event.noteKey; value=Math.round(event.value / 262144); }
            else continue;
            events.push({time:seconds(event.tick - midiFile.tickShift),kind,channel:channelMap.get(event.channel),key,value});
        }
        tracks.push({id:track.index,name:track.name,supported:supported && frames.every(f=>f.notes.every(n=>n.fret<=21)),frames,events,barActivity:[...barActivity]});
    }
    return JSON.stringify({importVersion:5,title:score.title || 'Guitar Pro',tempo:score.tempo,barCount:score.masterBars.length,tracks,beats});
}
