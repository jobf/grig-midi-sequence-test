package;

import grig.midi.MidiMessage;
import grig.midi.MidiOut;
import haxe.Timer;
import tink.core.Future;

using Main.MidiNoteExtensions;

class Main {
	private static function mainLoop(midiOut:MidiOut) {
		var numBeats = 8;

		var noteOns:Array<MidiNote> = [
			for (n in 0...numBeats)
				{
					velocity: 64,
					note: 50 + n,
					length: 1
				}
		];
		var noteOffs:Array<MidiMessage> = [];
		
		var counter:Int = 0;
		var beatIndex:Int = 0;
		var beatTimer = new Timer(500);
		beatTimer.run = function() {
			if (noteOffs.length > 0) {
				midiOut.sendMessage(noteOffs.shift());
			}
			beatIndex = counter % numBeats;
			var next_note_on = noteOns[beatIndex];
			noteOffs.push(next_note_on.toNoteOffMessage());
			midiOut.sendMessage(next_note_on.toNoteOnMessage());
			trace('beatIndex $beatIndex counter $counter ${noteOns.length}');
			counter++;
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