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

  /// Creates an [HrReading].
  const HrReading({required this.bpm, required this.elapsed});

  @override
  String toString() => 'HrReading(bpm: $bpm, elapsed: $elapsed)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HrReading &&
          runtimeType == other.runtimeType &&
          bpm == other.bpm &&
          elapsed == other.elapsed;

  @override
  int get hashCode => Object.hash(bpm, elapsed);
}
