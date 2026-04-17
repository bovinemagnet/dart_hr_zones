/// Custom zone boundaries specified by the user or a clinician.
///
/// Each zone is defined by its lower bound (inclusive) in beats per minute.
/// The upper bound of a zone is implicitly the lower bound of the next zone
/// (or [zone5Lower] for zone 5, which extends to max HR).
class CustomZoneBoundary {
  /// Lower bound of zone 1 in beats per minute (inclusive).
  final int zone1Lower;

  /// Lower bound of zone 2 in beats per minute (inclusive).
  final int zone2Lower;

  /// Lower bound of zone 3 in beats per minute (inclusive).
  final int zone3Lower;

  /// Lower bound of zone 4 in beats per minute (inclusive).
  final int zone4Lower;

  /// Lower bound of zone 5 in beats per minute (inclusive).
  final int zone5Lower;

  /// Creates a [CustomZoneBoundary].
  const CustomZoneBoundary({
    required this.zone1Lower,
    required this.zone2Lower,
    required this.zone3Lower,
    required this.zone4Lower,
    required this.zone5Lower,
  });

  @override
  String toString() => 'CustomZoneBoundary('
      'z1: $zone1Lower, z2: $zone2Lower, z3: $zone3Lower, '
      'z4: $zone4Lower, z5: $zone5Lower)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomZoneBoundary &&
          runtimeType == other.runtimeType &&
          zone1Lower == other.zone1Lower &&
          zone2Lower == other.zone2Lower &&
          zone3Lower == other.zone3Lower &&
          zone4Lower == other.zone4Lower &&
          zone5Lower == other.zone5Lower;

  @override
  int get hashCode => Object.hash(
        zone1Lower,
        zone2Lower,
        zone3Lower,
        zone4Lower,
        zone5Lower,
      );
}

/// Input model describing the health profile used to calculate heart rate zones.
///
/// Provide as many fields as are known; the calculator uses a priority chain
/// to select the most reliable method available.
class HealthProfile {
  /// Age in years. Used to estimate maximum heart rate via `220 − age` when no
  /// measured maximum is available.
  final int? age;

  /// Resting heart rate in beats per minute. Required for the HRR/Karvonen
  /// method.
  final int? restingHr;

  /// Clinician-prescribed maximum heart rate in beats per minute.
  ///
  /// When set this overrides all percentage-based calculations for both the
  /// `ZoneMethod.clinicianCap` and `ZoneMethod.hrrKarvonen` methods, unless
  /// [betaBlocker] or [heartCondition] is `true` (caution mode).
  final int? clinicianMaxHr;

  /// The user's measured maximum heart rate (e.g. from a lab or field test).
  final int? measuredMaxHr;

  /// Whether the user takes beta-blockers, which suppress heart rate.
  ///
  /// When `true`, percentage-based zones use a more conservative upper limit
  /// and the reliability grade is downgraded to `ZoneReliability.low`.
  final bool betaBlocker;

  /// Whether the user has a known heart condition.
  ///
  /// When `true`, caution mode is activated, which caps zone boundaries at
  /// [clinicianMaxHr] if available and downgrades reliability to
  /// `ZoneReliability.low`.
  final bool heartCondition;

  /// Clinician- or user-provided custom zone boundaries.
  ///
  /// When set, `ZoneMethod.custom` is attempted first in the priority chain.
  final CustomZoneBoundary? customZones;

  /// Creates a [HealthProfile].
  const HealthProfile({
    this.age,
    this.restingHr,
    this.clinicianMaxHr,
    this.measuredMaxHr,
    this.betaBlocker = false,
    this.heartCondition = false,
    this.customZones,
  });

  /// Whether caution mode is active (beta-blocker or heart condition).
  bool get isCautionMode => betaBlocker || heartCondition;

  @override
  String toString() => 'HealthProfile('
      'age: $age, restingHr: $restingHr, measuredMaxHr: $measuredMaxHr, '
      'clinicianMaxHr: $clinicianMaxHr, betaBlocker: $betaBlocker, '
      'heartCondition: $heartCondition, customZones: $customZones)';
}
