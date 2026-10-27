import fs from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import {build} from 'esbuild';

process.chdir(fileURLToPath(new URL('.', import.meta.url)));
// Keep the pinned npm distribution intact. Generate an ignored, reproducible
// patched copy for the adapter; source changes are fully recorded here (MPL-2.0).
const source = await fs.readFile('node_modules/@coderline/alphatab/dist/alphaTab.core.mjs', 'utf8');
let patched = source;
for (const index of [1, 2]) {
    const before = `if (bendMiddleOffset${index} && bendMiddleValue) note.addBendPoint(new BendPoint(bendMiddleOffset${index}, bendMiddleValue));`;
    const after = `if (bendMiddleOffset${index} !== null && bendMiddleValue !== null && bendMiddleOffset${index} >= bendOrigin.offset && bendMiddleOffset${index} <= bendDestination.offset) note.addBendPoint(new BendPoint(bendMiddleOffset${index}, bendMiddleValue));`;
    if (patched.split(before).length !== 2) throw new Error('alphaTab GPIF parser changed; review bend patch before upgrading.');
    patched = patched.replace(before, after);
}
// Zero is a valid pitch/offset; absent fields are null. Do not synthesize a
// midpoint from an explicitly supplied zero-valued offset.
const before = 'if (!bendMiddleOffset1 && !bendMiddleOffset2 && bendMiddleValue) note.addBendPoint(new BendPoint(BendPoint.MaxPosition / 2 | 0, bendMiddleValue));';
const after = 'if (bendMiddleOffset1 === null && bendMiddleOffset2 === null && bendMiddleValue !== null) note.addBendPoint(new BendPoint((bendOrigin.offset + bendDestination.offset) / 2, bendMiddleValue));';
if (patched.split(before).length !== 2) throw new Error('alphaTab GPIF midpoint fallback changed; review bend patch.');
patched = patched.replace(before, after);
await fs.mkdir('node_modules/.fretnote', {recursive: true});
await fs.writeFile('node_modules/.fretnote/alphaTab.core.mjs', '// FretNote GPIF bend patch; see tools/guitar-pro/build.mjs. MPL-2.0.\n' + patched);
await build({entryPoints:['importer.js'],bundle:true,format:'iife',globalName:'FretNoteGP',minify:true,
    outfile:'../../Sources/FretNoteApp/Resources/GuitarProImporter.js',logLevel:'info'});
