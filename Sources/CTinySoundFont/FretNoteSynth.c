#include "FretNoteSynth.h"
#define TSF_IMPLEMENTATION
#include "tsf.h"

struct FNSynth {
    tsf *font;
    int wheel[16], noteWheel[16][128], range[16], cents[16], rpnMSB[16], rpnLSB[16];
};
static void reset(FNSynth *s) {
    tsf_reset(s->font);
    // Drain the library's short release ramps before a discontinuous bar cut.
    // These samples are discarded; they never lengthen the music timeline.
    float discarded[2048];
    tsf_render_float(s->font, discarded, 2048, 0);
    // Offline renderer: allocate virtual per-note channels up front. This
    // preserves independent bends when multiple notes share a MIDI channel.
    tsf_channel_set_presetnumber(s->font, 2047, 0, 0);
    for (int ch=0; ch<16; ++ch) {
        s->wheel[ch]=8192; s->range[ch]=2; s->cents[ch]=0;
        s->rpnMSB[ch]=s->rpnLSB[ch]=127;
        for (int key=0; key<128; ++key) s->noteWheel[ch][key]=8192;
    }
}
FNSynth *fn_synth_create(const char *path, int rate) {
    tsf *font=tsf_load_filename(path);
    if (!font) return NULL;
    FNSynth *s=calloc(1,sizeof(FNSynth));
    if (!s) { tsf_close(font); return NULL; }
    s->font=font;
    tsf_set_output(font,TSF_MONO,rate,-8.0f);
    if (!tsf_set_max_voices(font,256)) { fn_synth_destroy(s); return NULL; }
    reset(s); return s;
}
void fn_synth_destroy(FNSynth *s) { if(s) { tsf_close(s->font); free(s); } }
static void tune(FNSynth *s,int ch,int key) {
    float semitones=(s->wheel[ch]-8192+s->noteWheel[ch][key]-8192)/8192.0f*(s->range[ch]+s->cents[ch]/100.0f);
    tsf_channel_set_tuning(s->font,ch*128+key,semitones);
}
void fn_synth_event(FNSynth *s,int kind,int ch,int key,int value) {
    if (!s) return;
    if (kind==0) { reset(s); return; }
    if (ch<0 || ch>15 || key<0 || key>127) return;
    switch(kind) {
        case 1: tsf_channel_note_on(s->font,ch*128+key,key,value/127.0f); break;
        case 2: tsf_channel_note_off(s->font,ch*128+key,key); break;
        case 3:
            if(key==101) s->rpnMSB[ch]=value;
            if(key==100) s->rpnLSB[ch]=value;
            if(s->rpnMSB[ch]==0 && s->rpnLSB[ch]==0) {
                if(key==6) s->range[ch]=value;
                if(key==38) s->cents[ch]=value;
            }
            for(int k=0;k<128;++k) {
                tsf_channel_midi_control(s->font,ch*128+k,key,value);
                tune(s,ch,k);
            }
            break;
        case 4:
            for(int k=0;k<128;++k) tsf_channel_set_presetnumber(s->font,ch*128+k,value,ch==9);
            break;
        case 5:
            s->wheel[ch]=value;
            for(int k=0;k<128;++k) tune(s,ch,k);
            break;
        case 6: s->noteWheel[ch][key]=value; tune(s,ch,key); break;
    }
}
void fn_synth_render(FNSynth *s,float *mono,int frames) { tsf_render_float(s->font,mono,frames,0); }
