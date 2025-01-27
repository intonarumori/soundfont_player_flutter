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
}
