// Engine_SineNote.sc
//
// This is the SuperCollider side of the norns script.
// A norns "engine" is a class that extends CroneEngine.
// The class name MUST be "Engine_" + the name you set in Lua
// with `engine.name = "SineNote"`.

Engine_SineNote : CroneEngine {

	// a control bus holding the master amplitude. every note synth reads
	// it live, so changing it affects notes that are already sounding.
	var <ampBus;

	// *new is the constructor norns calls. Just pass through to super.
	*new { arg context, doneCallback;
		^super.new(context, doneCallback);
	}

	// alloc runs once when the engine is loaded.
	// Define buses, SynthDefs and register commands here.
	alloc {

		// allocate the master-amplitude bus and give it a starting value.
		ampBus = Bus.control(context.server, 1);
		ampBus.set(1.0);

		// The actual sound: one sine oscillator shaped by an envelope,
		// then scaled by the shared master amplitude.
		//   env levels: 0 -> amp -> amp -> 0   (starts and ends silent)
		//   env times : fadeIn, sustain, fadeOut
		// doneAction: 2 frees the synth automatically when the env ends.
		SynthDef("sineNote", {
			arg freq = 440,
			    amp = 0.5,
			    fadeIn = 8,
			    sustain = 10,
			    fadeOut = 5,
			    ampBus = 0,
			    out = 0;

			var env, master, sig;

			env = EnvGen.kr(
				Env.new(
					levels: [0, amp, amp, 0],
					times:  [fadeIn, sustain, fadeOut],
					curve:  \sin            // smooth S-curve fades
				),
				doneAction: Done.freeSelf   // == 2, frees synth at the end
			);

			// read the current master amplitude from the control bus
			master = In.kr(ampBus);

			sig = SinOsc.ar(freq) * env * master;

			// send the same signal to left and right
			Out.ar(out, [sig, sig]);
		}).add;

		// Make sure the SynthDef is registered before any command uses it.
		context.server.sync;

		// engine.playNote(freq, fadeIn, sustain, fadeOut)
		// "ffff" = four float arguments.
		this.addCommand("playNote", "ffff", { arg msg;
			Synth.new(
				"sineNote",
				[
					\freq,    msg[1],
					\fadeIn,  msg[2],
					\sustain, msg[3],
					\fadeOut, msg[4],
					\ampBus,  ampBus.index,   // tell the synth which bus to read
					\out,     context.out_b.index
				],
				context.xg   // the engine's group in the audio graph
			);
		});

		// engine.setAmp(level) -- live master amplitude for the whole mix.
		this.addCommand("setAmp", "f", { arg msg;
			ampBus.set(msg[1]);
		});
	}

	// Called when the engine is unloaded. Free the bus we allocated.
	// (Each note frees itself via doneAction.)
	free {
		ampBus.free;
	}
}
