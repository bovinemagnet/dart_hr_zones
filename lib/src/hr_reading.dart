/// A single heart rate reading.
///
/// Stores the instantaneous beats-per-minute value and the elapsed time
/// since the start of the recording session, which is used by
/// `calculateTimeInZones` to compute per-zone durations.
class HrReading {
  /// Beats per minute at this sample point.
  final int bpm;

  /// Time elapsed since the recording session started when this sample was
  /// taken.
  final Duration elapsed;

  /// Whether this sample is a deliberate post-exercise recovery measurement
  /// (as opposed to part of the active session).
  ///
  /// Set this on a reading appended after exercise has stopped so
  /// `calculateTimeInZones` can (a) compute the recovery heart-rate drop
  /// deterministically and (b) exclude the cooldown gap that precedes it from
  /// the per-zone totals. Marking the sample explicitly avoids
  /// misclassifying a mid-session sensor dropout as a recovery measurement.
  final bool isRecoverySample;

  /// Creates an [HrReading].
  const HrReading({
    required this.bpm,
    required this.elapsed,
    this.isRecoverySample = false,
  });

  /// Serialises this reading to a JSON-compatible map.
  ///
  /// [elapsed] is stored as integer microseconds under `elapsedMicroseconds`.
  Map<String, dynamic> toJson() => {
        'bpm': bpm,
        'elapsedMicroseconds': elapsed.inMicroseconds,
        'isRecoverySample': isRecoverySample,
      };

  /// Reconstructs an [HrReading] from a [toJson] map.
  factory HrReading.fromJson(Map<String, dynamic> json) => HrReading(
        bpm: json['bpm'] as int,
        elapsed: Duration(microseconds: json['elapsedMicroseconds'] as int),
        isRecoverySample: json['isRecoverySample'] as bool? ?? false,
      );

  @override
  String toString() => 'HrReading(bpm: $bpm, elapsed: $elapsed'
      '${isRecoverySample ? ', recovery' : ''})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HrReading &&
          runtimeType == other.runtimeType &&
          bpm == other.bpm &&
          elapsed == other.elapsed &&
          isRecoverySample == other.isRecoverySample;

  @override
  int get hashCode => Object.hash(bpm, elapsed, isRecoverySample);
}
