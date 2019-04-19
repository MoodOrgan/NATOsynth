////////////////////////////////// NATOsynth
//// by Timm Mason (timm.mason@gmail.com)
//// last update 20181130

// TODO:
//   - add pitchbend
//   - debug randomization
//   - add loudness curve?
//   - automatic gain compensation?
//   - mod matrix
//   - add Scala support
//   - record / playback performances

/////////////////////
// STEP 1 - initialize system with correct interface
// init
( // use iMic
s.options.sampleRate = 48000;
s.options.device="iMic USB audio system";
s.reboot;

MIDIClient.init;
MIDIIn.connectAll;
)

( // use speakers
s.options.sampleRate = 44100;
s.options.outDevice="Built-in Output";
s.reboot;

MIDIClient.init;
MIDIIn.connectAll;
)

/////////////////////
// STEP 2 - set vars
(
~natosynth_waves = [["~"], ["^"], ["/"], ["□"]];
~natosynth_lfo_waves = [["~"], ["^"], ["/"], ["\\"], ["□"], ["R"], ["He"], ["Le"], ["Ae"]];
~natomodulator1_waves = [["~"], ["^"], ["/"], ["\\"], ["□"], ["2"], ["R"]];
~natomodulator2_waves = [["~"], ["^"], ["/"], ["\\"], ["□"], ["1"], ["R"]];
//~current_tuning = Tuning.just;
~current_tuning = Tuning.et;
~current_scale  = Scale.chromatic(~current_tuning);
~pitchbend_range = 12.0;
)

/////////////////////
// STEP 3 - evaluate BOTH synthdefs (\natoSynth & \natoModulator)
(
SynthDef(\natoSynth, { |out = 0, gate = 1, note_num = 48.0, freq = 220, prev_freq = 220,
	osc1_freq = 1, osc2_freq = 1, osc2_detune = 0, vib_freq = 2.5, vib_depth = 0, vib_delay = 0.2,
	portamento = 0, veloc = 120, pitchbend = 0.0,
	osc1_wave1 = 3, osc1_wave2 = 2, osc2_wave1 = 2, osc2_wave2 = 3,
	osc1_wavemix = -1, osc2_wavemix = -1,
	pwm_wave = 1, pwm_freq = 0.5, pwm_delay = 0, pwm_depth = 0, pwm_offset = 0.5,
	trem_freq = 3, trem_depth = 0,
	pan_freq = 0.333, pan_depth = 0, pan_delay = 0, pan_deviance = 0,
	epsilon = 0.1313, amp = 0.3,
	osc1_amp = 0.666, osc2_amp = 0.333,
	mod1_inlet, mod2_inlet,
	mod1_deviance = 0, mod2_deviance = 0,
	mod1_send_hpf = 0, mod1_send_lpf = 0, mod1_send_dca = 0,
	mod2_send_hpf = 0, mod2_send_lpf = 0, mod2_send_dca = 0,
	hpf_cutoff = 33, hpf_q = 0.2,
	lpf_cutoff = 330, lpf_q = 0.2,
	hpf_env_a = 0.01, hpf_env_d = 0.3, hpf_env_s = 0.6, hpf_env_r = 3, hpf_env_depth = 0,
	lpf_env_a = 0.01, lpf_env_d = 0.3, lpf_env_s = 0.6, lpf_env_r = 3, lpf_env_depth = 1,
	dca_env_a = 0.01, dca_env_d = 0.3, dca_env_s = 0.6, dca_env_r = 3|

	var osc1, osc2a, osc2b;

	var hpf_env = EnvGen.kr(Env.adsr(hpf_env_a, hpf_env_d, hpf_env_s, hpf_env_r), gate);
	var lpf_env = EnvGen.kr(Env.adsr(lpf_env_a, lpf_env_d, lpf_env_s, lpf_env_r), gate);
	var dca_env = EnvGen.kr(Env.adsr(dca_env_a, dca_env_d, dca_env_s, dca_env_r), gate,
		doneAction: Done.freeSelf);

	var mod1 = LFNoise2.kr(Rand(0.05, 0.1), mod1_deviance, In.kr(mod1_inlet));
	var mod2 = LFNoise2.kr(Rand(0.05, 0.1), mod2_deviance, In.kr(mod2_inlet));
	var trem = LFTri.kr(LFNoise2.kr(Rand(0.05, 0.1), epsilon, trem_freq), 0, trem_depth*dca_env);
//	var vib  = LFTri.kr(LFNoise2.kr(Rand(0.05, 0.1), epsilon, vib_freq),  0, vib_depth*dca_env);
	var vib  = LFTri.kr(LFNoise2.kr(Rand(0.05, 0.1), epsilon, vib_freq),  0, EnvGen.kr(Env.dadsr(vib_delay, dca_env_a, 0, 1, dca_env_r), gate, vib_depth));
	var pan = LFTri.kr(LFNoise2.kr(Rand(0.05, 0.1), epsilon+pan_deviance, pan_freq),  0, EnvGen.kr(Env.dadsr(pan_delay, dca_env_a, 0, 1, dca_env_r), gate, pan_depth));

	var pwm_env = EnvGen.kr(Env.dadsr(pwm_delay, 2*pwm_delay, 0, 1, dca_env_r), gate ,pwm_depth);
	var pwm  = Array.with(
		SinOsc.kr(pwm_freq, 0, pwm_env),
		LFTri.kr(pwm_freq, 0, pwm_env),
		LFSaw.kr(pwm_freq, 0, pwm_env),
		1-LFSaw.kr(pwm_freq, 0, pwm_env),
		Pulse.kr(pwm_freq, 0.5, pwm_env),
		LFNoise2.kr(pwm_freq, pwm_env),
		hpf_env*pwm_env,
		lpf_env*pwm_env,
		dca_env*pwm_env);
	var pwm_lfo = Select.kr(pwm_wave, pwm).clip2(1);

	osc1 = Array.with(
		SinOsc.ar(LFNoise2.kr(Rand(0.05, 0.1), epsilon,
			XLine.ar(prev_freq, freq, portamento)*(osc1_freq+vib)),
			LFNoise2.kr(Rand(0.05, 0.1), 2*pi*epsilon), osc1_amp),
		LFTri.ar(LFNoise2.kr(Rand(0.05, 0.1), epsilon,
			XLine.ar(prev_freq, freq, portamento)*(osc1_freq+vib)),
			LFNoise2.kr(Rand(0.05, 0.1), 2*pi*epsilon), osc1_amp),
		Saw.ar(LFNoise2.kr(Rand(0.05, 0.1), epsilon,
			XLine.ar(prev_freq, freq, portamento)*(osc1_freq+vib)), osc1_amp),
		Pulse.ar(LFNoise2.kr(Rand(0.05, 0.1), epsilon,
			XLine.ar(prev_freq, freq, portamento)*(osc1_freq+vib)),
			LFNoise2.kr(Rand(0.05, 0.1), epsilon, pwm_lfo + pwm_offset), osc1_amp)
	);

	osc2a = Array.with(
		SinOsc.ar(LFNoise2.kr(Rand(0.05, 0.1), epsilon,
			XLine.ar(prev_freq, freq, portamento)*(osc2_freq+vib)*(1+osc2_detune)),
			LFNoise2.kr(Rand(0.05, 0.1), 2*pi*epsilon), osc2_amp),
		LFTri.ar(LFNoise2.kr(Rand(0.05, 0.1), epsilon,
			XLine.ar(prev_freq, freq, portamento)*(osc2_freq+vib)*(1+osc2_detune)),
			LFNoise2.kr(Rand(0.05, 0.1), 2*pi*epsilon), osc2_amp),
		Saw.ar(LFNoise2.kr(Rand(0.05, 0.1), epsilon,
			XLine.ar(prev_freq, freq, portamento)*(osc2_freq+vib)*(1+osc2_detune)), osc2_amp),
		Pulse.ar(LFNoise2.kr(Rand(0.05, 0.1), epsilon,
			XLine.ar(prev_freq, freq, portamento)*(osc2_freq+vib)*(1+osc2_detune)),
			LFNoise2.kr(Rand(0.05, 0.1), epsilon, pwm_lfo + pwm_offset), osc2_amp));

	osc2b = Array.with(
		SinOsc.ar(LFNoise2.kr(Rand(0.05, 0.1), epsilon,
			XLine.ar(prev_freq, freq, portamento)*(osc2_freq+vib)*(1-osc2_detune)),
			LFNoise2.kr(Rand(0.05, 0.1), 2*pi*epsilon), osc2_amp),
		LFTri.ar(LFNoise2.kr(Rand(0.05, 0.1), epsilon,
			XLine.ar(prev_freq, freq, portamento)*(osc2_freq+vib)*(1-osc2_detune)),
			LFNoise2.kr(Rand(0.05, 0.1), 2*pi*epsilon), osc2_amp),
		Saw.ar(LFNoise2.kr(Rand(0.05, 0.1), epsilon,
			XLine.ar(prev_freq, freq, portamento)*(osc2_freq+vib)*(1-osc2_detune)), osc2_amp),
		Pulse.ar(LFNoise2.kr(Rand(0.05, 0.1), epsilon,
			XLine.ar(prev_freq, freq, portamento)*(osc2_freq+vib)*(1-osc2_detune)),
			LFNoise2.kr(Rand(0.05, 0.1), epsilon, pwm_lfo + pwm_offset), osc2_amp));

	Out.ar(out, Pan2.ar(
		RHPF.ar(
			RLPF.ar(
				Mix.ar([
					XFade2.ar(Select.ar(osc1_wave1, osc1), Select.ar(osc1_wave2, osc1), osc1_wavemix),
					XFade2.ar(Select.ar(osc2_wave1, osc2a), Select.ar(osc2_wave2, osc2a), osc2_wavemix),
					XFade2.ar(Select.ar(osc2_wave1, osc2b), Select.ar(osc2_wave2, osc2b), osc2_wavemix)]),
				(LFNoise2.kr(Rand(0.05, 0.1), epsilon, lpf_cutoff) +
					(XLine.ar(prev_freq, freq, portamento) *
						((lpf_env*lpf_env_depth)+(mod1_send_lpf*mod1)+(mod2_send_lpf*mod2))))
				.max(20).clip2(19999),
				LFNoise2.kr(Rand(0.05, 0.1), epsilon/100, lpf_q)),
			(LFNoise2.kr(Rand(0.05, 0.1), epsilon, hpf_cutoff) +
				(XLine.ar(prev_freq, freq, portamento) *
					((hpf_env*hpf_env_depth)+(mod1_send_hpf*mod1)+(mod2_send_hpf*mod2))))
			.max(20).clip2(19999),
			LFNoise2.kr(Rand(0.05, 0.1), epsilon/100, hpf_q),
			(1+(mod1*mod1_send_dca)+(mod2*mod2_send_dca)+trem)*dca_env*amp*(veloc/128.0)),
		LFNoise2.kr(Rand(0.05, 0.1), epsilon, pan)));
}).add;
)


