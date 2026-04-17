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

/// The result of [calculateTimeInZones].
class TimeInZoneSummary {
  /// Per-zone durations, in zone-number order (zone 1 first).
  final List<ZoneDuration> zoneDurations;

  /// Total time spent in zone 3 or higher ("moderate-or-higher").
  ///
  /// This maps to current public health guidelines that recommend
  /// ≥ 150 minutes/week of moderate activity.
  final Duration moderateOrHigherDuration;

  /// Heart rate at the first reading minus heart rate at the last reading,
  /// expressed as a positive value when the heart rate decreased (recovery).
  ///
  /// Returns `null` if fewer than two readings were provided.
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
/// between consecutive readings.  The zone used for each interval is
/// determined by the *earlier* reading's BPM value.
///
/// Returns a [TimeInZoneSummary] with:
/// - per-zone accumulated durations,
/// - total time in zone 3 or higher ([TimeInZoneSummary.moderateOrHigherDuration]),
/// - the HR drop between the first and last reading
///   ([TimeInZoneSummary.recoveryHrDrop]).
///
/// An empty or single-reading list returns zero durations and a `null` drop.
TimeInZoneSummary calculateTimeInZones(
  List<HrReading> readings,
  ZoneConfiguration config,
) {
  // Initialise an accumulator for every zone.
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
      accumulators[zone.zoneNumber] =
          accumulators[zone.zoneNumber]! + interval;
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

  // Moderate-or-higher: zones 3, 4, 5.
  var moderateOrHigher = Duration.zero;
  for (final zd in zoneDurations) {
    if (zd.zone.zoneNumber >= 3) {
      moderateOrHigher += zd.duration;
    }
  }

  // Recovery HR drop.
  int? recoveryHrDrop;
  if (readings.length >= 2) {
    recoveryHrDrop = readings.first.bpm - readings.last.bpm;
  }

  return TimeInZoneSummary(
    zoneDurations: zoneDurations,
    moderateOrHigherDuration: moderateOrHigher,
    recoveryHrDrop: recoveryHrDrop,
  );
}
