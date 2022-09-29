package;

import grig.midi.MidiMessage;
import grig.midi.MidiOut;
import haxe.Timer;
import tink.core.Future;

using Main.MidiNoteExtensions;


class Main {
	private static function mainLoop(midiOut:MidiOut) {
		var pulses_per_quarter_note = 24;
		var bars_in_buffer = 1;
		var quarter_notes_in_bar = 4;
		var buffer_length = (quarter_notes_in_bar * pulses_per_quarter_note) * bars_in_buffer;
		var seconds_per_minute = 60;
		var ms_per_second = 1000;
		var ms_per_minute = ms_per_second * seconds_per_minute;
		var quarter_notes_per_minute = 100;
		var ms_per_quarter_note = ms_per_minute / quarter_notes_per_minute;
		var ms_per_pulse:Int = Std.int(ms_per_quarter_note / pulses_per_quarter_note);

		trace('tick length $ms_per_pulse buffer_length $buffer_length');

		var schedule = new ScheduledCycle<MidiNote>();
		var schedule_note_off = new ScheduledCycle<MidiMessage>();
		
		schedule.push(0, {
			velocity: 60,
			note: 46,
			length: pulses_per_quarter_note
		});

		schedule.push(64, {
			velocity: 60,
			note: 43,
			length: pulses_per_quarter_note * 0.25
		});

		var counter = 0;
		var pulse = 0;
		var quarter_noteTimer = new Timer(ms_per_pulse);

		quarter_noteTimer.run = function() {
			// if there is note offs in schedule then send it
			var next_off = schedule_note_off.next();
			if (next_off != null && next_off.pulse == pulse) {
				midiOut.sendMessage(next_off.event);
				schedule_note_off.advance();
				// trace('event off at $pulse');
			}

			// get next note in schedule
			var next = schedule.next();

			if (next.pulse == pulse) {
				// trace('event at $pulse');

				// send next note
				midiOut.sendMessage(next.event.toNoteOnMessage());

				// buffer a note off for the next note
				var off_at_pulse = Std.int(pulse + next.event.length);//Std.int(next.event.length * ppqn);
				schedule_note_off.push(off_at_pulse, next.event.toNoteOffMessage());

				// advance schedule
				schedule.advance();
			}
			pulse = counter % buffer_length;
			counter++;
			// trace('$pulse');
		};
	}

	static function main() {
		trace(MidiOut.getApis());
		var midiOut = new MidiOut(grig.midi.Api.Unspecified);
		midiOut.getPorts().handle(function(outcome) {
			switch outcome {
				case Success(ports):
					trace(ports);
					midiOut.openPort(1, 'NTS-1 digital kit').handle(function(midiOutcome) {
						switch midiOutcome {
							case Success(_):
								mainLoop(midiOut);
							case Failure(error):
								trace(error);
						}
					});
				case Failure(error):
					trace(error);
			}
		});
	}
}

@:structInit
class MidiNote {
	public var note:Int;
	public var velocity:Int;
	public var length:Float;
}

class MidiNoteExtensions {
	static var status_note_on = 144;
	static var status_note_off = 128;

	public static function toNoteOnMessage(n:MidiNote):MidiMessage {
		return MidiMessage.ofArray([status_note_on, n.note, n.velocity]);
	}

	public static function toNoteOffMessage(n:MidiNote):MidiMessage {
		return MidiMessage.ofArray([status_note_off, n.note, 0]);
	}
}

class Cycle<T> {
	var steps:Array<T>;
	var counter:Int = 0;
	var index:Int = 0;

	public function new(length:Int, builder:Int->T) {
		steps = [for (n in 0...length) builder(n)];
	}

	public function next():T {
		// trace('Cycle index $index counter $counter length ${steps.length}');
		index = counter % steps.length;
		counter++;
		return steps[index];
	}

	public function advance() {
		counter++;
	}
}

@:structInit
class Scheduled<T> {
	public var pulse:Int;
	public var event:T;
}

class ScheduledCycle<T> {
	var steps:Array<Scheduled<T>>;
	var counter:Int;
	var index:Int;

	public function new() {
		steps = [];
		counter = 0;
		index = 0;
	}

	public function push(pulse:Int, event:T) {
		steps.push({
			pulse: pulse,
			event: event
		});
	}

	public function next():Scheduled<T> {
		// trace('Cycle index $index counter $counter length ${steps.length}');
		if (steps.length == 0)
			return null;

		index = counter % steps.length;
		return steps[index];
	}

	public function advance() {
		counter++;
	}
}
