// Original GPIF regression fixture; run after create-bend-fixtures.py and npm run build.
import fs from 'node:fs';
import {fileURLToPath} from 'node:url';
import {importer, exporter, model, Settings} from './node_modules/.fretnote/alphaTab.core.mjs';
const root = fileURLToPath(new URL('../../Tests/FretNoteAppTests/Fixtures/', import.meta.url));
const finish=model.Note.prototype.finish, curves=new Map();
model.Note.prototype.finish=function(...args) {
    if(this.bendPoints?.length)curves.set(this,this.bendPoints.map(p=>new model.BendPoint(p.offset,p.value)));
    return finish.apply(this,args);
};
let score;
try{score=importer.ScoreLoader.loadScoreFromBytes(fs.readFileSync(root+'complex-bends.gp5'),new Settings());}
finally{model.Note.prototype.finish=finish;}
for(const [note,points] of curves) note.bendPoints=points;
// Native GP files can retain an unused middle-offset field after the destination.
// This ends at 51% of the beat; the 100% middle offset must not undo that bend.
const note=score.tracks[0].staves[0].bars[1].voices[0].beats[0].notes[0];
note.bendPoints=[[0,0],[30,2],[60,2],[30.6,4]].map(([x,y])=>new model.BendPoint(x,y));
fs.writeFileSync(root+'complex-bends.gp',new exporter.Gp7Exporter().export(score));
