class ChordPattern {
  const ChordPattern({required this.steps});

  final List<ChordPatternStep> steps;

  factory ChordPattern.standard() {
    return ChordPattern(
      steps: List.generate(16, (_) => const ChordPatternStep(notes: [])),
    );
  }

  factory ChordPattern.arp() {
    return ChordPattern(
      steps: List.generate(
        16,
        (index) => ChordPatternStep(
            notes: [ChordPatternStepNote(note: index % 4, type: ChordPatternStepNoteType.normal)]),
      ),
    );
  }

  ChordPattern copyWith({List<ChordPatternStep>? steps}) {
    return ChordPattern(steps: steps ?? this.steps);
  }

  Map<String, dynamic> asMap() {
    return {
      'steps': steps.map((step) => step.asMap()).toList(),
    };
  }

  factory ChordPattern.fromMap(Map<String, dynamic> map) {
    return ChordPattern(
      steps: (map['steps'] as List).map((step) => ChordPatternStep.fromMap(step)).toList(),
    );
  }
}

class ChordPatternStep {
  const ChordPatternStep({required this.notes});

  final List<ChordPatternStepNote> notes;

  ChordPatternStep copyWith({List<ChordPatternStepNote>? notes}) {
    return ChordPatternStep(notes: notes ?? this.notes);
  }

  Map<String, dynamic> asMap() {
    return {
      'notes': notes.map((note) => note.asMap()).toList(),
    };
  }

  factory ChordPatternStep.fromMap(Map<String, dynamic> map) {
    return ChordPatternStep(
      notes: (map['notes'] as List).map<ChordPatternStepNote>((note) => note.fromMap(map)).toList(),
    );
  }
}

enum ChordPatternStepNoteType { normal, sustain, kill }

class ChordPatternStepNote {
  const ChordPatternStepNote({required this.note, required this.type});

  final int note;
  final ChordPatternStepNoteType type;

  ChordPatternStepNote copyWith({int? note, ChordPatternStepNoteType? type}) {
    return ChordPatternStepNote(
      note: note ?? this.note,
      type: type ?? this.type,
    );
  }

  Map<String, dynamic> asMap() {
    return {
      'note': note,
      'type': type.index,
    };
  }

  factory ChordPatternStepNote.fromMap(Map<String, dynamic> map) {
    return ChordPatternStepNote(
      note: map['note'],
      type: ChordPatternStepNoteType.values[map['type']],
    );
  }
}
