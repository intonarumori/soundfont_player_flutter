

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

@objc class ChordPattern: NSObject {
    let steps: [ChordPatternStep]
    
    init(steps: [ChordPatternStep]) {
        self.steps = steps
    }
    
    static func fromMap(_ map: [String: Any]) -> ChordPattern {
        let list = map["steps"] as! [[String: Any]]
        return ChordPattern(
            steps: list.map({ ChordPatternStep.fromMap($0) })
        )
    }
}

@objc class ChordPatternStep: NSObject {
    let notes: [ChordPatternStepNote]

    init(notes: [ChordPatternStepNote]) {
        self.notes = notes
    }
    
    static func fromMap(_ map: [String: Any]) -> ChordPatternStep {
        return ChordPatternStep(
            notes: (map["notes"] as! [[String: Any]]).map({ ChordPatternStepNote.fromMap($0) })
        )
    }
}

@objc class ChordPatternStepNote: NSObject {
    let type: Int
    let note: Int
    
    init(type: Int, note: Int) {
        self.type = type
        self.note = note
    }
    
    static func fromMap(_ map: [String: Any]) -> ChordPatternStepNote {
        return ChordPatternStepNote(
            type: map["type"] as! Int,
            note: map["note"] as! Int
        )
    }
}

// MARK: -

class SoundfontAudioPlayer {
    private var audioEngine: AVAudioEngine
    //private var matrixMixer: AVAudioUnit?
    
    private var keyboardSequencer: AVAudioUnit?
    private var keyboardSampler: AVAudioUnitSampler

    //private var drumSequencer: AVAudioSequencer
    private var drumSequencer: AVAudioUnit?
    private var drumSampler: AVAudioUnitSampler

    private var midiIn = MidiSource()

    private var repeating: Bool = false

    var chords: [ChordEvent] = []
    
    var rhythm: [RhythmEvent] = []
    
    var pattern: ChordPattern = ChordPattern(steps: [])
    
    init() {
        audioEngine = AVAudioEngine()
        
        keyboardSampler = AVAudioUnitSampler()
        audioEngine.attach(keyboardSampler)
        audioEngine.connect(keyboardSampler, to: audioEngine.mainMixerNode, format: nil)
        
        keyboardSampler.volume = 0.5

        drumSampler = AVAudioUnitSampler()
        audioEngine.attach(drumSampler)
        audioEngine.connect(drumSampler, to: audioEngine.mainMixerNode, format: nil)

        let newTempo: Double = 120.0
        let rate: Double = newTempo / 60.0
        
//        drumSequencer = AVAudioSequencer(audioEngine: audioEngine)
//        if #available(iOS 16.0, macOS 13.0, *) {
//            let track = drumSequencer.createAndAppendTrack()
//            track.lengthInBeats = 8
//            track.isLoopingEnabled = true
//            track.numberOfLoops = -1
//            track.destinationAudioUnit = drumSampler
//            
//            // Define a basic drum beat (kick and snare)
//           let beats: [(MIDINoteNumber, MusicTimeStamp)] = [
//               (36, 0.0),
//               (36, 2.0),
//               (36, 4.0),
//               (36, 6.0),
//               // sd
//               (37, 2.0),
//               (37, 6.0),
//               // HH
//               (39, 0.0),
//               (39, 1.0),
//               (39, 2.0),
//               (39, 3.0),
//               (39, 4.0),
//               (39, 5.0),
//               (39, 6.0),
//               (40, 7.0),
//           ]
//           
//           for (note, time) in beats {
//               let duration: MusicTimeStamp = 0.2
//               let velocity: MIDIVelocity = 100
//               track.addEvent(AVMIDINoteEvent(channel: 0, key: UInt32(note), velocity: UInt32(velocity), duration: duration), at: time)
//           }
//        }
//        drumSequencer.rate = Float(rate)
//        drumSequencer.prepareToPlay()
        //

        instantiateSequencer()
        instantiateDrumSequencer()
        // instantiateMatrixMixer()
        
        startEngineIfReady()
                
        midiIn.callback = self.handleEvent
    }
    
