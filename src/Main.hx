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
		
		var midiSchedule = new MidiSchedule(message -> {
			midiOut.sendMessage(message);
		});

		midiSchedule.schedule(0, {
			velocity: 60,
			note: 46,
			length: pulses_per_quarter_note
		});

		midiSchedule.schedule(64, {
			velocity: 60,
			note: 43,
			length: pulses_per_quarter_note * 0.25
		});


		var repeater = new PulseRepeat(ms_per_pulse, buffer_length, pulse -> {
			midiSchedule.next(pulse);
		});

		repeater.start();
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

class PulseRepeat {
	var tick:Int;
	var pulse:Int;
	var timer:Timer;
	var on_tick:Int->Void;
	var wrap_length:Int;

	public function new(period_ms:Int, wrap_length:Int, on_tick:(pulse:Int) -> Void) {
		tick = 0;
		pulse = 0;
		timer = new Timer(period_ms);
		this.wrap_length = wrap_length;
		this.on_tick = on_tick;
	}

	public function start() {
		timer.run = () -> {
			on_tick(pulse);
			pulse = tick % wrap_length;
			tick++;
		}
	}

	public function stop() {
		timer.stop();
	}
}

class MidiSchedule {
	var note_on:ScheduledCycle<MidiMessage>;
	var note_off:ScheduledCycle<MidiMessage>;
	var send_message:MidiMessage->Void;

	public function new(send_message:MidiMessage->Void) {
		note_on = new ScheduledCycle<MidiMessage>();
		note_off = new ScheduledCycle<MidiMessage>();
		this.send_message = send_message;
	}

	public function schedule(pulse:Int, note:MidiNote) {
		note_on.push(pulse, note.toNoteOnMessage());
		var off_at_pulse = Std.int(pulse + note.length);
		note_off.push(off_at_pulse, note.toNoteOffMessage());
	}

	public function next(pulse:Int){
		var next_on = note_on.next();
		if(pulse == next_on.pulse){
			send_message(next_on.event);
			note_on.advance();
		}

		var next_off = note_off.next();
		if(pulse == next_off.pulse){
			send_message(next_off.event);
			note_off.advance();
		}
	}
}
