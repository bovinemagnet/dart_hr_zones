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
  ///
  /// Summaries produced by [calculateTimeInZones] hold an unmodifiable list.
  final List<ZoneDuration> zoneDurations;

  /// Total time spent in zone 3 or higher ("moderate-or-higher").
  ///
  /// This maps to current public health guidelines that recommend
  /// ≥ 150 minutes/week of moderate activity.
  final Duration moderateOrHigherDuration;

  /// Total time whose starting reading fell below zone 1's lower bound.
  ///
  /// Such intervals are not credited to any zone, so without this field the
  /// per-zone durations would not account for the whole session. Callers that
  /// need a total active/recorded time can add this to the summed zone
  /// durations.
  final Duration belowZone1Duration;

  /// Recovery heart rate drop: peak session BPM minus the post-exercise
  /// reading.
  ///
  /// Populated when the final reading is flagged
  /// [HrReading.isRecoverySample], or — as a legacy fallback — when it sits at
  /// least [ReadingCadence.cooldownGap] after the previous reading. Prefer the
  /// explicit flag: the gap fallback can misclassify a late sensor dropout as
  /// a recovery measurement.
  ///
  /// Returns `null` when no post-exercise reading is present (the session is
  /// still in progress, or the caller chose not to append a recovery sample).
  final int? recoveryHrDrop;

  /// Creates a [TimeInZoneSummary].
  const TimeInZoneSummary({
    required this.zoneDurations,
    required this.moderateOrHigherDuration,
    this.belowZone1Duration = Duration.zero,
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
      'belowZone1: $belowZone1Duration, '
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
/// When the final reading is flagged [HrReading.isRecoverySample], the
/// cooldown interval leading up to it is excluded from the per-zone totals —
/// that gap is post-exercise, not time held in the last active zone.
///
/// [TimeInZoneSummary.recoveryHrDrop] is populated when the final reading is
/// flagged [HrReading.isRecoverySample], or — as a legacy fallback — when its
/// [HrReading.elapsed] is at least [cooldownGap] after the previous reading's.
/// Prefer the explicit flag: the gap fallback can misclassify a late sensor
/// dropout as a recovery sample. The returned drop is `peakBpm − lastBpm`.
TimeInZoneSummary calculateTimeInZones(
  List<HrReading> readings,
  ZoneConfiguration config, {
  Duration cooldownGap = ReadingCadence.cooldownGap,
}) {
  final accumulators = <int, Duration>{
    for (final z in config.zones) z.zoneNumber: Duration.zero,
  };

  // A reading explicitly flagged as a recovery sample is not part of the
  // active session; the interval that precedes it is cooldown, so it is left
  // out of the per-zone totals.
  final hasRecoverySample =
      readings.length >= 2 && readings.last.isRecoverySample;
  final recoveryIntervalIndex = hasRecoverySample ? readings.length - 2 : -1;

  var belowZone1 = Duration.zero;
  for (var i = 0; i < readings.length - 1; i++) {
    if (i == recoveryIntervalIndex) continue;
    final current = readings[i];
    final next = readings[i + 1];
    final interval = next.elapsed - current.elapsed;
    if (interval <= Duration.zero) continue;

    final zone = currentZoneFromConfig(current.bpm, config);
    if (zone != null) {
      accumulators[zone.zoneNumber] = accumulators[zone.zoneNumber]! + interval;
    } else {
      belowZone1 += interval;
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
    // The explicit flag is authoritative; the gap is a legacy fallback.
    if (last.isRecoverySample || gap >= cooldownGap) {
      final peakBpm =
          readings.map((r) => r.bpm).reduce((a, b) => a > b ? a : b);
      recoveryHrDrop = peakBpm - last.bpm;
    }
  }

  return TimeInZoneSummary(
    zoneDurations: List.unmodifiable(zoneDurations),
    moderateOrHigherDuration: moderateOrHigher,
    belowZone1Duration: belowZone1,
    recoveryHrDrop: recoveryHrDrop,
  );
}
