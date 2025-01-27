import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:soundfont_player/chord_event.dart';

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
}
