

import Foundation
import AVFoundation

class SoundfontAudioPlayer {
    private var audioEngine: AVAudioEngine
    private var sampler: AVAudioUnitSampler

    init() {
        audioEngine = AVAudioEngine()
        sampler = AVAudioUnitSampler()
        audioEngine.attach(sampler)
        audioEngine.connect(sampler, to: audioEngine.mainMixerNode, format: nil)
        
        do {
            try audioEngine.start()
        } catch {
            print("Error starting audio engine: \(error.localizedDescription)")
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

    func play(note: UInt8, velocity: UInt8) {
        sampler.startNote(note, withVelocity: velocity, onChannel: 0)
    }

    func stop(note: UInt8) {
        sampler.stopNote(note, onChannel: 0)
    }
}
