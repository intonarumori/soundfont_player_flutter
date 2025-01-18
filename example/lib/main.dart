import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:soundfont_player/soundfont_player.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';

  final _soundfontPlayerPlugin = SoundfontPlayer();

  @override
  void initState() {
    super.initState();
    initPlatformState();

    loadFont();
  }

  Future<void> loadFont() async {
    final filename = "FreeFont.sf2";
    final font = await rootBundle.load('assets/$filename');
    final documents = await getApplicationDocumentsDirectory();
    final path = '${documents.path}/$filename';
    final file = File(path)..writeAsBytesSync(font.buffer.asUint8List());

    await _soundfontPlayerPlugin.loadFont(file.path);
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    try {
      platformVersion =
          await _soundfontPlayerPlugin.getPlatformVersion() ?? 'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Column(
          children: [
            GestureDetector(
              onTapDown: (details) => _soundfontPlayerPlugin.playNote(60, velocity: 127),
              onTapUp: (details) => _soundfontPlayerPlugin.stopNote(60),
              onTapCancel: () => _soundfontPlayerPlugin.stopNote(60),
              child: Container(
                width: 50,
                height: 50,
                color: Colors.red,
              ),
            ),
            Center(
              child: Text('Running on: $_platformVersion\n'),
            ),
          ],
        ),
      ),
    );
  }
}
