import 'package:flutter_test/flutter_test.dart';
import 'package:soundfont_player/soundfont_player.dart';
import 'package:soundfont_player/soundfont_player_platform_interface.dart';
import 'package:soundfont_player/soundfont_player_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockSoundfontPlayerPlatform
    with MockPlatformInterfaceMixin
    implements SoundfontPlayerPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final SoundfontPlayerPlatform initialPlatform = SoundfontPlayerPlatform.instance;

  test('$MethodChannelSoundfontPlayer is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelSoundfontPlayer>());
  });

  test('getPlatformVersion', () async {
    SoundfontPlayer soundfontPlayerPlugin = SoundfontPlayer();
    MockSoundfontPlayerPlatform fakePlatform = MockSoundfontPlayerPlatform();
    SoundfontPlayerPlatform.instance = fakePlatform;

    expect(await soundfontPlayerPlugin.getPlatformVersion(), '42');
  });
}