    private func instantiateDrumSequencer() {
        let mySubType : OSType = 1
        
        let componentDescription = AudioComponentDescription(
            componentType: kAudioUnitType_MIDIProcessor,
            componentSubType:  mySubType,
            componentManufacturer: 0x666f6f20, // 4 hex byte OSType 'foo '
            componentFlags:        AudioComponentFlags.sandboxSafe.rawValue,
            componentFlagsMask:    0
        )

        AUAudioUnit.registerSubclass(
            DrumSequencerAudioUnit.self,
            as: componentDescription,
            name: "DrumSequencer",   // my AUAudioUnit subclass
            version:   1
        )

        AVAudioUnit.instantiate(
            with: componentDescription,
            options: .init(rawValue: 0),
            completionHandler: { [weak self] (audiounit: AVAudioUnit?, error: Error?) in
                guard let self else { return }
                
                audioEngine.attach(audiounit!)
                drumSequencer = audiounit!
                if #available(iOS 16, macOS 13, *) {
                    audioEngine.connectMIDI(audiounit!, to: self.drumSampler, format: nil, eventListBlock: nil)
                } else {
                    audioEngine.connectMIDI(audiounit!, to: self.drumSampler, format: nil)
                }
                startEngineIfReady()
            }
        )
    }
    
    private func instantiateSequencer() {
        let myUnitType = kAudioUnitType_MIDIProcessor
        let mySubType : OSType = 1
        
        let compDesc = AudioComponentDescription(
            componentType: myUnitType,
            componentSubType:  mySubType,
            componentManufacturer: 0x665f6f20, // 4 hex byte OSType 'foo '
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
            options: .init(rawValue: 0),
            completionHandler: { [weak self] (audiounit: AVAudioUnit?, error: Error?) in
                guard let self else { return }
                
                audioEngine.attach(audiounit!)
                
                keyboardSequencer = audiounit!
                
//                audiounit?.auAudioUnit.musicalContextBlock = { [weak self] _, _, _, _, _, _ in
//                    return false
//                }
//                audiounit?.auAudioUnit.midiOutputEventBlock = { [weak self] _, _, _, _ in
//                    return noErr
//                }
//                audiounit?.auAudioUnit.transportStateBlock = { [weak self] _, _, _, _ in
//                    return false
//                }
                if #available(iOS 16, macOS 13, *) {
                    audioEngine.connectMIDI(audiounit!, to: self.keyboardSampler, format: nil, eventListBlock: nil)
                } else {
                    audioEngine.connectMIDI(audiounit!, to: self.keyboardSampler, format: nil)
                }

                startEngineIfReady()
            }
        )
    }
    
    private func startEngineIfReady() {
        guard let _ = keyboardSequencer, let _ = drumSequencer else {
            return
        }
        do {
            try audioEngine.start()
        } catch {
            print("could not start engine")
        }
    }
    
    
