import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'soundfont_player_platform_interface.dart';

/// An implementation of [SoundfontPlayerPlatform] that uses method channels.
class MethodChannelSoundfontPlayer extends SoundfontPlayerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('soundfont_player');

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
}
