import Flutter
import UIKit

public class SoundfontPlayerPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "soundfont_player", binaryMessenger: registrar.messenger())
    let instance = SoundfontPlayerPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }
    
    override init() {
        super.init()        
        soundfontAudioPlayer = SoundfontAudioPlayer()
    }

  var soundfontAudioPlayer: SoundfontAudioPlayer!

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    case "playNote":
        let args = call.arguments as? [String: Any] ?? [:]
        let note = args["note"] as! Int
        let velocity = args["velocity"] as! Int
        print("playNote \(note) \(velocity)")
        soundfontAudioPlayer.play(note: UInt8(note), velocity: UInt8(velocity))
    case "stopNote":
        let args = call.arguments as? [String: Any] ?? [:]
        let note = args["note"] as! Int
        print("stopNote \(note)")
        soundfontAudioPlayer.stop(note: UInt8(note))
    case "loadFont":
        let args = call.arguments as? [String: Any] ?? [:]
        let path = args["path"] as! String
        soundfontAudioPlayer.loadSoundfont(path: path)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
