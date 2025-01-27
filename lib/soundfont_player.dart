import 'package:soundfont_player/chord_event.dart';

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

  Future<void> startSequencer() {
    return SoundfontPlayerPlatform.instance.startSequencer();
  }

  Future<void> stopSequencer() {
    return SoundfontPlayerPlatform.instance.stopSequencer();
  }

  Future<bool> isPlaying() {
    return SoundfontPlayerPlatform.instance.isPlaying();
  }

  Future<void> setRepeating(bool value) {
    return SoundfontPlayerPlatform.instance.setRepeating(value);
  }

  Future<double> getPlayheadPosition() {
    return SoundfontPlayerPlatform.instance.getPlayheadPosition();
  }

  Future<void> addChord(ChordEvent chord) {
    return SoundfontPlayerPlatform.instance.addChord(chord);
  }

  Future<void> removeChord(ChordEvent chord) {
    return SoundfontPlayerPlatform.instance.removeChord(chord);
  }
}
