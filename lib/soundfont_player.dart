import 'package:soundfont_player/chord_event.dart';
import 'package:soundfont_player/chord_pattern.dart';
import 'package:soundfont_player/rhythm_event.dart';

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

  Future<void> loadDrums(String fontPath) {
    return SoundfontPlayerPlatform.instance.loadDrums(fontPath);
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

  Future<void> addRhythmEvent(RhythmEvent event) {
    return SoundfontPlayerPlatform.instance.addRhythmEvent(event);
  }

  Future<void> removeRhythmEvent(RhythmEvent event) {
    return SoundfontPlayerPlatform.instance.removeRhythmEvent(event);
  }

  Future<void> setChordPattern(ChordPattern pattern) {
    return SoundfontPlayerPlatform.instance.setChordPattern(pattern);
  }
}
