import 'package:flutter/material.dart';
import 'package:soundfont_player/rhythm_event.dart';
import 'package:soundfont_player/soundfont_player.dart';

class RhythmSequencer extends StatefulWidget {
  const RhythmSequencer({super.key, required this.player});

  final SoundfontPlayer player;

  @override
  State<RhythmSequencer> createState() => _RhythmSequencerState();
}

class _RhythmSequencerState extends State<RhythmSequencer> {
  final items = List.generate(16, (_) {
    return false;
  });

  void _toggle(int index) {
    if (items[index]) {
      items[index] = false;
      widget.player.removeRhythmEvent(RhythmEvent(
        timestamp: index * 0.25,
        duration: 0.1,
        velocity: 100,
        note: 60,
      ));
    } else {
      items[index] = true;
      widget.player.addRhythmEvent(RhythmEvent(
        timestamp: index * 0.25,
        duration: 0.1,
        velocity: 100,
        note: 60,
      ));
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ...items.asMap().entries.map((e) {
          return Checkbox(value: e.value, onChanged: (_) => _toggle(e.key));
        }),
      ],
    );
  }
}
