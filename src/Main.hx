package;

import grig.midi.MidiMessage;
import grig.midi.MidiOut;
import haxe.Timer;
import tink.core.Future;

using Main.MidiNoteExtensions;

class Main {
	private static function mainLoop(midiOut:MidiOut) {
		var numBeats = 8;

		// set a note to play on every beat
		var Cycle = new Cycle<MidiNote>(numBeats, i -> {
			note: 46 + i,
			velocity: 60,
			length: 1
		});

		// buffer for note off messages
		var buffer_off:Array<MidiMessage> = [];

		// loop timer
		var beatTimer = new Timer(320);
		beatTimer.run = function() {
			// if there is note offs in the buffer then send it
			if (buffer_off.length > 0) {
				midiOut.sendMessage(buffer_off.shift());
			}

			// get next note in Cycle
			var next = Cycle.next();

			// send next note
			midiOut.sendMessage(next.toNoteOnMessage());
			
			// buffer a note off for the next note
			buffer_off.push(next.toNoteOffMessage());
		}
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
	public var length:Int;
}

class MidiNoteExtensions{
	static var status_note_on = 144;
	static var status_note_off = 128;
	
	public static function toNoteOnMessage(n:MidiNote):MidiMessage{
		return MidiMessage.ofArray([status_note_on, n.note, n.velocity]);
	}
	
	public static function toNoteOffMessage(n:MidiNote):MidiMessage{
		return MidiMessage.ofArray([status_note_off, n.note, n.velocity]);
	}
}

class Cycle<T>{
	var steps:Array<T>;
	var counter:Int = 0;
	var index:Int = 0;

	public function new(length:Int, builder:Int->T){
		steps = [for (n in 0...length) builder(n)];
	}

	public function next():T{
		// trace('Cycle index $index counter $counter length ${steps.length}');
		index = counter % steps.length;
		counter++;
		return steps[index];
	}

}