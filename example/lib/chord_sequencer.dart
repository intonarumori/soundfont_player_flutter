import 'package:flutter/material.dart';
import 'package:soundfont_player/chord_event.dart';
import 'package:soundfont_player_example/vertical_slider.dart';

class ChordItem {
  final bool enabled;
  final ChordEvent chord;

  const ChordItem({required this.enabled, required this.chord});

  ChordItem copyWith({
    bool? enabled,
    ChordEvent? chord,
  }) {
    return ChordItem(
      enabled: enabled ?? this.enabled,
      chord: chord ?? this.chord,
    );
  }
}

class ChordSequencer extends StatelessWidget {
  const ChordSequencer({
    super.key,
    required this.chords,
    required this.onChordsChanged,
  });

  final List<ChordItem> chords;
  final void Function(List<ChordItem>) onChordsChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        chords.length,
        (index) => Expanded(
          child: ChordSequencerItemWidget(
            chord: chords[index],
            onChordChanged: (value) {
              chords[index] = value;
              onChordsChanged(chords);
            },
          ),
        ),
      ),
    );
  }
}

class ChordSequencerItemWidget extends StatelessWidget {
  const ChordSequencerItemWidget({
    super.key,
    required this.chord,
    required this.onChordChanged,
  });

  final ChordItem chord;
  final ValueChanged<ChordItem> onChordChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Container(
            color: Colors.grey,
            child: VerticalSlider(
              value: chord.chord.root,
              min: 24,
              max: 96,
              onChanged: (v) => onChordChanged(chord.copyWith(
                chord: chord.chord.copyWith(root: v),
              )),
            ),
          ),
        ),
        Checkbox(
            value: chord.enabled,
            onChanged: (v) => onChordChanged(
                  ChordItem(enabled: v ?? false, chord: chord.chord),
                )),
      ],
    );
  }
}
