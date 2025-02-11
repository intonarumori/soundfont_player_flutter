
#if os(macOS)
import Cocoa
import FlutterMacOS
#else
import Flutter
import UIKit
#endif


public class SoundfontPlayerPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    public static func register(with registrar: FlutterPluginRegistrar) {
        #if os(macOS)
        let channel = FlutterMethodChannel(name: "soundfont_player", binaryMessenger: registrar.messenger)
        let eventChannel = FlutterEventChannel(name: "soundfont_player_events", binaryMessenger: registrar.messenger)
        #else
        let channel = FlutterMethodChannel(name: "soundfont_player", binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: "soundfont_player_events", binaryMessenger: registrar.messenger())
        #endif
        let instance = SoundfontPlayerPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance)
    }
    
    override init() {
        super.init()        
        soundfontAudioPlayer = SoundfontAudioPlayer()
    }

    private var soundfontAudioPlayer: SoundfontAudioPlayer!
    
    private var eventSink: FlutterEventSink?
    
    // MARK: -

    public func onListen(withArguments arguments: Any?,
                         eventSink: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = eventSink
        // TO send messages call `self.eventSink?(data)`
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
    
    // MARK: -
    
    private func getPlatformVersion() -> String {
        #if os(iOS)
        return "iOS " + UIDevice.current.systemVersion
        #elseif os(macOS)
        return "macOS " + ProcessInfo.processInfo.operatingSystemVersionString
        #else
        return "Unknown OS"
        #endif
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
          result(getPlatformVersion())
        case "playNote":
            let args = call.arguments as? [String: Any] ?? [:]
            let note = args["note"] as! Int
            let velocity = args["velocity"] as! Int
            soundfontAudioPlayer.play(note: UInt8(note), velocity: UInt8(velocity))
        case "stopNote":
            let args = call.arguments as? [String: Any] ?? [:]
            let note = args["note"] as! Int
            soundfontAudioPlayer.stop(note: UInt8(note))
        case "loadFont":
            let args = call.arguments as? [String: Any] ?? [:]
            let path = args["path"] as! String
            soundfontAudioPlayer.loadSoundfont(path: path)
        case "loadDrums":
            let args = call.arguments as? [String: Any] ?? [:]
            let path = args["path"] as! String
            soundfontAudioPlayer.loadDrumSoundfont(path: path)
        case "startSequencer":
            soundfontAudioPlayer.startSequencer()
        case "stopSequencer":
            soundfontAudioPlayer.stopSequencer()
        case "getIsPlaying":
            result(soundfontAudioPlayer.isPlaying)
        case "setRepeating":
            soundfontAudioPlayer.setRepeating(call.arguments as! Bool)
            break
        case "addChord":
            let args = call.arguments as? [String: Any] ?? [:]
            let notes = args["notes"] as! [Int]
            let root = args["root"] as! Int
            let duration = args["duration"] as! Double
            let timestamp = args["timestamp"] as! Double
            let velocity = args["velocity"] as! Int
            soundfontAudioPlayer.addChord(
                ChordEvent(root: root, notes:notes, velocity: velocity, timestamp: timestamp, duration: duration)
            )
        case "removeChord":
            let args = call.arguments as? [String: Any] ?? [:]
            let notes = args["notes"] as! [Int]
            let root = args["root"] as! Int
            let duration = args["duration"] as! Double
            let timestamp = args["timestamp"] as! Double
            let velocity = args["velocity"] as! Int
            soundfontAudioPlayer.removeChord(
                ChordEvent(root: root, notes:notes, velocity: velocity, timestamp: timestamp, duration: duration)
            )
        case "addRhythmEvent":
            let args = call.arguments as? [String: Any] ?? [:]
            let note = args["note"] as! Int
            let duration = args["duration"] as! Double
            let timestamp = args["timestamp"] as! Double
            let velocity = args["velocity"] as! Int
            soundfontAudioPlayer.addRhythmEvent(RhythmEvent(note: UInt8(note), velocity: UInt8(velocity), timestamp: timestamp, duration: duration))
            break
        case "removeRhythmEvent":
            let args = call.arguments as? [String: Any] ?? [:]
            let note = args["note"] as! Int
            let duration = args["duration"] as! Double
            let timestamp = args["timestamp"] as! Double
            let velocity = args["velocity"] as! Int
            soundfontAudioPlayer.removeRhythmEvent(RhythmEvent(note: UInt8(note), velocity: UInt8(velocity), timestamp: timestamp, duration: duration))
            break
            
        case "setChordPattern":
            let args = call.arguments as? [String: Any] ?? [:]
            let pattern = ChordPattern.fromMap(args)
            soundfontAudioPlayer.setChordPattern(pattern)
            break
            
        case "setDrumTrack":
            let args = call.arguments as? [String: Any] ?? [:]
            soundfontAudioPlayer.setDrumTrack(args)
            break
            
        case "getDrumTrack":
            let args = call.arguments as? [String: Any] ?? [:]
            let sequenceIndex = args["sequence"] as! Int
            let trackIndex = args["track"] as! Int
            result(soundfontAudioPlayer.getDrumTrack(sequenceIndex: sequenceIndex, trackIndex: trackIndex))

        case "getPlayheadPosition":
            result(soundfontAudioPlayer.playheadPosition)
        
        case "setTempo":
            soundfontAudioPlayer.setTempo(call.arguments as! Double)
            
        default:
          result(FlutterMethodNotImplemented)
        }
    }
}
