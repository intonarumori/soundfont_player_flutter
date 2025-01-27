import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:soundfont_player/chord_event.dart';
import 'package:soundfont_player/soundfont_player.dart';
import 'package:soundfont_player_example/chord_sequencer.dart';
import 'package:soundfont_player_example/sliding_button.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MyAppState();
}

class _MyAppState extends State<MainPage> {
  String _platformVersion = 'Unknown';
  bool _isRepeating = false;
  bool _isPlaying = false;
  double _playheadPosition = 0.0;
  Timer? _timer;
  int _playingNote = -1;

  List<ChordItem> chords = List.generate(
    8,
    (index) => ChordItem(
      enabled: false,
      chord: ChordEvent(
        root: 48,
        notes: [0, 3, 7, 10, 14],
        velocity: 100,
        timestamp: index.toDouble() + ((index % 2 == 1) ? 0.5 : 0.0),
        duration: 0.1,
      ),
    ),
  ).toList();
  final _soundfontPlayerPlugin = SoundfontPlayer();

  @override
  void initState() {
    super.initState();
    initPlatformState();

    loadFont();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(milliseconds: 30), (timer) async {
      final playheadPosition = await _soundfontPlayerPlugin.getPlayheadPosition();
      setState(() {
        _playheadPosition = playheadPosition;
      });
    });
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

  void _updatePlaying(int note) {
    if (_playingNote == note) return;
    if (note != -1) {
      _soundfontPlayerPlugin.playNote(note, velocity: 127);
    } else {
      _soundfontPlayerPlugin.stopNote(_playingNote);
    }
    _playingNote = note;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SlidingButton(
              tapStarted: (value) {
                _updatePlaying(40 + (value * 20).toInt());
              },
              tapUpdated: (value) {
                _updatePlaying(40 + (value * 20).toInt());
              },
              tapEnded: (value) {
                _updatePlaying(-1);
              },
            ),
            // GestureDetector(
            //   onTapDown: (details) => _soundfontPlayerPlugin.playNote(60, velocity: 127),
            //   onTapUp: (details) => _soundfontPlayerPlugin.stopNote(60),
            //   onTapCancel: () => _soundfontPlayerPlugin.stopNote(60),
            //   child:
            // ),
            FilledButton(
                onPressed: () {
                  setState(() {
                    _isRepeating = !_isRepeating;
                    _soundfontPlayerPlugin.setRepeating(_isRepeating);
                  });
                },
                child: Text(_isRepeating ? 'Repeat' : 'No Repeat')),
          ],
        ),
        FilledButton(
            onPressed: () async {
              _isPlaying = await _soundfontPlayerPlugin.isPlaying();
              if (_isPlaying) {
                _soundfontPlayerPlugin.stopSequencer();
              } else {
                _soundfontPlayerPlugin.startSequencer();
              }
              _isPlaying = await _soundfontPlayerPlugin.isPlaying();
              setState(() {});
            },
            child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow)),
        LinearProgressIndicator(value: (_playheadPosition % 8) / 8),
        const SizedBox(height: 10),
        SizedBox(
          height: 200,
          child: ChordSequencer(
            chords: chords.toList(),
            onChordsChanged: (chords) {
              for (int i = 0; i < chords.length; i++) {
                final oldChord = this.chords[i];
                final newChord = chords[i];
                if (oldChord == newChord) continue;
                if (newChord.enabled) {
                  _soundfontPlayerPlugin.addChord(newChord.chord);
                } else {
                  _soundfontPlayerPlugin.removeChord(newChord.chord);
                }
              }
              setState(() {
                this.chords = chords;
              });
            },
          ),
        ),
        Center(
          child: Text('Running on: $_platformVersion\n'),
        ),
      ],
    );
  }
}
