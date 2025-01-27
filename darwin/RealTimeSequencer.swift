
import AVFoundation
import AudioUnit

public class RealTimeSequencer {

    var noteBlock: AUScheduleMIDIEventBlock?
    var frameIndex: Int = 0
    
    init() {}
    
    func addToEngine(_ engine: AVAudioEngine) {

        let sampleRate: Double = 44100
        let channels: AVAudioChannelCount = 2
        let audioFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels)!

        // Create a generator node (AVAudioSourceNode)
        let sourceNode = AVAudioSourceNode { [weak self] isSilence, audioTime, frameCount, audioBufferList -> OSStatus in

            let frameIndex = self?.frameIndex ?? 1
            
            if let noteBlock = self?.noteBlock, frameIndex % 20 == 0  {
                let cbytes = UnsafeMutablePointer<UInt8>.allocate(capacity: 3)
                cbytes[0] = 0x90 // status
                cbytes[1] = 60 // note
                cbytes[2] = 100 // velocity
                noteBlock(AUEventSampleTimeImmediate, 0, 3, cbytes)
            }
            
            self?.frameIndex += 1

            // Access the audio buffer list to write audio samples
            // let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

            // Generate a sine wave
//            let frequency: Float = 440.0 // Frequency in Hz (e.g., A4 note)
//            let amplitude: Float = 0.25 // Amplitude of the sine wave
//            var phase: Float = 0.0 // Phase accumulator
//            let phaseIncrement = 2.0 * Float.pi * frequency / Float(sampleRate)
//
//            // Fill each channel with generated audio
//            for frame in 0..<Int(frameCount) {
//                let sampleValue = sin(phase) * amplitude
//                phase += phaseIncrement
//                if phase > 2.0 * Float.pi {
//                    phase -= 2.0 * Float.pi
//                }
//
//                for buffer in ablPointer {
//                    let bufferPointer = buffer.mData!.assumingMemoryBound(to: Float.self)
//                    bufferPointer[frame] = sampleValue
//                }
//            }

            return noErr
        }
        // Attach the source node to the engine
        engine.attach(sourceNode)

        // Connect the source node to the main mixer
        engine.connect(sourceNode, to: engine.mainMixerNode, format: audioFormat)
    }
}