//    private func instantiateMatrixMixer() {
//        
//        let kAudioComponentFlag_SandboxSafe:UInt32 = 2
//        let mixerDesc = AudioComponentDescription(
//            componentType: kAudioUnitType_Mixer,
//            componentSubType: kAudioUnitSubType_MatrixMixer,
//            componentManufacturer: kAudioUnitManufacturer_Apple,
//            componentFlags: kAudioComponentFlag_SandboxSafe,
//            componentFlagsMask: 0
//        )
//        AVAudioUnit.instantiate(with: mixerDesc) { [weak self] avAudioUnit, error in
//            guard let self, let avAudioUnit else {
//                return
//            }
//            
//            self.matrixMixer = avAudioUnit
//            
//            audioEngine.attach(avAudioUnit)
//            
//            AudioUnitSetParameter(matrixMixer!.audioUnit, kMatrixMixerParam_Volume, kAudioUnitScope_Global, 0xFFFFFFFF, 1.0, 0);
//
//            audioEngine.connect(keyboardSampler, to: avAudioUnit, format: nil)
//            audioEngine.connect(drumSampler, to: avAudioUnit, format: nil)
//
//            audioEngine.connect(avAudioUnit, to: audioEngine.mainMixerNode, format: nil)
//            
//            startEngineIfReady()
//            
//            AudioUnitSetParameter(matrixMixer!.audioUnit, kMatrixMixerParam_Volume, kAudioUnitScope_Global, 0xFFFFFFFF, 1.0, 0);
//            AudioUnitSetParameter(matrixMixer!.audioUnit, kMatrixMixerParam_Volume, kAudioUnitScope_Output, 0, 1.0, 0);
//            AudioUnitSetParameter(matrixMixer!.audioUnit, kMatrixMixerParam_Volume, kAudioUnitScope_Output, 1, 1.0, 0);
//            AudioUnitSetParameter(matrixMixer!.audioUnit, kMatrixMixerParam_Volume, kAudioUnitScope_Input, 0, 1.0, 0);
//            AudioUnitSetParameter(matrixMixer!.audioUnit, kMatrixMixerParam_Volume, kAudioUnitScope_Input, 1, 1.0, 0);
//            var i : UInt32 = 0
//            var j : UInt32 = 0
//            let crossPoint : UInt32  = (i << 16) | (j & 0x0000FFFF);
//            AudioUnitSetParameter(matrixMixer!.audioUnit, kMatrixMixerParam_Volume, kAudioUnitScope_Global, crossPoint, 1.0, 0);
//            i = 1
//            j = 1
//            let crossPoint2 : UInt32  = (i << 16) | (j & 0x0000FFFF);
//            AudioUnitSetParameter(matrixMixer!.audioUnit, kMatrixMixerParam_Volume, kAudioUnitScope_Global, crossPoint2, 1.0, 0);
//        }
//    }
    
    func handleEvent(_ data: [UInt8]) {
        switch (data[0] & 0xF0) {
        case 0x90:
            if (data[2] > 0) {
                keyboardSampler.startNote(data[1], withVelocity: data[2], onChannel: 0)
            }
            else {
                keyboardSampler.stopNote(data[1], onChannel: 0)
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
            try keyboardSampler.loadSoundBankInstrument(at: soundfontURL, program: 0, bankMSB: 0x79, bankLSB: 0x00)
        } catch {
            print("Error loading soundfont: \(error.localizedDescription)")
        }
    }
    
    func loadDrumSoundfont(path: String) {
        guard FileManager().fileExists(atPath: path) else {
            return
        }
        let soundfontURL = URL(fileURLWithPath: path)
        do {
            try drumSampler.loadSoundBankInstrument(at: soundfontURL, program: 0, bankMSB: 0x78, bankLSB: 0x00)
        } catch {
            print("Error loading soundfont: \(error.localizedDescription)")
        }
    }
    
    func setTempo(_ value: Double) {
        sequencerUnit?.setTempo(value)
        drumSequencerUnit?.setTempo(value)
    }
    
    func setDrumTrack(_ data: [String: Any]) {
        drumSequencerUnit?.setTrack(data)
    }
    
    func getDrumTrack(sequenceIndex: Int, trackIndex: Int) -> [AnyHashable: Any] {
        return drumSequencerUnit!.getTrack(sequenceIndex, trackIndex: trackIndex)
    }
    
    func startSequencer() {
        sequencerUnit?.setPlaying(true);
        drumSequencerUnit?.setPlaying(true);
    }
    
    func stopSequencer() {
        sequencerUnit?.setPlaying(false);
        drumSequencerUnit?.setPlaying(false);
    }
    
    var sequencerUnit: SequencerAudioUnit? {
        keyboardSequencer?.auAudioUnit as? SequencerAudioUnit
    }
    
    var drumSequencerUnit: DrumSequencerAudioUnit? {
         drumSequencer?.auAudioUnit as? DrumSequencerAudioUnit
    }
    
    var isPlaying: Bool {
        sequencerUnit?.getPlaying() ?? false
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
            keyboardSampler.startNote(note, withVelocity: velocity, onChannel: 0)
        }
    }

    func stop(note: UInt8) {
        if (repeating) {
            sequencerUnit?.releaseNote(note);
        } else {
            keyboardSampler.stopNote(note, onChannel: 0)
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
        
//        for note in chord.notes {
//            musicSequencer.tracks[0].add(
//                noteNumber: UInt8(chord.root + note),
//                velocity: UInt8(100),
//                position: Duration(beats: chord.timestamp),
//                duration: Duration(beats:chord.duration)
//            )
//        }
        
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
            
            //musicSequencer.tracks[0].clearRange(start: Duration(beats:chord.timestamp), duration: Duration(beats: chord.duration))
            
//            let track = sequencer.tracks[0]
//            if #available(iOS 16.0, *) {
//                track.clearEvents(in: AVBeatRange(start: chord.timestamp, length: chord.duration))
//            }
        }
    }
    
    func setChordPattern(_ pattern: ChordPattern) {
        self.pattern = pattern
        
        for i in 0..<16 {
            for j in 0..<8 {
                if (i < pattern.steps.count && j < pattern.steps[i].notes.count) {
                    let note = pattern.steps[i].notes[j].note;
                    let type = pattern.steps[i].notes[j].type;
                    sequencerUnit?.setChordPatternNote(Int32(note), type: Int32(type), step: Int32(i), note: Int32(j))
                } else {
                    sequencerUnit?.setChordPatternNote(0, type: 127, step: Int32(i), note: Int32(j))
                }
                
            }
        }
    }
}
