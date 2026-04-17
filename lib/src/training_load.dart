import 'dart:math' show exp;

import 'health_profile.dart';
import 'hr_reading.dart';
import 'time_in_zone_calculator.dart';

/// Coefficients for the exponential weighting term in Banister's TRIMP.
///
/// Banister's original paper reports sex-specific values reflecting the
/// different lactate-response curves in men and women:
/// `a = 0.64, b = 1.92` for men and `a = 0.86, b = 1.67` for women.
/// Other cohorts (e.g. children, clinical populations) have their own derived
/// pairs; this class lets callers pass any validated pair they like.
class BanisterCoefficients {
  /// Intensity factor (typically 0.64 – 0.86).
  final double a;

  /// Steepness factor (typically 1.67 – 1.92).
  final double b;

  /// Creates a [BanisterCoefficients] value with explicit [a] / [b].
  const BanisterCoefficients({required this.a, required this.b});

  /// Banister's published male coefficients (`a = 0.64`, `b = 1.92`).
  const BanisterCoefficients.male()
      : a = 0.64,
        b = 1.92;

  /// Banister's published female coefficients (`a = 0.86`, `b = 1.67`).
  const BanisterCoefficients.female()
      : a = 0.86,
        b = 1.67;

  @override
  String toString() => 'BanisterCoefficients(a: $a, b: $b)';
}

/// Edwards (1993) TRIMP: zone-weighted training load.
///
/// Each zone's minutes are multiplied by the zone number and summed:
/// `1 × z1 + 2 × z2 + 3 × z3 + 4 × z4 + 5 × z5`, returned as a fractional
/// minute count (so a 30-minute zone-3 session scores `90`).
///
/// The score is derived directly from [summary] and therefore inherits its
/// zone definition: this works for any configuration that
/// [calculateTimeInZones] produced, including LTHR-anchored configurations.
double calculateEdwardsTrimp(TimeInZoneSummary summary) {
  var total = 0.0;
  for (final zd in summary.zoneDurations) {
    final minutes = zd.duration.inMicroseconds / Duration.microsecondsPerMinute;
    total += zd.zone.zoneNumber * minutes;
  }
  return total;
}

/// Banister (1991) TRIMP: exponentially-weighted training load.
///
/// Computed per interval between consecutive [readings] as:
///
/// ```text
/// TRIMP   = Σ (Δt_minutes × HRRf × a × exp(b × HRRf))
/// HRRf    = (hr − restingHr) / (maxHr − restingHr)   // clamped to [0, 1]
/// ```
///
/// The earlier reading's BPM is used as `hr` for its interval (matching
/// [calculateTimeInZones]). Intervals with non-positive duration are ignored.
///
/// Returns `null` when the [profile] lacks either [HealthProfile.restingHr]
/// or a resolvable maximum heart rate (measured or age-estimated via
/// [HealthProfile.maxHrFormula]). Returns `0` when [readings] has fewer than
/// two samples.
///
/// The [coefficients] parameter defaults to
/// [BanisterCoefficients.male]; pass [BanisterCoefficients.female] or a
/// custom pair when sex-specific or cohort-specific weighting is desired.
double? calculateBanisterTrimp(
  List<HrReading> readings,
  HealthProfile profile, {
  BanisterCoefficients coefficients = const BanisterCoefficients.male(),
}) {
  final restingHr = profile.restingHr;
  if (restingHr == null) return null;
  final maxHr = profile.measuredMaxHr ?? profile.estimatedMaxHr;
  if (maxHr == null) return null;
  final range = maxHr - restingHr;
  if (range <= 0) return null;

  if (readings.length < 2) return 0.0;

  var total = 0.0;
  for (var i = 0; i < readings.length - 1; i++) {
    final current = readings[i];
    final next = readings[i + 1];
    final interval = next.elapsed - current.elapsed;
    if (interval <= Duration.zero) continue;

    var hrrFraction = (current.bpm - restingHr) / range;
    if (hrrFraction < 0) hrrFraction = 0;
    if (hrrFraction > 1) hrrFraction = 1;

    final minutes = interval.inMicroseconds / Duration.microsecondsPerMinute;
    final weighting = coefficients.a * exp(coefficients.b * hrrFraction);
    total += minutes * hrrFraction * weighting;
  }
  return total;
}
