

import Foundation
import AVFoundation
import AudioToolbox

class Chords {
    static let minor9 = [0,3,7,10,14]
    static let major9 = [0,4,7,11,14]
}

struct ChordEvent {
    let root: Int
    let notes: [Int]
    let velocity: Int
    let timestamp: Double
    let duration: Double
}

struct RhythmEvent {
    let note: UInt8
    let velocity: UInt8
    let timestamp: Double
    let duration: Double
}

class SoundfontAudioPlayer {
    private var audioEngine: AVAudioEngine
    private var sampler: AVAudioUnitSampler
    private var sequencer: AVAudioSequencer
    private var musicSequencer: AppleSequencer!
    private var realTimeSequencer: RealTimeSequencer!
    
    private var repeating: Bool = false
    
    private var midiNode: AVAudioUnit?

    private var midiIn = MidiSource()
    
    var chords: [ChordEvent] = []
    
    var rhythm: [RhythmEvent] = []
    
    init() {
        audioEngine = AVAudioEngine()
        sampler = AVAudioUnitSampler()
        audioEngine.attach(sampler)
        audioEngine.connect(sampler, to: audioEngine.mainMixerNode, format: nil)

        let newTempo: Double = 120.0
        let rate: Double = newTempo / 60.0
        
        sequencer = AVAudioSequencer(audioEngine: audioEngine)
        if #available(iOS 16.0, macOS 13.0, *) {
            let track = sequencer.createAndAppendTrack()
            track.lengthInBeats = 8
            track.isLoopingEnabled = true
            track.numberOfLoops = -1
        }
        sequencer.rate = Float(rate)
        sequencer.prepareToPlay()
        
        musicSequencer = AppleSequencer()
        musicSequencer.newTrack("Track 1")
        musicSequencer.setLength(Duration(beats: 8))
        musicSequencer.enableLooping()
        musicSequencer.setGlobalMIDIOutput(midiIn.endpoint)
        musicSequencer.setRate(rate)
        //musicSequencer.tracks[0].add(midiNoteData: MIDINoteData(noteNumber: 48, velocity: 100, channel: 0, duration: Duration(beats: 0.5), position: Duration(beats: 0.0)))
        
//        realTimeSequencer = RealTimeSequencer()
//        realTimeSequencer.addToEngine(audioEngine)
//        realTimeSequencer.noteBlock = sampler.auAudioUnit.scheduleMIDIEventBlock
        
        //
        
        let myUnitType = kAudioUnitType_MIDIProcessor
        let mySubType : OSType = 1
        
        let compDesc = AudioComponentDescription(
            componentType: myUnitType,
            componentSubType:  mySubType,
            componentManufacturer: 0x666f6f20, // 4 hex byte OSType 'foo '
            componentFlags:        AudioComponentFlags.sandboxSafe.rawValue,
            componentFlagsMask:    0
        )
    
        AUAudioUnit.registerSubclass(
            SequencerAudioUnit.self,
            as: compDesc,
            name: "Sequencer",   // my AUAudioUnit subclass
            version:   1
        )
               
               
        AVAudioUnit.instantiate(
            with: compDesc,
            options: .init(rawValue: 0)) { (audiounit: AVAudioUnit?, error: Error?) in
                
                self.audioEngine.attach(audiounit!)
                
                self.midiNode = audiounit!
                
//                audiounit?.auAudioUnit.musicalContextBlock = { [weak self] _, _, _, _, _, _ in
//                    return false
//                }
//                
//                audiounit?.auAudioUnit.midiOutputEventBlock = { [weak self] _, _, _, _ in
//                    return noErr
//                }
//                audiounit?.auAudioUnit.transportStateBlock = { [weak self] _, _, _, _ in
//                    return false
//                }

                //let outFormat = self.sampler.inputFormat(forBus: 0)
                
                self.audioEngine.connectMIDI(audiounit!, to: self.sampler, format: nil, block: { _, _, _, _ in
                    return noErr
                })

//                self.audioEngine.connect(
//                    audiounit!,
//                    to: self.sampler,
//                    format: nil
//                )
            }
                
        do {
            try audioEngine.start()
        } catch {
            print("Error starting audio engine: \(error.localizedDescription)")
        }
        
