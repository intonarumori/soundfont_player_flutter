import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:soundfont_player/chord_pattern.dart';
import 'package:soundfont_player/rhythm_event.dart';
import 'package:soundfont_player/soundfont_player.dart';
import 'package:soundfont_player_example/grid_buttons.dart';
import 'package:soundfont_player_example/rhythm_sequencer.dart';

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

  final List<List<int>> _chords = [
    [60, 63, 67, 70],
    [60, 64, 67, 71],
    [60, 63, 67, 70].map((e) => e - 3).toList(),
    [60, 64, 67, 71].map((e) => e - 3).toList(),
    [60, 63, 67, 70].map((e) => e - 5).toList(),
    [60, 64, 67, 71].map((e) => e - 5).toList(),
    [60, 63, 67, 70].map((e) => e - 6).toList(),
    [60, 64, 67, 71].map((e) => e - 6).toList(),
    [60, 63, 67, 70].map((e) => e - 8).toList(),
    [60, 64, 67, 71].map((e) => e - 8).toList(),
    [60, 63, 67, 70].map((e) => e - 10).toList(),
    [60, 64, 67, 71].map((e) => e - 10).toList(),
    [60, 63, 67, 70].map((e) => e - 11).toList(),
    [60, 64, 67, 71].map((e) => e - 11).toList(),
    [60, 63, 67, 70].map((e) => e - 13).toList(),
    [60, 64, 67, 71].map((e) => e - 13).toList(),
  ];

  final List<int> _heldChords = [];

  List<int> _heldNotes = [];

  void _pressChord(int index) {
    if (_heldChords.contains(index)) return;

    _heldChords.add(index);
    _updateHeldNotes();
  }

  void _updateHeldNotes() {
    final notes = <int>{};
    for (final chordIndex in _heldChords) {
      notes.addAll(_chords[chordIndex]);
    }

    final removable = _heldNotes.toSet().difference(notes);
    final addable = notes.difference(_heldNotes.toSet());

    for (final note in removable) {
      _soundfontPlayerPlugin.stopNote(note);
    }
    for (final note in addable) {
      _soundfontPlayerPlugin.playNote(note, velocity: 127);
    }

    _heldNotes = notes.toList();
  }

  void _releaseChord(int index) {
    if (!_heldChords.contains(index)) return;
    _heldChords.remove(index);
    _updateHeldNotes();
  }

  // List<ChordItem> chords = List.generate(
  //   8,
  //   (index) => ChordItem(
  //     enabled: false,
  //     chord: ChordEvent(
  //       root: 48,
  //       notes: [0, 3, 7, 10, 14],
  //       velocity: 100,
  //       timestamp: index.toDouble() + ((index % 2 == 1) ? 0.5 : 0.0),
  //       duration: 0.1,
  //     ),
  //   ),
  // ).toList();

  final _soundfontPlayerPlugin = SoundfontPlayer();

  @override
  void initState() {
    super.initState();
    initPlatformState();

    loadFont();
    loadDrums();

    _startTimer();
    _soundfontPlayerPlugin.events.listen((event) {
      debugPrint(event);
    });
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

  Future<void> loadDrums() async {
    final filename = "r70-808.sf2";
    final font = await rootBundle.load('assets/$filename');
    final documents = await getApplicationDocumentsDirectory();
    final path = '${documents.path}/$filename';
    final file = File(path)..writeAsBytesSync(font.buffer.asUint8List());

    await _soundfontPlayerPlugin.loadDrums(file.path);
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
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // SlidingButton(
            //   tapStarted: (value) {
            //     _updatePlaying(40 + (value * 20).toInt());
            //   },
            //   tapUpdated: (value) {
            //     _updatePlaying(40 + (value * 20).toInt());
            //   },
            //   tapEnded: (value) {
            //     _updatePlaying(-1);
            //   },
            // ),
            // GestureDetector(
            //   onTapDown: (details) => _soundfontPlayerPlugin.playNote(60, velocity: 127),
            //   onTapUp: (details) => _soundfontPlayerPlugin.stopNote(60),
            //   onTapCancel: () => _soundfontPlayerPlugin.stopNote(60),
            //   child:
            // ),

            FilledButton(
              onPressed: () {
                _soundfontPlayerPlugin.setTempo(80.0 + Random().nextInt(40));
              },
              child: Text('Set Tempo'),
            ),

            FilledButton(
              onPressed: () {
                _soundfontPlayerPlugin.setDrumTrack(
                  0,
                  1,
                  [
                    RhythmEvent(note: 36, velocity: 100, timestamp: 0, duration: 0.2),
                    RhythmEvent(note: 36, velocity: 100, timestamp: 1, duration: 0.2),
                    RhythmEvent(note: 36, velocity: 100, timestamp: 2, duration: 0.2),
                    RhythmEvent(note: 36, velocity: 100, timestamp: 3, duration: 0.2),
                  ],
                );
              },
              child: Text('Set drums'),
            ),

            FilledButton(
              onPressed: () {
                _soundfontPlayerPlugin.getDrumTrack(0, 0);
              },
              child: Text('Get drums'),
            ),

            FilledButton(
              onPressed: () {
                final pattern = ChordPattern(steps: [
                  ChordPatternStep(notes: [
                    ChordPatternStepNote(note: 0, type: ChordPatternStepNoteType.normal),
                    ChordPatternStepNote(note: 1, type: ChordPatternStepNoteType.normal),
                    ChordPatternStepNote(note: 2, type: ChordPatternStepNoteType.normal),
                    ChordPatternStepNote(note: 3, type: ChordPatternStepNoteType.normal),
                  ]),
                  ChordPatternStep(notes: [
                    ChordPatternStepNote(note: 0, type: ChordPatternStepNoteType.normal),
                  ]),
                  ChordPatternStep(notes: [
                    ChordPatternStepNote(note: 1, type: ChordPatternStepNoteType.normal),
                  ]),
                  ChordPatternStep(notes: [
                    ChordPatternStepNote(note: 2, type: ChordPatternStepNoteType.normal),
                  ]),
                  ChordPatternStep(notes: []),
                  ChordPatternStep(notes: []),
                  ChordPatternStep(notes: [
                    ChordPatternStepNote(note: 0, type: ChordPatternStepNoteType.normal),
                    ChordPatternStepNote(note: 1, type: ChordPatternStepNoteType.normal),
                    ChordPatternStepNote(note: 2, type: ChordPatternStepNoteType.normal),
                    ChordPatternStepNote(note: 3, type: ChordPatternStepNoteType.normal),
                  ]),
                  ChordPatternStep(notes: []),
                  ChordPatternStep(notes: []),
                  ChordPatternStep(notes: [
                    ChordPatternStepNote(note: 0, type: ChordPatternStepNoteType.normal),
                    ChordPatternStepNote(note: 1, type: ChordPatternStepNoteType.normal),
                    ChordPatternStepNote(note: 2, type: ChordPatternStepNoteType.normal),
                    ChordPatternStepNote(note: 3, type: ChordPatternStepNoteType.normal),
                  ]),
                  ChordPatternStep(notes: []),
                  ChordPatternStep(notes: [
                    ChordPatternStepNote(note: 0, type: ChordPatternStepNoteType.normal),
                    ChordPatternStepNote(note: 2, type: ChordPatternStepNoteType.normal),
                  ]),
                  ChordPatternStep(notes: [
                    ChordPatternStepNote(note: 1, type: ChordPatternStepNoteType.normal),
                    ChordPatternStepNote(note: 3, type: ChordPatternStepNoteType.normal),
                  ]),
                  ChordPatternStep(notes: [
                    ChordPatternStepNote(note: 0, type: ChordPatternStepNoteType.normal),
                    ChordPatternStepNote(note: 2, type: ChordPatternStepNoteType.normal),
                  ]),
                ]);
                _soundfontPlayerPlugin.setChordPattern(pattern);
              },
              child: Text('Set pattern'),
            ),
            FilledButton(
              onPressed: () {
                setState(() {
                  _isRepeating = !_isRepeating;
                  _soundfontPlayerPlugin.setRepeating(_isRepeating);
                });
              },
              child: Text(_isRepeating ? 'Repeat' : 'No Repeat'),
            ),
            const SizedBox(width: 10),
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
              child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LinearProgressIndicator(value: (_playheadPosition % 4) / 4),
        const SizedBox(height: 10),
        SizedBox(
          height: 50,
          child: RhythmSequencer(player: _soundfontPlayerPlugin),
        ),
        // SizedBox(
        //   height: 200,
        //   child: ChordSequencer(
        //     chords: chords.toList(),
        //     onChordsChanged: (chords) {
        //       for (int i = 0; i < chords.length; i++) {
        //         final oldChord = this.chords[i];
        //         final newChord = chords[i];
        //         if (oldChord == newChord) continue;
        //         if (newChord.enabled) {
        //           _soundfontPlayerPlugin.addChord(newChord.chord);
        //         } else {
        //           _soundfontPlayerPlugin.removeChord(newChord.chord);
        //         }
        //       }
        //       setState(() {
        //         this.chords = chords;
        //       });
        //     },
        //   ),
        // ),
        Expanded(
          child: GridButtons(
            onTapDown: (index) => _pressChord(index),
            onTapUp: (index) => _releaseChord(index),
          ),
        ),
        Center(
          child: Text('Running on: $_platformVersion\n'),
        ),
      ],
    );
  }
}
