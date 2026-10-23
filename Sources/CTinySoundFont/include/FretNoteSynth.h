#ifndef FRETNOTE_SYNTH_H
#define FRETNOTE_SYNTH_H
#include <stdint.h>
typedef struct FNSynth FNSynth;
FNSynth *fn_synth_create(const char *soundfont, int sample_rate);
void fn_synth_destroy(FNSynth *synth);
// kind: 0 reset, 1 note on, 2 note off, 3 controller, 4 program,
// 5 channel pitch wheel, 6 per-note pitch wheel (14-bit, center 8192).
void fn_synth_event(FNSynth *synth, int kind, int channel, int key, int value);
void fn_synth_render(FNSynth *synth, float *mono, int frames);
#endif
