import 'soundfont_player_platform_interface.dart';

class SoundfontPlayer {
  Future<String?> getPlatformVersion() {
    return SoundfontPlayerPlatform.instance.getPlatformVersion();
  }

  Future<void> playNote(int note, {required int velocity}) {
    return SoundfontPlayerPlatform.instance.playNote(note, velocity: velocity);
  }

  Future<void> stopNote(int note) {
    return SoundfontPlayerPlatform.instance.stopNote(note);
  }

  Future<void> loadFont(String fontPath) {
    return SoundfontPlayerPlatform.instance.loadFont(fontPath);
  }
}
