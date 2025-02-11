import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:soundfont_player/chord_event.dart';
import 'package:soundfont_player/chord_pattern.dart';
import 'package:soundfont_player/rhythm_event.dart';

import 'soundfont_player_platform_interface.dart';

/// An implementation of [SoundfontPlayerPlatform] that uses method channels.
class MethodChannelSoundfontPlayer extends SoundfontPlayerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('soundfont_player');

  final eventChannel = EventChannel('soundfont_player_events');

  @override
  Stream<dynamic> get events => eventChannel.receiveBroadcastStream();

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<void> playNote(int note, {required int velocity}) async {
    await methodChannel.invokeMethod<String>('playNote', <String, dynamic>{
      'note': note,
      'velocity': velocity,
    });
  }

  @override
  Future<void> stopNote(int note) async {
    await methodChannel.invokeMethod<String>('stopNote', <String, dynamic>{
      'note': note,
    });
  }

  @override
  Future<void> loadFont(String fontPath) async {
    await methodChannel.invokeMethod<String>('loadFont', <String, dynamic>{
      'path': fontPath,
    });
  }

  @override
  Future<void> loadDrums(String fontPath) async {
    await methodChannel.invokeMethod<String>('loadDrums', <String, dynamic>{
      'path': fontPath,
    });
  }

  @override
  Future<void> startSequencer() async {
    await methodChannel.invokeMethod<String>('startSequencer');
  }

  @override
  Future<void> stopSequencer() async {
    await methodChannel.invokeMethod<String>('stopSequencer');
  }

  @override
  Future<bool> isPlaying() async {
    final result = await methodChannel.invokeMethod<bool>('getIsPlaying');
    return result ?? false;
  }

  @override
  Future<void> setRepeating(bool value) async {
    await methodChannel.invokeMethod<void>('setRepeating', value);
  }

  @override
  Future<double> getPlayheadPosition() async {
    final result = await methodChannel.invokeMethod<double>('getPlayheadPosition');
    return result ?? 0.0;
  }

  @override
  Future<void> addChord(ChordEvent chord) async {
    await methodChannel.invokeMethod<String>('addChord', chord.asMap());
  }

  @override
  Future<void> removeChord(ChordEvent chord) async {
    await methodChannel.invokeMethod<String>('removeChord', chord.asMap());
  }

  @override
  Future<void> addRhythmEvent(RhythmEvent event) async {
    await methodChannel.invokeMethod<void>('addRhythmEvent', event.asMap());
  }

  @override
  Future<void> removeRhythmEvent(RhythmEvent event) async {
    await methodChannel.invokeMethod<void>('removeRhythmEvent', event.asMap());
  }

  @override
  Future<void> setChordPattern(ChordPattern pattern) async {
    await methodChannel.invokeMethod<void>('setChordPattern', pattern.asMap());
  }

  @override
  Future<void> setDrumTrack(int sequence, int track, List<RhythmEvent> events) async {
    final map = {
      "sequence": sequence,
      "track": track,
      "events": events.map((e) => e.asMap()).toList(),
    };
    await methodChannel.invokeMethod<void>('setDrumTrack', map);
  }

  @override
  Future<List<RhythmEvent>> getDrumTrack(int sequence, int track) async {
    final result = await methodChannel.invokeMethod<Map>('getDrumTrack', {
      "sequence": sequence,
      "track": track,
    });
    final dict = result!.cast<String, dynamic>();
    final eventList = dict["events"] as List<dynamic>;
    final events = eventList.map((e) => RhythmEvent.fromMap(e.cast<String, dynamic>())).toList();
    return events;
  }

  @override
  Future<void> setTempo(double tempo) async {
    await methodChannel.invokeMethod<void>('setTempo', tempo);
  }
}
