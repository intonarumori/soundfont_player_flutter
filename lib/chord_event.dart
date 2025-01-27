class ChordEvent {
  final int root;
  final List<int> notes;
  final int velocity;
  final double timestamp;
  final double duration;

  const ChordEvent({
    required this.root,
    required this.notes,
    required this.velocity,
    required this.timestamp,
    required this.duration,
  });

  Map<String, dynamic> asMap() {
    return {
      'root': root,
      'notes': notes,
      'velocity': velocity,
      'timestamp': timestamp,
      'duration': duration,
    };
  }

  factory ChordEvent.fromMap(Map<String, dynamic> map) {
    return ChordEvent(
      root: map['root'],
      notes: List<int>.from(map['notes']),
      velocity: map['velocity'],
      timestamp: map['timestamp'],
      duration: map['duration'],
    );
  }

  ChordEvent copyWith({
    int? root,
    List<int>? notes,
    int? velocity,
    double? timestamp,
    double? duration,
  }) {
    return ChordEvent(
      root: root ?? this.root,
      notes: notes ?? this.notes,
      velocity: velocity ?? this.velocity,
      timestamp: timestamp ?? this.timestamp,
      duration: duration ?? this.duration,
    );
  }
}
