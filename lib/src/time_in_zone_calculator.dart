import 'hr_reading.dart';
import 'zone_calculator.dart';

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

/// Per-zone duration summary produced by [calculateTimeInZones].
class ZoneDuration {
  /// The zone this duration applies to.
  final CalculatedZone zone;

  /// Total time spent in this zone across the reading sequence.
  final Duration duration;

  /// Creates a [ZoneDuration].
  const ZoneDuration({required this.zone, required this.duration});

  @override
  String toString() =>
      'ZoneDuration(zone: ${zone.zoneNumber}, duration: $duration)';
}

/// Constants used to classify reading cadence for recovery detection.
abstract class ReadingCadence {
  /// Default minimum gap (from the penultimate to the final reading) that
  /// qualifies the final reading as a post-exercise "recovery" sample.
  ///
  /// 55 seconds leaves a little slack around the one-minute convention used
  /// in sports-medicine recovery HR assessments.
  static const Duration cooldownGap = Duration(seconds: 55);
}

/// The result of [calculateTimeInZones].
class TimeInZoneSummary {
  /// Per-zone durations, in zone-number order (zone 1 first).
  final List<ZoneDuration> zoneDurations;

  /// Total time spent in zone 3 or higher ("moderate-or-higher").
  ///
  /// This maps to current public health guidelines that recommend
  /// ≥ 150 minutes/week of moderate activity.
  final Duration moderateOrHigherDuration;

  /// Recovery heart rate drop: peak session BPM minus the post-exercise
  /// reading, when the caller has appended a post-session reading at least
  /// [ReadingCadence.cooldownGap] after exercise stopped.
  ///
  /// Returns `null` when no such post-exercise reading is present (the
  /// session is still in progress, or the caller chose not to append a
  /// recovery sample).
  final int? recoveryHrDrop;

  /// Creates a [TimeInZoneSummary].
  const TimeInZoneSummary({
    required this.zoneDurations,
    required this.moderateOrHigherDuration,
    this.recoveryHrDrop,
  });

  /// Convenience accessor: duration in zone [number] (1-based).
  ///
  /// Returns [Duration.zero] if the zone number is not found.
  Duration durationInZone(int number) {
    for (final zd in zoneDurations) {
      if (zd.zone.zoneNumber == number) return zd.duration;
    }
    return Duration.zero;
  }

  @override
  String toString() => 'TimeInZoneSummary('
      'moderateOrHigher: $moderateOrHigherDuration, '
      'recoveryHrDrop: $recoveryHrDrop, '
      'zones: $zoneDurations)';
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Summarises a sequence of [readings] into per-zone durations using the
/// zone boundaries in [config].
///
/// The duration for a zone segment is the difference in [HrReading.elapsed]
/// between consecutive readings. The zone used for each interval is
/// determined by the *earlier* reading's BPM value. Intervals with
/// non-positive duration are ignored.
///
/// [TimeInZoneSummary.recoveryHrDrop] is populated only when the last
/// reading's [HrReading.elapsed] is at least [cooldownGap] after the
/// previous reading's. That gap is the convention for a post-exercise
/// recovery sample — during active monitoring the field stays `null`, so
/// UIs don't have to invent ad-hoc rules to decide when to show it.
/// The returned drop is `peakBpm − lastBpm`.
TimeInZoneSummary calculateTimeInZones(
  List<HrReading> readings,
  ZoneConfiguration config, {
  Duration cooldownGap = ReadingCadence.cooldownGap,
}) {
  final accumulators = <int, Duration>{
    for (final z in config.zones) z.zoneNumber: Duration.zero,
  };

  for (var i = 0; i < readings.length - 1; i++) {
    final current = readings[i];
    final next = readings[i + 1];
    final interval = next.elapsed - current.elapsed;
    if (interval <= Duration.zero) continue;

    final zone = currentZoneFromConfig(current.bpm, config);
    if (zone != null) {
      accumulators[zone.zoneNumber] = accumulators[zone.zoneNumber]! + interval;
    }
  }

  final zoneDurations = config.zones
      .map(
        (z) => ZoneDuration(
          zone: z,
          duration: accumulators[z.zoneNumber] ?? Duration.zero,
        ),
      )
      .toList();

  var moderateOrHigher = Duration.zero;
  for (final zd in zoneDurations) {
    if (zd.zone.zoneNumber >= 3) {
      moderateOrHigher += zd.duration;
    }
  }

  int? recoveryHrDrop;
  if (readings.length >= 2) {
    final last = readings.last;
    final penultimate = readings[readings.length - 2];
    final gap = last.elapsed - penultimate.elapsed;
    if (gap >= cooldownGap) {
      final peakBpm =
          readings.map((r) => r.bpm).reduce((a, b) => a > b ? a : b);
      recoveryHrDrop = peakBpm - last.bpm;
    }
  }

  return TimeInZoneSummary(
    zoneDurations: zoneDurations,
    moderateOrHigherDuration: moderateOrHigher,
    recoveryHrDrop: recoveryHrDrop,
  );
}