// don't forget to evaluate this!
(
SynthDef(\natoModulator, { |out, freq = 1, amp = 1,
	wave1 = 0, wave2 = 4, wavemix = -1, mod_inlet = nil, mod_index = 0|

	var f, mod = 0, waves;

	mod_inlet.notNil.if( { mod = In.kr(mod_inlet); } );
	f = freq * (1 + (mod * mod_index));
	waves = Array.with(SinOsc.kr(f), LFTri.kr(f), LFSaw.kr(f), 1-LFSaw.kr(f),
		Pulse.kr(f), Latch.kr(-1*mod, Impulse.kr(f)), LFNoise2.kr(f));

	Out.kr(out, XFade2.kr(Select.kr(wave1, waves), Select.kr(wave2, waves), wavemix, amp));
}).add;
)

/////////////////////
// NATOsynth
// STEP 4 - evaluate below and bend some air
(
// Groups
var notes_group = Group.new, modulators_group = Group.new(addAction:\addToHead);

// Busses
var mod1_out, mod2_out;

// Synths
var notes = Array.newClear(128);    // one slot per possible MIDI note
var mod1, mod2;
var note_history_length = 1, note_history_ptr = 0;
var note_history = Array.newClear(note_history_length);

// MIDI listeners
var on, off,
bender,
lpf_cutoff_listener, lpf_q_listener, lpf_q_val=0.2,
hpf_cutoff_listener, hpf_cutoff_val=33, hpf_q_listener, hpf_q_val=0.2;

// GUI
var window, window_bg;
var quit;
var pane_columns = 8, pane_rows = 2;
var bg_color = Color.new(0, 0, 0, 0.666), label_color = Color.new(1, 1, 1);
var slider_width = 15, slider_height = 260;
var pane_width = 105, pane_height = slider_height+50;
var margin_width = 20, margin_height = 8;
var window_width=(2*margin_width) + (pane_columns*pane_width) + ((pane_columns-1)*2);
var window_height=(2*margin_height) + (pane_rows*pane_height) + ((pane_rows-1)*2);
var button_radius=6;

var make_window, arrange_panes, make_pane, make_pane_label;
var make_slider, make_label, make_zero_button;
var panes;

var osc1_view, osc1_view_label;
var osc1_freq_slider, osc1_freq_slider_label, osc2_freq_slider, osc2_freq_slider_label;
var osc2_detune_slider, osc2_detune_slider_label;
var vib_freq_slider, vib_freq_slider_label, vib_depth_slider, vib_depth_slider_label;
var vib_delay_slider, vib_delay_slider_label;
var portamento_slider, portamento_slider_label;
var osc1_freq_zero, osc2_freq_zero;
var osc1_wave1_button, osc1_wave2_button, osc2_wave1_button, osc2_wave2_button;
var osc1_wave_slider, osc2_wave_slider;
var osc1_amp_slider, osc1_amp_slider_label, osc2_amp_slider, osc2_amp_slider_label;

var osc_mod_view, osc_mod_view_label;

var osc2_view, osc2_view_label;

var pwm_view, pwm_view_label;
var pwm_freq_slider, pwm_freq_slider_label, pwm_depth_slider, pwm_wave_button;
var pwm_delay_slider, pwm_delay_slider_label, pwm_offset_slider, pwm_offset_slider_label, pwm_offset_zero_button;

var mod1_view, mod1_view_label, mod1_send_view, mod1_send_view_label;
var mod1_freq_slider, mod1_freq_slider_label;
var mod1_wave1_button, mod1_wave2_button, mod1_wave_slider;
var mod1_deviance_slider, mod1_deviance_slider_label;

var mod2_view, mod2_view_label, mod2_send_view, mod2_send_view_label;
var mod2_freq_slider, mod2_freq_slider_label;
var mod2_wave1_button, mod2_wave2_button, mod2_wave_slider;
var mod2_deviance_slider, mod2_deviance_slider_label;

var mod1_send_hpf_slider, mod1_send_hpf_slider_label, mod1_send_hpf_zero;
var mod1_send_lpf_slider, mod1_send_lpf_slider_label, mod1_send_lpf_zero;
var mod1_send_dca_slider, mod1_send_dca_slider_label, mod1_send_dca_zero;
var mod1_send_mod2_slider, mod1_send_mod2_slider_label, mod1_send_mod2_zero;
var mod2_send_hpf_slider, mod2_send_hpf_slider_label, mod2_send_hpf_zero;
var mod2_send_lpf_slider, mod2_send_lpf_slider_label, mod2_send_lpf_zero;
var mod2_send_dca_slider, mod2_send_dca_slider_label, mod2_send_dca_zero;
var mod2_send_mod1_slider, mod2_send_mod1_slider_label, mod2_send_mod1_zero;

var hpf_view, hpf_view_label, hpf_env_view, hpf_env_view_label;
var hpf_cutoff_slider, hpf_cutoff_slider_label;
var hpf_env_slider, hpf_env_slider_label, hpf_env_zero;
var hpf_q_slider, hpf_q_slider_label;
var hpf_env_a_slider, hpf_env_a_slider_label;
var hpf_env_d_slider, hpf_env_d_slider_label;
var hpf_env_s_slider, hpf_env_s_slider_label;
var hpf_env_r_slider, hpf_env_r_slider_label;

var lpf_view, lpf_view_label, lpf_env_view, lpf_env_view_label;
var lpf_cutoff_slider, lpf_cutoff_slider_label;
var lpf_env_slider, lpf_env_slider_label, lpf_env_zero;
var lpf_q_slider, lpf_q_slider_label;
var lpf_env_a_slider, lpf_env_a_slider_label;
var lpf_env_d_slider, lpf_env_d_slider_label;
var lpf_env_s_slider, lpf_env_s_slider_label;
var lpf_env_r_slider, lpf_env_r_slider_label;

var dca_view, dca_view_label, dca_env_view, dca_env_view_label;
var trem_freq_slider, trem_freq_slider_label, trem_depth_slider, trem_depth_slider_label;
var epsilon_slider, epsilon_slider_label, amp_slider, amp_slider_label;
var dca_env_a_slider, dca_env_a_slider_label;
var dca_env_d_slider, dca_env_d_slider_label;
var dca_env_s_slider, dca_env_s_slider_label;
var dca_env_r_slider, dca_env_r_slider_label;

var pan_view, pan_view_label;
var pan_freq_slider, pan_freq_slider_label, pan_delay_slider, pan_delay_slider_label;
var pan_depth_slider, pan_depth_slider_label, pan_deviance_slider, pan_deviance_slider_label;

var mem_view, mem_view_label;
var load_button, save_button, randomize_button;
var key_label, key_text;
//var load_button_label, save_button_label;

// model & functions
var setter, updater;
var model;
var map_model_to_gui_control;
var map_model_to_control_spec;

//// Control Specs
var osc_freq_control_spec = ControlSpec(1/4, 4, \exp, 1/4);
var osc_detune_control_spec = ControlSpec(0, 0.006, \lin, default: 0);
var pitchbend_control_spec = ControlSpec(-1 * ~pitchbend_range, ~pitchbend_range);
var vib_depth_control_spec = ControlSpec(0, 0.1, \lin, default: 0);
var epsilon_control_spec = ControlSpec(0.001, 0.6666, \lin);
var f_control_spec = \freq.asSpec;
var q_control_spec = ControlSpec(1, 0);
var f_env_control_spec = ControlSpec(-16, 16);
var env_adr_control_spec = ControlSpec(0.01, 8, \exp);
var porta_control_spec = ControlSpec(0.0001, 8, \exp);
var env_s_control_spec = ControlSpec(0, 1);
var mix_control_spec = ControlSpec(0, 1);
var amp_control_spec = ControlSpec(0, 0.5);
var mod_freq_control_spec = ControlSpec(0.01, 20, \exp);
var mod_send_control_spec = ControlSpec(-2, 2);
var xfade_control_spec = ControlSpec(-1, 1);

// file functions
var load_patch, save_patch, randomize_patch;

// display settings
"".postln.postln;
"~current_tuning: ".post; ~current_tuning.postln;
"~current_scale:  ".post; ~current_scale.postln;
"~pitchbend_range: ".post; ~pitchbend_range.postln;

//// model
model = (
	osc1_freq: 0.5,
	osc1_wave1: 2,
	osc1_wave2: 3,
	osc1_wavemix: -1,
	osc2_freq: 1,
	osc2_detune: 0,
	osc2_wave1: 1,
	osc2_wave2: 3,
	osc2_wavemix: -1,
	osc1_amp: 0.333,
	osc2_amp: 0.222,
	vib_freq: 2.5,
	vib_depth: 0,
	vib_delay: 0.2,
	pitchbend: 0.0,
	portamento: 0,
	pwm_wave: 1,
	pwm_delay: 0,
	pwm_depth: 0,
	pwm_freq: 0.5,
	pwm_offset: 0.5,
	mod1_freq: 1,
	mod1_wavemix: -1,
	mod1_wave1: 0,
	mod1_wave2: 4,
	mod1_deviance: 0,
	mod1_send_hpf: 0,
	mod1_send_lpf: 0,
	mod1_send_dca: 0,
	mod1_send_mod2: 0,
	mod2_freq: 1,
	mod2_wavemix: -1,
	mod2_wave1: 0,
	mod2_wave2: 4,
	mod2_deviance: 0,
	mod2_send_hpf: 0,
	mod2_send_lpf: 0,
	mod2_send_dca: 0,
	mod2_send_mod1: 0,
	hpf_cutoff: 33,
	hpf_env_depth: 0,
	hpf_q: 0.9,
	hpf_env_a: 0.001,
	hpf_env_d: 0.3,
	hpf_env_s: 0.6,
	hpf_env_r: 3.0,
	lpf_cutoff: 330,
	lpf_env_depth: 1,
	lpf_q: 0.9,
	lpf_env_a: 0.001,
	lpf_env_d: 0.3,
	lpf_env_s: 0.6,
	lpf_env_r: 3.0,
	trem_freq: 3,
	trem_depth: 0,
	epsilon: 0.1313,
	amp: 0.3,
	dca_env_a: 0.001,
	dca_env_d: 0.3,
	dca_env_s: 0.6,
	dca_env_r: 3.0,
	pan_freq: 0.333,
	pan_depth: 0,
	pan_delay: 0,
	pan_deviance: 0
);
//"model: ".post; model.postln; //debug

map_model_to_control_spec = (
	osc1_freq: osc_freq_control_spec,
	osc1_wavemix: xfade_control_spec,
	osc1_amp: amp_control_spec,
	osc2_freq: osc_freq_control_spec,
	osc2_detune: osc_detune_control_spec,
	osc2_wavemix: xfade_control_spec,
	osc2_amp: amp_control_spec,
	vib_freq: mod_freq_control_spec,
	vib_depth: vib_depth_control_spec,
	vib_delay: env_adr_control_spec,
	pitchbend: pitchbend_control_spec,
	portamento: porta_control_spec,
	pwm_freq: mod_freq_control_spec,
	pwm_depth: mix_control_spec,
	pwm_delay: env_adr_control_spec,
	pwm_offset: mix_control_spec,
	mod1_freq: mod_freq_control_spec,
	mod1_wavemix: xfade_control_spec,
	mod1_deviance: mix_control_spec,
	mod1_send_hpf: mod_send_control_spec,
	mod1_send_lpf: mod_send_control_spec,
	mod1_send_dca: xfade_control_spec,
	mod1_send_mod2: mod_send_control_spec,
	mod2_freq: mod_freq_control_spec,
	mod2_wavemix: xfade_control_spec,
	mod2_deviance: mix_control_spec,
	mod2_send_hpf: mod_send_control_spec,
	mod2_send_lpf: mod_send_control_spec,
	mod2_send_dca: xfade_control_spec,
	mod2_send_mod1:mod_send_control_spec,
	trem_freq: mod_freq_control_spec,
	trem_depth: mix_control_spec,
	epsilon: epsilon_control_spec,
	amp: amp_control_spec,
	hpf_cutoff: f_control_spec,
	hpf_env_depth: f_env_control_spec,
	hpf_q: q_control_spec,
	hpf_env_a: env_adr_control_spec,
	hpf_env_d: env_adr_control_spec,
	hpf_env_s: env_s_control_spec,
	hpf_env_r: env_adr_control_spec,
	lpf_cutoff: f_control_spec,
	lpf_env_depth: f_env_control_spec,
	lpf_q: q_control_spec,
	lpf_env_a: env_adr_control_spec,
	lpf_env_d: env_adr_control_spec,
	lpf_env_s: env_s_control_spec,
	lpf_env_r: env_adr_control_spec,
	dca_env_a: env_adr_control_spec,
	dca_env_d: env_adr_control_spec,
	dca_env_s: env_s_control_spec,
	dca_env_r: env_adr_control_spec,
	pan_freq: mod_freq_control_spec,
	pan_depth: mix_control_spec,
	pan_delay: env_adr_control_spec,
	pan_deviance: mix_control_spec
);
//"map_model_to_control_spec: ".post; map_model_to_control_spec.postln; //debug

setter = { |key, value|
	("setter: |" ++ key ++ ", " ++ value ++ "|").postln; //debug
	model[key] = value;
	model.changed(key, value);

	switch (key,
		\mod1_freq, { mod1.set(\freq, value); },
		\mod1_wavemix, { mod1.set(\wavemix, value); },
		\mod1_wave1, { mod1.set(\wave1, value); },
		\mod1_wave2, { mod1.set(\wave2, value); },
		\mod2_freq, { mod2.set(\freq, value); },
		\mod2_wavemix, { mod2.set(\wavemix, value); },
		\mod2_wave1, { mod2.set(\wave1, value); },
		\mod2_wave2, { mod2.set(\wave2, value); },
		\mod1_send_mod2, { mod2.set(\mod_index, value); },
		\mod2_send_mod1, { mod1.set(\mod_index, value); },
		{ notes_group.set(key, value); }
	);
};

//// Init Busses
mod1_out = Bus.control;
mod2_out = Bus.control;
//mod1_out.scope; //debug
//mod2_out.scope; //debug

//// Init Synths
mod1 = Synth(\natoModulator,
	[\freq, model[\mod1_freq], \wave1, model[\mod1_wave1], \wave2, model[\mod1_wave2],
		\wavemix, model[\mod1_wavemix],
		\out, mod1_out, \mod_inlet, mod2_out, \mod_index, model[\mod2_send_mod1]], modulators_group);

mod2 = Synth(\natoModulator,
	[\freq, model[\mod2_freq], \wave1, model[\mod2_wave1], \wave2, model[\mod2_wave2],
		\wavemix, model[\mod2_wavemix],
		\out, mod2_out, \mod_inlet, mod1_out, \mod_index, model[\mod1_send_mod2]], modulators_group);

//////////////////////////////////////////// FILE
load_patch = {
	var load_path, f, f_content, f_pairs, f_line, f_key, f_val;
	Dialog.openPanel(
		{ |path|
			f = File.open(path, "r");
			f_content = f.readAllString;
//			f_content.postln; // DEBUG
			f_pairs = f_content.split($\n);
			f_pairs.do({ |item|
				f_line = item.split($,);
				f_key  = f_line[0].asSymbol;
				f_val  = f_line[1].asFloat;
				setter.value(f_key, f_val);
			});
			f.close;
		},
		{"load_patch cancelled".postln;},
		false
	);
};

save_patch = {
	var save_path, f;
	Dialog.savePanel(
		{ |path|
			f = File.open(path, "w");
			model.asPairs.do(
				{ |item, i|
					if(item.isNumber,
						{f.write("," ++ item.asString);},
						{
							if ( i != 0 ) { f.write("\n"); };
							f.write(item.asString);
						}
					)
			    }
			);
			f.close;
		},
		{"save_patch cancelled".postln;}
	);
};

randomize_patch = {
	model.keys.do(
		{ |item, i|
			map_model_to_control_spec[item].isNil.if(
				{ // Buttons are not in the control spec
					setter.value(item, map_model_to_gui_control[item].states.size.rand);
				}, {
					setter.value(item, map_model_to_control_spec[item].map(1.0.rand));
				}
			);
		}
	);
};

//////////////////////////////////////////// GUI
Font.setDefault(Font("Andale Mono"), View);

////////////// Control Makers
make_window = { |panes, title, bgimg|
	var window, window_bg;

	window = Window(title, Rect(12, 600, window_width, window_height));
	window_bg = Image.open(bgimg);
	window_bg.interpolation = \smooth;
	window_bg.scalesWhenResized_(true);
	window_bg.setSize(window_width, window_height);
	window.view.backgroundImage_(window_bg);
};

arrange_panes = { |panes|
	panes.do( { |row, i|
		row.do( { |pane, j|
			pane.moveTo(margin_width + (j*(pane_width + 2)), margin_height + (i*(pane_height+2)));
		} );
	} );
};

make_pane = { |view|
	CompositeView(window, Point(pane_width, pane_height))
	.background_(bg_color);
};

make_pane_label = { |view, text|
	StaticText(view, Rect(0, 8, pane_width, 10))
	.string_(text)
	.font_(Font.default.boldVariant)
	.stringColor_(label_color)
	.align_(\center);
};

make_slider = { |view, key, x, y|
	Slider(view, Rect(x, y, slider_width, slider_height))
	.value_(map_model_to_control_spec[key].unmap(model[key]))
	.action_({ |view| setter.value(key, map_model_to_control_spec[key].map(view.value)); });
};

make_label = { |view, text, x, y|
	StaticText(view, Rect(x, y, slider_width, 20))
	.string_(text)
	.stringColor_(label_color)
	.align_(\center);
};

make_zero_button = { |view, key, zeroval, x, y|
	Button(view, Rect(x, y, button_radius, button_radius))
	.states_([" "])
	.action_({ |view| setter.value(key, zeroval); });
};

////////// make window
window = make_window.value(panes, "NATOsynth", "~/Documents/SuperCollider/NATOsynth/Flag_of_NATO.png");

osc1_view = make_pane.value(window);
osc1_view_label = make_pane_label.value(osc1_view, "OSC1");

osc_mod_view = make_pane.value(window);
osc_mod_view_label = make_pane_label.value(osc_mod_view, ">OSC");

osc2_view = make_pane.value(window);
osc2_view_label = make_pane_label.value(osc2_view, "OSC2");

pwm_view = make_pane.value(window);
pwm_view_label = make_pane_label.value(pwm_view, "PWM");

mod1_view = make_pane.value(window);
mod1_view_label = make_pane_label.value(mod1_view, "MOD1");

mod1_send_view = make_pane.value(window);
mod1_send_view_label = make_pane_label.value(mod1_send_view, "MOD1>");

mod2_view = make_pane.value(window);
mod2_view_label = make_pane_label.value(mod2_view, "MOD2");

mod2_send_view = make_pane.value(window);
mod2_send_view_label = make_pane_label.value(mod2_send_view, "MOD2>");

hpf_view = make_pane.value(window);
hpf_view_label = make_pane_label.value(hpf_view, "HPF");

hpf_env_view = make_pane.value(window);
hpf_env_view_label = make_pane_label.value(hpf_env_view, "HPFe");

lpf_view = make_pane.value(window);
lpf_view_label = make_pane_label.value(lpf_view, "LPF");

lpf_env_view = make_pane.value(window);
lpf_env_view_label = make_pane_label.value(lpf_env_view, "LPFe");

dca_view = make_pane.value(window);
dca_view_label = make_pane_label.value(dca_view, "AMP");

dca_env_view = make_pane.value(window);
dca_env_view_label = make_pane_label.value(dca_env_view, "AMPe");

pan_view = make_pane.value(window);
pan_view_label = make_pane_label.value(pan_view, "PAN");

mem_view = make_pane.value(window);
mem_view_label = make_pane_label.value(mem_view, "MEM");

// legend
key_label = StaticText(mem_view, Rect(0, 49, pane_width, 59))
.string_("KEY")
.font_(Font.default.boldVariant)
.stringColor_(label_color)
.align_(\center);

key_text = StaticText(mem_view, Rect(4, 76, pane_width-4, 240))
.string_("ƒ = frequency\nA = amplitude\n± = detune\nd = delay\n∫ = slew\nW = PW offset\nσ = deviation\n∆ = depth\nQ = resonance\nε = error\nΣ = output amp\nR = random\n1,2 = MOD1,2\nH,L = HPF, LPF")
.font_(Font.default)
.stringColor_(label_color)
.align_(\left);

panes = [[osc1_view, osc2_view, mod1_view, mod2_view, hpf_view, lpf_view, dca_view, pan_view],
	[osc_mod_view, pwm_view, mod1_send_view, mod2_send_view, hpf_env_view, lpf_env_view, dca_env_view, mem_view]];

arrange_panes.value(panes);

/////////////////// make Controls

// OSC 1
osc1_freq_slider = make_slider.value(osc1_view, \osc1_freq, 20, 25);
osc1_freq_slider_label = make_label.value(osc1_view, "ƒ", 20, margin_height + slider_height + 18);
osc1_freq_zero = make_zero_button.value(osc1_view, \osc1_freq, 1, 20 + (slider_width/2) + (button_radius/2) + 3, 25 + (slider_height/2) - 3);

osc1_wave1_button = Button(osc1_view, Rect(45, margin_height + slider_height + 21, slider_width, slider_width))
.states_(~natosynth_waves)
.value_(model[\osc1_wave1])
.action_({ |view| setter.value(\osc1_wave1, view.value); });

osc1_wave2_button = Button(osc1_view, Rect(45, margin_height + 19, slider_width, slider_width))
.states_(~natosynth_waves)
.value_(model[\osc1_wave2])
.action_({ |view| setter.value(\osc1_wave2, view.value); });

osc1_wave_slider = Slider(osc1_view, Rect(45, margin_height + 18 + 18, slider_width, slider_height - 20))
.value_(map_model_to_control_spec[\osc1_wavemix].unmap(model[\osc1_wavemix]))
.action_({ |view| setter.value(\osc1_wavemix, map_model_to_control_spec[\osc1_wavemix].map(view.value)); });

osc1_amp_slider = make_slider.value(osc1_view, \osc1_amp, 70, 25);
osc1_amp_slider_label = make_label.value(osc1_view, "A", 70, margin_height + slider_height + 18);

// OSC 2
osc2_freq_slider = make_slider.value(osc2_view, \osc2_freq, 12+(0*22), 25);
osc2_freq_slider_label = make_label.value(osc2_view, "ƒ", 12+(0*22), margin_height + slider_height + 18);
osc2_freq_zero = make_zero_button.value(osc2_view, \osc2_freq, 1, 12+(0*22) + (slider_width/2) + (button_radius/2) + 3, 25 + (slider_height/2) - 3);

osc2_wave1_button = Button(osc2_view, Rect(12+(1*22), margin_height + slider_height + 21, slider_width, slider_width))
.states_(~natosynth_waves)
.value_(model[\osc2_wave1])
.action_({ |view| setter.value(\osc2_wave1, view.value); });

osc2_wave2_button = Button(osc2_view, Rect(12+(1*22), margin_height + 19, slider_width, slider_width))
.states_(~natosynth_waves)
.value_(model[\osc2_wave2])
.action_({ |view| setter.value(\osc2_wave2, view.value); });

osc2_wave_slider = Slider(osc2_view, Rect(12+(1*22), margin_height + 18 + 18, slider_width, slider_height - 20))
.value_(map_model_to_control_spec[\osc2_wavemix].unmap(model[\osc2_wavemix]))
.action_({ |view| setter.value(\osc2_wavemix, map_model_to_control_spec[\osc2_wavemix].map(view.value)); });

osc2_detune_slider = make_slider.value(osc2_view, \osc2_detune, 12+(2*22), 25);
osc2_detune_slider_label = make_label.value(osc2_view, "±", 12+(2*22), margin_height + slider_height + 18);

osc2_amp_slider = make_slider.value(osc2_view, \osc2_amp, 12+(3*22), 25);
osc2_amp_slider_label = make_label.value(osc2_view, "A", 12+(3*22), margin_height + slider_height + 18);

// OSC MOD
vib_freq_slider = make_slider.value(osc_mod_view, \vib_freq, 12+(0*22), 25);
vib_freq_slider_label = make_label.value(osc_mod_view, "ƒ", 12+(0*22), margin_height + slider_height + 18);

vib_depth_slider = make_slider.value(osc_mod_view, \vib_depth, 12+(1*22), 25);
vib_depth_slider_label = make_label.value(osc_mod_view, "∆", 12+(1*22), margin_height + slider_height + 18);

vib_delay_slider = make_slider.value(osc_mod_view, \vib_delay, 12+(2*22), 25);
vib_delay_slider_label = make_label.value(osc_mod_view, "d", 12+(2*22), margin_height + slider_height + 18);

portamento_slider = make_slider.value(osc_mod_view, \portamento, 12+(3*22), 25);
portamento_slider_label = make_label.value(osc_mod_view, "∫", 12+(3*22), margin_height + slider_height + 18);

// PWM
pwm_freq_slider = make_slider.value(pwm_view, \pwm_freq, 12+(0*22), 25);
pwm_freq_slider_label = make_label.value(pwm_view, "ƒ", 12+(0*22), margin_height + slider_height + 18);

pwm_wave_button = Button(pwm_view, Rect(12+(1*22), margin_height + slider_height + 21, slider_width, slider_width))
.states_(~natosynth_lfo_waves)
.value_(model[\pwm_wave])
.action_({ |view| setter.value(\pwm_wave, view.value); });

pwm_depth_slider = make_slider.value(pwm_view, \pwm_depth, 12+(1*22), 25);

pwm_delay_slider = make_slider.value(pwm_view, \pwm_delay, 12+(2*22), 25);
pwm_delay_slider_label = make_label.value(pwm_view, "d", 12+(2*22), margin_height + slider_height + 18);

pwm_offset_slider = make_slider.value(pwm_view, \pwm_offset, 12+(3*22), 25);
pwm_offset_slider_label = make_label.value(pwm_view, "W", 12+(3*22), margin_height + slider_height + 18);
pwm_offset_zero_button = make_zero_button.value(pwm_view, \pwm_offset, 0.5, 12+(3*22) + (slider_width/2) + (button_radius/2) + 3, 25 + (slider_height/2) - 3);

// MOD1
mod1_freq_slider = make_slider.value(mod1_view, \mod1_freq, 20, 25);
mod1_freq_slider_label = make_label.value(mod1_view, "ƒ", 20, margin_height + slider_height + 18);

mod1_wave_slider = Slider(mod1_view, Rect(45, margin_height + 18 + 18, slider_width, slider_height - 20))
.value_(map_model_to_control_spec[\mod1_wavemix].unmap(model[\mod1_wavemix]))
.action_({ |view| setter.value(\mod1_wavemix, map_model_to_control_spec[\mod1_wavemix].map(view.value)); });

mod1_wave1_button = Button(mod1_view, Rect(45, margin_height + slider_height + 21, slider_width, slider_width))
.states_(~natomodulator1_waves)
.value_(model[\mod1_wave1])
.action_({ |view| setter.value(\mod1_wave1, view.value); });

mod1_wave2_button = Button(mod1_view, Rect(45, margin_height + 19, slider_width, slider_width))
.states_(~natomodulator1_waves)
.value_(model[\mod1_wave2])
.action_({ |view| setter.value(\mod1_wave2, view.value); });

mod1_deviance_slider = make_slider.value(mod1_view, \mod1_deviance, 70, 25);
mod1_deviance_slider_label = make_label.value(mod1_view, "σ", 70, margin_height + slider_height + 18);

// MOD1 SEND
mod1_send_hpf_slider = make_slider.value(mod1_send_view, \mod1_send_hpf, 12+(0*22), 25);
mod1_send_hpf_slider_label = make_label.value(mod1_send_view, "H", 12+(0*22), margin_height + slider_height + 18);
mod1_send_hpf_zero = make_zero_button.value(mod1_send_view, \mod1_send_hpf, 0, 12+(0*22) + (slider_width/2) + (button_radius/2) + 3, 25 + (slider_height/2) - 3);

mod1_send_lpf_slider = make_slider.value(mod1_send_view, \mod1_send_lpf, 12+(1*22), 25);
mod1_send_lpf_slider_label = make_label.value(mod1_send_view, "L", 12+(1*22), margin_height + slider_height + 18);
mod1_send_lpf_zero = make_zero_button.value(mod1_send_view, \mod1_send_lpf, 0, 12+(1*22) + (slider_width/2) + (button_radius/2) + 3, 25 + (slider_height/2) - 3);

mod1_send_dca_slider = make_slider.value(mod1_send_view, \mod1_send_dca, 12+(2*22), 25);
mod1_send_dca_slider_label = make_label.value(mod1_send_view, "A", 12+(2*22), margin_height + slider_height + 18);
mod1_send_dca_zero = make_zero_button.value(mod1_send_view, \mod1_send_dca, 0, 12+(2*22) + (slider_width/2) + (button_radius/2) + 3, 25 + (slider_height/2) - 3);

mod1_send_mod2_slider = make_slider.value(mod1_send_view, \mod1_send_mod2, 12+(3*22), 25);
mod1_send_mod2_slider_label = make_label.value(mod1_send_view, "2", 12+(3*22), margin_height + slider_height + 18);
mod1_send_mod2_zero = make_zero_button.value(mod1_send_view, \mod1_send_mod2, 0, 12+(3*22) + (slider_width/2) + (button_radius/2) + 3, 25 + (slider_height/2) - 3);

// MOD 2
mod2_freq_slider = make_slider.value(mod2_view, \mod2_freq, 20, 25);
mod2_freq_slider_label = make_label.value(mod2_view, "ƒ", 20, margin_height + slider_height + 18);

mod2_wave_slider = Slider(mod2_view, Rect(45, margin_height + 18 + 18, slider_width, slider_height - 20))
.value_(map_model_to_control_spec[\mod2_wavemix].unmap(model[\mod2_wavemix]))
.action_({ |view| setter.value(\mod2_wavemix, map_model_to_control_spec[\mod2_wavemix].map(view.value)); });

mod2_wave1_button = Button(mod2_view, Rect(45, margin_height + slider_height + 21, slider_width, slider_width))
.states_(~natomodulator2_waves)
.value_(model[\mod2_wave1])
.action_({ |view| setter.value(\mod2_wave1, view.value); });

mod2_wave2_button = Button(mod2_view, Rect(45, margin_height + 19, slider_width, slider_width))
.states_(~natomodulator2_waves)
.value_(model[\mod2_wave2])
.action_({ |view| setter.value(\mod2_wave2, view.value); });

mod2_deviance_slider = make_slider.value(mod2_view, \mod2_deviance, 70, 25);
mod2_deviance_slider_label = make_label.value(mod2_view, "σ", 70, margin_height + slider_height + 18);

// MOD 2 SEND
mod2_send_hpf_slider = make_slider.value(mod2_send_view, \mod2_send_hpf, 12+(0*22), 25);
mod2_send_hpf_slider_label = make_label.value(mod2_send_view, "H", 12+(0*22), margin_height + slider_height + 18);
mod2_send_hpf_zero = make_zero_button.value(mod2_send_view, \mod2_send_hpf, 0, 12+(0*22) + (slider_width/2) + (button_radius/2) + 3, 25 + (slider_height/2) - 3);

mod2_send_lpf_slider = make_slider.value(mod2_send_view, \mod2_send_lpf, 12+(1*22), 25);
mod2_send_lpf_slider_label = make_label.value(mod2_send_view, "L", 12+(1*22), margin_height + slider_height + 18);
mod2_send_lpf_zero = make_zero_button.value(mod2_send_view, \mod2_send_lpf, 0, 12+(1*22) + (slider_width/2) + (button_radius/2) + 3, 25 + (slider_height/2) - 3);

mod2_send_dca_slider = make_slider.value(mod2_send_view, \mod2_send_dca, 12+(2*22), 25);
mod2_send_dca_slider_label = make_label.value(mod2_send_view, "A", 12+(2*22), margin_height + slider_height + 18);
mod2_send_dca_zero = make_zero_button.value(mod2_send_view, \mod2_send_dca, 0, 12+(2*22) + (slider_width/2) + (button_radius/2) + 3, 25 + (slider_height/2) - 3);

mod2_send_mod1_slider = make_slider.value(mod2_send_view, \mod2_send_mod1, 12+(3*22), 25);
mod2_send_mod1_slider_label = make_label.value(mod2_send_view, "1", 12+(3*22), margin_height + slider_height + 18);
mod2_send_mod1_zero = make_zero_button.value(mod2_send_view, \mod2_send_mod1, 0, 12+(3*22) + (slider_width/2) + (button_radius/2) + 3, 25 + (slider_height/2) - 3);

// HPF
hpf_cutoff_slider = make_slider.value(hpf_view, \hpf_cutoff, 20, 25);
hpf_cutoff_slider_label = make_label.value(hpf_view, "ƒ", 20, margin_height + slider_height + 18);

hpf_env_slider = make_slider.value(hpf_view, \hpf_env_depth, 45, 25);
hpf_env_slider_label = make_label.value(hpf_view, "∆", 45, margin_height + slider_height + 18);
hpf_env_zero = make_zero_button.value(hpf_view, \hpf_env_depth, 0, 45 + (slider_width/2) + (button_radius/2) + 3, 25 + (slider_height/2) - 3);

hpf_q_slider = make_slider.value(hpf_view, \hpf_q, 70, 25);
hpf_q_slider_label = make_label.value(hpf_view, "Q", 70, margin_height + slider_height + 18);

// HPF ENV
hpf_env_a_slider = make_slider.value(hpf_env_view, \hpf_env_a, 12+(0*22), margin_height + 18);
hpf_env_a_slider_label = make_label.value(hpf_env_view, "A", 12+(0*22), margin_height + slider_height + 18);

hpf_env_d_slider = make_slider.value(hpf_env_view, \hpf_env_d, 12+(1*22), margin_height + 18);
hpf_env_d_slider_label = make_label.value(hpf_env_view, "D", 12+(1*22), margin_height + slider_height + 18);

hpf_env_s_slider = make_slider.value(hpf_env_view, \hpf_env_s, 12+(2*22), margin_height + 18);
hpf_env_s_slider_label = make_label.value(hpf_env_view, "S", 12+(2*22), margin_height + slider_height + 18);

hpf_env_r_slider = make_slider.value(hpf_env_view, \hpf_env_r, 12+(3*22), margin_height + 18);
hpf_env_r_slider_label = make_label.value(hpf_env_view, "R", 12+(3*22), margin_height + slider_height + 18);

// LPF
lpf_cutoff_slider = make_slider.value(lpf_view, \lpf_cutoff, 20, 25);
lpf_cutoff_slider_label = make_label.value(lpf_view, "ƒ", 20, margin_height + slider_height + 18);

lpf_env_slider = make_slider.value(lpf_view, \lpf_env_depth, 45, 25);
lpf_env_slider_label = make_label.value(lpf_view, "∆", 45, margin_height + slider_height + 18);
lpf_env_zero = make_zero_button.value(lpf_view, \lpf_env_depth, 0, 45 + (slider_width/2) + (button_radius/2) + 3, 25 + (slider_height/2) - 3);

lpf_q_slider = make_slider.value(lpf_view, \lpf_q, 70, 25);
lpf_q_slider_label = make_label.value(lpf_view, "Q", 70, margin_height + slider_height + 18);

// LPF ENV
lpf_env_a_slider = make_slider.value(lpf_env_view, \lpf_env_a, 12+(0*22), margin_height + 18);
lpf_env_a_slider_label = make_label.value(lpf_env_view, "A", 12+(0*22), margin_height + slider_height + 18);

lpf_env_d_slider = make_slider.value(lpf_env_view, \lpf_env_d, 12+(1*22), margin_height + 18);
lpf_env_d_slider_label = make_label.value(lpf_env_view, "D", 12+(1*22), margin_height + slider_height + 18);

lpf_env_s_slider = make_slider.value(lpf_env_view, \lpf_env_s, 12+(2*22), margin_height + 18);
lpf_env_s_slider_label = make_label.value(lpf_env_view, "S", 12+(2*22), margin_height + slider_height + 18);

lpf_env_r_slider = make_slider.value(lpf_env_view, \lpf_env_r, 12+(3*22), margin_height + 18);
lpf_env_r_slider_label = make_label.value(lpf_env_view, "R", 12+(3*22), margin_height + slider_height + 18);

// DCA
trem_freq_slider = make_slider.value(dca_view, \trem_freq, 12+(0*22), 25);
trem_freq_slider_label = make_label.value(dca_view, "ƒ", 12+(0*22), margin_height + slider_height + 18);

trem_depth_slider = make_slider.value(dca_view, \trem_depth, 12+(1*22), 25);
trem_depth_slider_label = make_label.value(dca_view, "∆", 12+(1*22), margin_height + slider_height + 18);

epsilon_slider = make_slider.value(dca_view, \epsilon, 12+(2*22), margin_height + 18);
epsilon_slider_label = make_label.value(dca_view, "ε", 12+(2*22), margin_height + slider_height + 18);

amp_slider = make_slider.value(dca_view, \amp, 12+(3*22), margin_height + 18);
amp_slider_label = make_label.value(dca_view, "Σ", 12+(3*22), margin_height + slider_height + 18);

// DCA ENV
dca_env_a_slider = make_slider.value(dca_env_view, \dca_env_a, 12+(0*22), margin_height + 18);
dca_env_a_slider_label = make_label.value(dca_env_view, "A", 12+(0*22), margin_height + slider_height + 18);

dca_env_d_slider = make_slider.value(dca_env_view, \dca_env_d, 12+(1*22), margin_height + 18);
dca_env_d_slider_label = make_label.value(dca_env_view, "D", 12+(1*22), margin_height + slider_height + 18);

dca_env_s_slider = make_slider.value(dca_env_view, \dca_env_s, 12+(2*22), margin_height + 18);
dca_env_s_slider_label = make_label.value(dca_env_view, "S", 12+(2*22), margin_height + slider_height + 18);

dca_env_r_slider = make_slider.value(dca_env_view, \dca_env_r, 12+(3*22), margin_height + 18);
dca_env_r_slider_label = make_label.value(dca_env_view, "R", 12+(3*22), margin_height + slider_height + 18);

// PAN
pan_freq_slider = make_slider.value(pan_view, \pan_freq, 12+(0*22), margin_height + 18);
pan_freq_slider_label = make_label.value(pan_view, "ƒ", 12+(0*22), margin_height + slider_height + 18);

pan_depth_slider = make_slider.value(pan_view, \pan_depth, 12+(1*22), margin_height + 18);
pan_depth_slider_label = make_label.value(pan_view, "∆", 12+(1*22), margin_height + slider_height + 18);

pan_delay_slider = make_slider.value(pan_view, \pan_delay, 12+(2*22), margin_height + 18);
pan_delay_slider_label = make_label.value(pan_view, "d", 12+(2*22), margin_height + slider_height + 18);

pan_deviance_slider = make_slider.value(pan_view, \pan_deviance, 12+(3*22), margin_height + 18);
pan_deviance_slider_label = make_label.value(pan_view, "σ", 12+(3*22), margin_height + slider_height + 18);

// MEM
load_button = Button(mem_view, Rect(6, margin_height + 19, 42, slider_width))
.states_([["Load", Color.black, Color.white]])
.action_(load_patch);

save_button = Button(mem_view, Rect(54, margin_height + 19, 42, slider_width))
.states_([["Save", Color.black, Color.white]])
.action_(save_patch);

randomize_button = Button(mem_view, Rect(14, margin_height + 39, 76, slider_width))
.states_([["Randomize", Color.black, Color.white]])
.action_(randomize_patch);

map_model_to_gui_control = (
	osc1_freq: osc1_freq_slider,
	osc1_wave1: osc1_wave1_button,
	osc1_wave2: osc1_wave2_button,
	osc1_wavemix: osc1_wave_slider,
	osc1_amp: osc1_amp_slider,
	osc2_freq: osc2_freq_slider,
	osc2_detune: osc2_detune_slider,
	osc2_wave1: osc2_wave1_button,
	osc2_wave2: osc2_wave2_button,
	osc2_wavemix: osc2_wave_slider,
	osc2_amp: osc2_amp_slider,
	pwm_freq: pwm_freq_slider,
	pwm_wave: pwm_wave_button,
	pwm_depth: pwm_depth_slider,
	pwm_delay: pwm_delay_slider,
	pwm_offset: pwm_offset_slider,
	vib_freq: vib_freq_slider,
	vib_depth: vib_depth_slider,
	vib_delay: vib_delay_slider,
	portamento: portamento_slider,
	mod1_freq: mod1_freq_slider,
	mod1_wave1: mod1_wave1_button,
	mod1_wave2: mod1_wave2_button,
	mod1_wavemix: mod1_wave_slider,
	mod1_deviance: mod1_deviance_slider,
	mod1_send_hpf: mod1_send_hpf_slider,
	mod1_send_lpf: mod1_send_lpf_slider,
	mod1_send_dca: mod1_send_dca_slider,
	mod1_send_mod2: mod1_send_mod2_slider,
	mod2_freq: mod2_freq_slider,
	mod2_wave1: mod2_wave1_button,
	mod2_wave2: mod2_wave2_button,
	mod2_wavemix: mod2_wave_slider,
	mod2_deviance: mod2_deviance_slider,
	mod2_send_hpf: mod2_send_hpf_slider,
	mod2_send_lpf: mod2_send_lpf_slider,
	mod2_send_dca: mod2_send_dca_slider,
	mod2_send_mod1: mod2_send_mod1_slider,
	hpf_cutoff: hpf_cutoff_slider,
	hpf_env_depth: hpf_env_slider,
	hpf_q: hpf_q_slider,
	hpf_env_a: hpf_env_a_slider,
	hpf_env_d: hpf_env_d_slider,
	hpf_env_s: hpf_env_s_slider,
	hpf_env_r: hpf_env_r_slider,
	lpf_cutoff: lpf_cutoff_slider,
	lpf_env_depth: lpf_env_slider,
	lpf_q: lpf_q_slider,
	lpf_env_a: lpf_env_a_slider,
	lpf_env_d: lpf_env_d_slider,
	lpf_env_s: lpf_env_s_slider,
	lpf_env_r: lpf_env_r_slider,
	trem_freq: trem_freq_slider,
	trem_depth: trem_depth_slider,
	epsilon: epsilon_slider,
	amp: amp_slider,
	dca_env_a: dca_env_a_slider,
	dca_env_d: dca_env_d_slider,
	dca_env_s: dca_env_s_slider,
	dca_env_r: dca_env_r_slider,
	pan_freq: pan_freq_slider,
	pan_depth: pan_depth_slider,
	pan_delay: pan_delay_slider,
	pan_deviance: pan_deviance_slider
);
//"map_model_to_gui_control: ".post; map_model_to_gui_control.postln; //debug

updater = { |changer, what, val|
	{
//		("updater: |changer=" ++ changer ++ ", what=" ++ what ++ ", val=" ++ val ++ "|").postln; //debug
		if (what != \pitchbend) { // no GUI control for pitchbend, ignore
			if(map_model_to_control_spec[what].notNil, {
				map_model_to_gui_control[what].value_(map_model_to_control_spec[what].unmap(val));
			}, {
				map_model_to_gui_control[what].value_(val);
			// buttons have no control spec. we need to set manually in case we just loaded a new patch
		});
		}
	}.defer;
};
model.addDependant(updater);

//// launch window
window.front;

// midi handlers
on = MIDIFunc.noteOn( { |veloc, num, chan, src|
	var f = ~current_scale.degreeToFreq(num%(~current_scale.pitchesPerOctave),
		0.midicps, (num/~current_scale.pitchesPerOctave).trunc());
	var f_pb = ~current_scale.degreeToFreq((num+model[\pitchbend])%(~current_scale.pitchesPerOctave),
		0.midicps, ((num+model[\pitchbend])/~current_scale.pitchesPerOctave).trunc());
	var prev_f = note_history[note_history_ptr];
	if(prev_f.isNil, { prev_f = f; }, {});

	"noteOn freq = ".post; f.post; "\tv = ".post; veloc.postln; // debug
/*	"note_history_ptr = ".post; note_history_ptr.postln; //debug
	note_history.do({|item| item.post; "\t".post;}); "".postln; // debug
	"prev_f = ".post; prev_f.postln; // debug
	"".postln; //debug */

	if (notes[num].notNil, {
//		"DEBUG: noteOn called for note that is already on!".postln;
		notes[num].release; notes[num] = nil;
	});

	notes[num] = Synth(\natoSynth, [
		\note_num, num, \freq, f_pb, \prev_freq, prev_f, \veloc, veloc,
		\osc1_amp, model[\osc1_amp], \osc2_amp, model[\osc2_amp],
		\osc1_freq, model[\osc1_freq], \osc2_freq, model[\osc2_freq],
		\osc2_detune, model[\osc2_detune],
		\osc1_wave1, model[\osc1_wave1], \osc1_wave2, model[\osc1_wave2],
		\osc1_wavemix, model[\osc1_wavemix], \osc2_wavemix, model[\osc2_wavemix],
		\osc2_wave1, model[\osc2_wave1], \osc2_wave2, model[\osc2_wave2],
		\pwm_freq, model[\pwm_freq], \pwm_depth, model[\pwm_depth], \pwm_delay, model[\pwm_delay],
		\pwm_offset, model[\pwm_offset], \pwm_wave, model[\pwm_wave],
		\vib_freq, model[\vib_freq], \vib_depth, model[\vib_depth], \vib_delay, model[\vib_delay],
		\pitchbend, model[\pitchbend], \portamento, model[\portamento],
		\mod1_inlet, mod1_out, \mod2_inlet, mod2_out,
		\mod1_deviance, model[\mod1_deviance], \mod2_deviance, model[\mod2_deviance],
		\mod1_send_hpf, model[\mod1_send_hpf], \mod1_send_lpf, model[\mod1_send_lpf],
		\mod1_send_dca, model[\mod1_send_dca],
		\mod2_send_hpf, model[\mod2_send_hpf], \mod2_send_lpf, model[\mod2_send_lpf],
		\mod2_send_dca, model[\mod2_send_dca],
		\lpf_cutoff, model[\lpf_cutoff], \lpf_env_depth, model[\lpf_env_depth], \lpf_q, model[\lpf_q],
		\hpf_cutoff, model[\hpf_cutoff], \hpf_env_depth, model[\hpf_env_depth], \hpf_q, model[\hpf_q],
		\hpf_env_a, model[\hpf_env_a], \hpf_env_d, model[\hpf_env_d],
		\hpf_env_s, model[\hpf_env_s], \hpf_env_r, model[\hpf_env_r],
		\lpf_env_a, model[\lpf_env_a], \lpf_env_d, model[\lpf_env_d],
		\lpf_env_s, model[\lpf_env_s], \lpf_env_r, model[\lpf_env_r],
		\trem_freq, model[\trem_freq], \trem_depth, model[\trem_depth],
		\amp, model[\amp], \epsilon, model[\epsilon],
		\dca_env_a, model[\dca_env_a], \dca_env_d, model[\dca_env_d],
		\dca_env_s, model[\dca_env_s], \dca_env_r, model[\dca_env_r],
		\pan_freq, model[\pan_freq], \pan_depth, model[\pan_depth],
		\pan_delay, model[\pan_delay], \pan_deviance, model[\pan_deviance]],
	target:notes_group, addAction:\addToHead
	);

	note_history[note_history_ptr] = f;
	note_history_ptr = (note_history_ptr + 1) % note_history_length;
});

off = MIDIFunc.noteOff({ |veloc, num, chan, src|
	if (notes[num].notNil, {
		notes[num].release; notes[num] = nil;
	});
});

bender = MIDIFunc.bend({ |val, chan, src|
	var freq_pb;
	"bender: ".post; val.postln; // debug
	setter.value(\pitchbend, map_model_to_control_spec[\pitchbend].map(val/16383.0));

//	"\tfreq_pb = ".post; freq_pb.postln; // debug

//	notes_group.do({ |note|
	notes.do({ |note, note_num|
		if (note.notNil, {
			freq_pb = ~current_scale.degreeToFreq(
				(note_num+model[\pitchbend])%(~current_scale.pitchesPerOctave),
				0.midicps,
				((note_num+model[\pitchbend])/~current_scale.pitchesPerOctave).trunc());
			note.set(\freq, freq_pb);
			note.get(\freq, { |newval| ("\t"++newval).postln; }); // debug - why no live pitchbend!!!???
			("\t" ++ note_num ++ ": ").post; freq_pb.postln; // debug
		});
	});
});

lpf_cutoff_listener = MIDIFunc.cc({ |val, num, chan, src|
//	postln("lpf_cutoff_listener: val=" ++ val); //debug
	setter.value(\lpf_cutoff, map_model_to_control_spec[\lpf_cutoff].map(val/127));
}, 14);

lpf_q_listener = MIDIFunc.cc({ |val, num, chan, src|
//	postln("lpf_q_listener: val=" ++ val); //debug
	setter.value(\lpf_q, map_model_to_control_spec[\lpf_q].map(val/127));
}, 15);

hpf_cutoff_listener = MIDIFunc.cc({ |val, num, chan, src|
	setter.value(\hpf_cutoff, map_model_to_control_spec[\hpf_cutoff].map(val/127));
}, 16);

hpf_q_listener = MIDIFunc.cc({ |val, num, chan, src|
	setter.value(\hpf_q, map_model_to_control_spec[\hpf_q].map(val/127));
}, 17);

//// cleanup
quit = {
	model.release;
	notes_group.release; notes_group.free;
	modulators_group.release; modulators_group.free;
	mod1_out.free; mod2_out.free;
	on.free; off.free; bender.free;
	lpf_cutoff_listener.free; lpf_q_listener.free;
	hpf_cutoff_listener.free; hpf_q_listener.free;
	window.close;
};

window.onClose_({ quit.value; });

//"dependants: ".post; model.dependants.postln; //debug
)

(
q = { MIDIIn.disconnectAll; MIDIClient.disposeClient; };
)
q.value; // use when quitting studio

