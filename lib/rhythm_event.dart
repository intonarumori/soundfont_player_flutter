
class RhythmEvent {
  final int note;
  final int velocity;
  final double timestamp;
  final double duration;

  const RhythmEvent({
    required this.note,
    required this.velocity,
    required this.timestamp,
    required this.duration,
  });

  Map<String, dynamic> asMap() {
    return {
      'note': note,
      'velocity': velocity,
      'timestamp': timestamp,
      'duration': duration,
    };
  }

  factory RhythmEvent.fromMap(Map<String, dynamic> map) {
    return RhythmEvent(
      note: map['note'],
      velocity: map['velocity'],
      timestamp: map['timestamp'],
      duration: map['duration'],
    );
  }

  RhythmEvent copyWith({
    int? note,
    int? velocity,
    double? timestamp,
    double? duration,
  }) {
    return RhythmEvent(
      note: note ?? this.note,
      velocity: velocity ?? this.velocity,
      timestamp: timestamp ?? this.timestamp,
      duration: duration ?? this.duration,
    );
  }
}
