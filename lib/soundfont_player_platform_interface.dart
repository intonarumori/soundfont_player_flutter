import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:soundfont_player/chord_event.dart';
import 'package:soundfont_player/chord_pattern.dart';
import 'package:soundfont_player/rhythm_event.dart';

import 'soundfont_player_method_channel.dart';

abstract class SoundfontPlayerPlatform extends PlatformInterface {
  /// Constructs a SoundfontPlayerPlatform.
  SoundfontPlayerPlatform() : super(token: _token);

  static final Object _token = Object();

  static SoundfontPlayerPlatform _instance = MethodChannelSoundfontPlayer();

  /// The default instance of [SoundfontPlayerPlatform] to use.
  ///
  /// Defaults to [MethodChannelSoundfontPlayer].
  static SoundfontPlayerPlatform get instance => _instance;

  Stream<dynamic> get events => throw UnimplementedError('events getter has not been implemented.');

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [SoundfontPlayerPlatform] when
  /// they register themselves.
  static set instance(SoundfontPlayerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<void> playNote(int note, {required int velocity}) {
    throw UnimplementedError('playNote() has not been implemented.');
  }

  Future<void> stopNote(int note) {
    throw UnimplementedError('stopNote() has not been implemented.');
  }

  Future<void> loadFont(String fontPath) {
    throw UnimplementedError('loadFont() has not been implemented.');
  }

  Future<void> loadDrums(String fontPath) async {
    throw UnimplementedError('loadDrums() has not been implemented.');
  }

  Future<void> startSequencer() {
    throw UnimplementedError('startSequencer() has not been implemented.');
  }

  Future<void> stopSequencer() {
    throw UnimplementedError('stopSequencer() has not been implemented.');
  }

  Future<bool> isPlaying() {
    throw UnimplementedError('isPlaying() has not been implemented.');
  }

  Future<void> setRepeating(bool value) {
    throw UnimplementedError('setRepeating() has not been implemented.');
  }

  Future<double> getPlayheadPosition() {
    throw UnimplementedError('getPlayheadPosition() has not been implemented.');
  }

  Future<void> addChord(ChordEvent chord) {
    throw UnimplementedError('addChord() has not been implemented.');
  }

  Future<void> removeChord(ChordEvent chord) {
    throw UnimplementedError('removeChord() has not been implemented.');
  }

  Future<void> addRhythmEvent(RhythmEvent event) {
    throw UnimplementedError('addRhythmEvent() has not been implemented.');
  }

  Future<void> removeRhythmEvent(RhythmEvent event) {
    throw UnimplementedError('removeRhythmEvent() has not been implemented.');
  }

  Future<void> setChordPattern(ChordPattern pattern) {
    throw UnimplementedError('setChordPattern() has not been implemented.');
  }

  Future<void> setDrumTrack(int sequence, int track, List<RhythmEvent> events) {
    throw UnimplementedError('setDrumTrack() has not been implemented.');
  }

  Future<List<RhythmEvent>> getDrumTrack(int sequence, int track) {
    throw UnimplementedError('getDrumTrack() has not been implemented.');
  }

  Future<void> setTempo(double tempo) {
    throw UnimplementedError('setTempo() has not been implemented.');
  }

  Future<void> queueSequence(int index, int followIndex) {
    throw UnimplementedError('queueSequence() has not been implemented.');
  }

  Future<int> getCurrentSequence() {
    throw UnimplementedError('getCurrentSequence() has not been implemented.');
  }

  Future<int> getQueuedSequence() {
    throw UnimplementedError('getQueuedSequence() has not been implemented.');
  }
}