        midiIn.callback = self.handleEvent
    }
    
    func handleEvent(_ data: [UInt8]) {
        switch (data[0] & 0xF0) {
        case 0x90:
            if (data[2] > 0) {
                sampler.startNote(data[1], withVelocity: data[2], onChannel: 0)
            }
            else {
                sampler.stopNote(data[1], onChannel: 0)
            }
            break
        case 0x80:
            break
        default:
            break
        }
    }

    func loadSoundfont(path: String) {
        guard FileManager().fileExists(atPath: path) else {
            return
        }
        let soundfontURL = URL(fileURLWithPath: path)
        do {
            try sampler.loadSoundBankInstrument(at: soundfontURL, program: 0, bankMSB: 0x79, bankLSB: 0x00)
        } catch {
            print("Error loading soundfont: \(error.localizedDescription)")
        }
    }
    
    func startSequencer() {
        musicSequencer.play()
//        do {
//            try sequencer.start()
//        } catch {
//            print("Error starting the sequencer \(error.localizedDescription)")
//        }
    }
    
    func stopSequencer() {
        musicSequencer.stop()
        //sequencer.stop()
    }
    
    var sequencerUnit: SequencerAudioUnit? {
        return (midiNode?.auAudioUnit as? SequencerAudioUnit)
    }
    
    var isPlaying: Bool {
        musicSequencer.isPlaying
        //sequencer.isPlaying
    }
    
    func setRepeating(_ value: Bool) {
        repeating = value
        sequencerUnit?.setRepeating(value);
    }
    
    var playheadPosition: Double {
        sequencerUnit?.getPlayheadPosition() ?? 0.0
        
        //musicSequencer.rate > 0 ? musicSequencer.currentPosition.beats : 0.0
        //sequencer.currentPositionInBeats
    }

    func play(note: UInt8, velocity: UInt8) {
        if (repeating) {
            sequencerUnit?.pressNote(note);
        } else {
            sampler.startNote(note, withVelocity: velocity, onChannel: 0)
        }
    }

    func stop(note: UInt8) {
        if (repeating) {
            sequencerUnit?.releaseNote(note);
        } else {
            sampler.stopNote(note, onChannel: 0)
        }
    }
    
    func addRhythmEvent(_ event: RhythmEvent) {
        sequencerUnit?.add(MIDIEvent(timestamp: event.timestamp, status: 0x90, data1: event.note, data2: event.velocity));
        sequencerUnit?.add(MIDIEvent(timestamp: event.timestamp + event.duration, status: 0x80, data1: event.note, data2: 0));
    }
    
    func removeRhythmEvent(_ event: RhythmEvent) {
        sequencerUnit?.delete(MIDIEvent(timestamp: event.timestamp, status: 0x90, data1: event.note, data2: event.velocity));
        sequencerUnit?.delete(MIDIEvent(timestamp: event.timestamp + event.duration, status: 0x80, data1: event.note, data2: 0));
    }
    
    func addChord(_ chord: ChordEvent) {
        removeChord(chord)
        chords.append(chord)
        
        for note in chord.notes {
            musicSequencer.tracks[0].add(
                noteNumber: UInt8(chord.root + note),
                velocity: UInt8(100),
                position: Duration(beats: chord.timestamp),
                duration: Duration(beats:chord.duration)
            )
        }
        
//        if #available(iOS 16.0, *) {
//            let track = sequencer.tracks[0]
//            for note in chord.notes {
//                track.addEvent(
//                    AVMIDINoteEvent(
//                        channel: 0, key: UInt32(chord.root + note),
//                        velocity: UInt32(chord.velocity), duration: chord.duration
//                    ),
//                    at: Double(chord.timestamp)
//                )
//            }
//        }
    }
    
    func removeChord(_ chord: ChordEvent) {
        let foundChord = chords.firstIndex(where: { ch in
            return ch.timestamp == chord.timestamp && ch.duration == chord.duration
        })
        if let foundChord {
            chords.remove(at: foundChord)
            
            musicSequencer.tracks[0].clearRange(start: Duration(beats:chord.timestamp), duration: Duration(beats: chord.duration))
            
//            let track = sequencer.tracks[0]
//            if #available(iOS 16.0, *) {
//                track.clearEvents(in: AVBeatRange(start: chord.timestamp, length: chord.duration))
//            }
        }
    }
}
