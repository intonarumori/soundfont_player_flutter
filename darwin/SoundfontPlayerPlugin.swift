
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
        //soundfontAudioPlayer = SoundfontAudioPlayer()
        audioPlayer = AudioPlayer()
    }

    //private var soundfontAudioPlayer: SoundfontAudioPlayer!
    private var audioPlayer: AudioPlayer!
    
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
            audioPlayer.playNote(UInt8(note), velocity: UInt8(velocity))
            result(nil)
        case "stopNote":
            let args = call.arguments as? [String: Any] ?? [:]
            let note = args["note"] as! Int
            audioPlayer.stopNote(UInt8(note))
            result(nil)
        case "loadFont":
            let args = call.arguments as? [String: Any] ?? [:]
            let path = args["path"] as! String
            audioPlayer.loadSoundfont(path)
            result(nil)
        case "loadDrums":
            let args = call.arguments as? [String: Any] ?? [:]
            let path = args["path"] as! String
            audioPlayer.loadDrumSoundfont(path)
            result(nil)
        case "startSequencer":
            audioPlayer.startSequencer()
            result(nil)
        case "stopSequencer":
            audioPlayer.stopSequencer()
            result(nil)
        case "getIsPlaying":
            result(audioPlayer.isPlaying())
        case "setRepeating":
            audioPlayer.setRepeating(call.arguments as! Bool)
            result(nil)
//        case "addChord":
//            let args = call.arguments as? [String: Any] ?? [:]
//            let event = Chord2Event()
//            event.root = args["root"] as! Int
//            event.velocity = args["velocity"] as! Int
//            event.notes = (args["notes"] as! [Int]).map( { NSNumber(value: $0) })
//            event.duration = args["duration"] as! Double
//            event.timestamp = args["timestamp"] as! Double
//            audioPlayer.addChord(event)
//            result(nil)
//        case "removeChord":
//            let args = call.arguments as? [String: Any] ?? [:]
//            let event = Chord2Event()
//            event.root = args["root"] as! Int
//            event.velocity = args["velocity"] as! Int
//            event.notes = (args["notes"] as! [Int]).map( { NSNumber(value: $0) })
//            event.duration = args["duration"] as! Double
//            event.timestamp = args["timestamp"] as! Double
//            audioPlayer.removeChord(event)
//            result(nil)
        case "addRhythmEvent":
            let args = call.arguments as? [String: Any] ?? [:]
            let event = Rhythm2Event();
            event.note = args["note"] as! Int
            event.duration = args["duration"] as! Double
            event.timestamp = args["timestamp"] as! Double
            event.velocity = args["velocity"] as! Int
            audioPlayer.add(event)
            result(nil)
        case "removeRhythmEvent":
            let args = call.arguments as? [String: Any] ?? [:]
            let event = Rhythm2Event();
            event.note = args["note"] as! Int
            event.duration = args["duration"] as! Double
            event.timestamp = args["timestamp"] as! Double
            event.velocity = args["velocity"] as! Int
            audioPlayer.remove(event)
            result(nil)
        case "setChordPattern":
            let args = call.arguments as? [String: Any] ?? [:]
            audioPlayer.setChordPattern(args)
            result(nil)
        case "setDrumTrack":
            let args = call.arguments as? [String: Any] ?? [:]
            audioPlayer.setDrumTrack(args)
            result(nil)
        case "getDrumTrack":
            let args = call.arguments as? [String: Any] ?? [:]
            let sequenceIndex = args["sequence"] as! Int
            let trackIndex = args["track"] as! Int
            result(audioPlayer.getDrumTrack(sequenceIndex, track: trackIndex))
        case "getPlayheadPosition":
            result(audioPlayer.getPlayheadPosition())
        case "setTempo":
            //soundfontAudioPlayer.setTempo(call.arguments as! Double)
            result(nil)
        case "queueSequence":
            let args = call.arguments as! [String: Any]
            let index = args["index"] as! Int
            let followIndex = args["followIndex"] as! Int
            audioPlayer.queueSequence(index, follow: followIndex)
            result(nil)
        case "getCurrentSequence":
            result(audioPlayer.getCurrentDrumSequence())

        case "getQueuedSequence":
            result(audioPlayer.getQueuedDrumSequence())
        default:
          result(FlutterMethodNotImplemented)
        }
    }
}
