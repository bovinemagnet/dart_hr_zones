/// Formula used to estimate maximum heart rate from age alone.
///
/// The default, [tanaka], is the modern consensus formula (Tanaka, Monahan &
/// Seals, 2001): `208 − 0.7 × age`. It was derived from a meta-analysis of
/// 351 studies and tracks observed max HR more accurately than the older
/// Fox 1971 formula, especially for people over 40.
///
/// [fox220] is kept for callers that need to match legacy tooling (`220 − age`,
/// Fox, Naughton & Haskell, 1971).
///
/// [nes] (Nes et al., 2013) is `211 − 0.64 × age`, derived from a large
/// Norwegian cross-sectional study and slightly more accurate for fit adults.
///
/// [gellish2007], [astrand], and [millerFaulkner] are additional published
/// alternatives covering different cohorts; see each value's doc comment for
/// the citation.
enum MaxHrFormula {
  /// Tanaka 2001: `208 − 0.7 × age`. Modern default.
  tanaka,

  /// Fox 1971: `220 − age`. Legacy formula, widely taught but less accurate
  /// for older adults.
  fox220,

  /// Nes et al. 2013: `211 − 0.64 × age`. Large Norwegian sample.
  nes,

  /// Gellish et al. 2007: `207 − 0.7 × age`. Linear form derived from 908
  /// healthy adults across a wide age range.
  gellish2007,

  /// Åstrand 1952: `216.6 − 0.84 × age`. Classical formula with a steeper
  /// age-related decline than Tanaka.
  astrand,

  /// Miller, Wallace & Eggert 1993: `217 − 0.85 × age`. Derived from a
  /// meta-analytic adjustment of earlier Fox-style estimates.
  millerFaulkner,
}

/// Extension exposing the numeric evaluation of each [MaxHrFormula].
extension MaxHrFormulaApply on MaxHrFormula {
  /// Computes the estimated maximum heart rate for [age] in years.
  int apply(int age) {
    switch (this) {
      case MaxHrFormula.tanaka:
        return (208 - 0.7 * age).round();
      case MaxHrFormula.fox220:
        return 220 - age;
      case MaxHrFormula.nes:
        return (211 - 0.64 * age).round();
      case MaxHrFormula.gellish2007:
        return (207 - 0.7 * age).round();
      case MaxHrFormula.astrand:
        return (216.6 - 0.84 * age).round();
      case MaxHrFormula.millerFaulkner:
        return (217 - 0.85 * age).round();
    }
  }

  /// Human-readable short name suitable for UI / reason strings.
  String get displayName {
    switch (this) {
      case MaxHrFormula.tanaka:
        return 'Tanaka (208 \u2212 0.7 \u00d7 age)';
      case MaxHrFormula.fox220:
        return 'Fox (220 \u2212 age)';
      case MaxHrFormula.nes:
        return 'Nes (211 \u2212 0.64 \u00d7 age)';
      case MaxHrFormula.gellish2007:
        return 'Gellish (207 \u2212 0.7 \u00d7 age)';
      case MaxHrFormula.astrand:
        return '\u00c5strand (216.6 \u2212 0.84 \u00d7 age)';
      case MaxHrFormula.millerFaulkner:
        return 'Miller\u2013Faulkner (217 \u2212 0.85 \u00d7 age)';
    }
  }
}

/// Custom zone boundaries specified by the user or a clinician.
///
/// Each zone is defined by its lower bound (inclusive) in beats per minute.
/// The upper bound of a zone is implicitly the lower bound of the next zone
/// (or [zone5Lower] for zone 5, which extends to max HR).
///
/// Optionally, [labels] supplies a human-readable effort label for each of
/// the five zones (e.g. `['Marathon', 'Endurance', 'Tempo', 'Threshold',
/// 'VO₂']`). When `null`, the default effort labels are used.
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

  /// Optional per-zone effort labels. Must contain exactly 5 entries when set.
  ///
  /// When `null`, the library's default effort labels are used (`'Easy'`,
  /// `'Light'`, `'Moderate'`, `'Hard'`, `'Very Hard'`).
  final List<String>? labels;

  /// Creates a [CustomZoneBoundary].
  const CustomZoneBoundary({
    required this.zone1Lower,
    required this.zone2Lower,
    required this.zone3Lower,
    required this.zone4Lower,
    required this.zone5Lower,
    this.labels,
  });

  @override
  String toString() => 'CustomZoneBoundary('
      'z1: $zone1Lower, z2: $zone2Lower, z3: $zone3Lower, '
      'z4: $zone4Lower, z5: $zone5Lower'
      '${labels != null ? ', labels: $labels' : ''})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! CustomZoneBoundary) return false;
    if (zone1Lower != other.zone1Lower ||
        zone2Lower != other.zone2Lower ||
        zone3Lower != other.zone3Lower ||
        zone4Lower != other.zone4Lower ||
        zone5Lower != other.zone5Lower) {
      return false;
    }
    final a = labels;
    final b = other.labels;
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        zone1Lower,
        zone2Lower,
        zone3Lower,
        zone4Lower,
        zone5Lower,
        labels == null ? 0 : Object.hashAll(labels!),
      );
}

/// Input model describing the health profile used to calculate heart rate zones.
///
/// Provide as many fields as are known; the calculator uses a priority chain
/// to select the most reliable method available.
class HealthProfile {
  /// Age in years. Used to estimate maximum heart rate via [maxHrFormula]
  /// when no measured maximum is available.
  final int? age;

  /// Resting heart rate in beats per minute. Required for the HRR/Karvonen
  /// method.
  final int? restingHr;

  /// Clinician-prescribed maximum heart rate in beats per minute.
  ///
  /// When set this takes priority over measured/estimated max values and
  /// produces `ZoneMethod.clinicianCap` zones with high reliability — the
  /// clinician's guidance overrides the usual method selection regardless of
  /// caution flags.
  final int? clinicianMaxHr;

  /// The user's measured maximum heart rate (e.g. from a lab or field test).
  final int? measuredMaxHr;

  /// Measured lactate threshold heart rate in beats per minute.
  ///
  /// Typically obtained from a 30-minute time-trial protocol (Friel) or a
  /// lab lactate test. When set, the LTHR / Friel method is attempted in the
  /// priority chain after [clinicianMaxHr] but before HRR/Karvonen — LTHR is
  /// a measured threshold value and, when available, is a stronger anchor
  /// than the HRR fallback.
  final int? lactateThresholdHr;

  /// Whether the user takes beta-blockers, which suppress heart rate.
  ///
  /// When `true` and no [clinicianMaxHr] is set, reliability is downgraded to
  /// `ZoneReliability.low`. When a clinician cap is present it takes
  /// precedence and reliability remains high.
  final bool betaBlocker;

  /// Whether the user has a known heart condition.
  ///
  /// When `true` and no [clinicianMaxHr] is set, reliability is downgraded to
  /// `ZoneReliability.low`. When a clinician cap is present it takes
  /// precedence and reliability remains high.
  final bool heartCondition;

  /// Clinician- or user-provided custom zone boundaries.
  ///
  /// When set, `ZoneMethod.custom` is attempted first in the priority chain.
  final CustomZoneBoundary? customZones;

  /// Formula used to compute [estimatedMaxHr] when no measured maximum is
  /// provided. Defaults to [MaxHrFormula.tanaka] — the modern consensus
  /// formula that is more accurate than `220 − age` for adults over 40.
  final MaxHrFormula maxHrFormula;

  /// Creates a [HealthProfile].
  const HealthProfile({
    this.age,
    this.restingHr,
    this.clinicianMaxHr,
    this.measuredMaxHr,
    this.lactateThresholdHr,
    this.betaBlocker = false,
    this.heartCondition = false,
    this.customZones,
    this.maxHrFormula = MaxHrFormula.tanaka,
  });

  /// Whether caution mode is active (beta-blocker or heart condition).
  bool get isCautionMode => betaBlocker || heartCondition;

  /// Age-estimated maximum heart rate using [maxHrFormula].
  ///
  /// Returns `null` when [age] is `null`.
  int? get estimatedMaxHr => age != null ? maxHrFormula.apply(age!) : null;

  /// Returns a copy of this profile with the given fields replaced.
  ///
  /// To set a currently-populated field back to `null`, pass the matching
  /// `clear…` flag as `true`. Passing only a new non-null value follows the
  /// usual "leave unchanged when omitted" contract.
  HealthProfile copyWith({
    int? age,
    bool clearAge = false,
    int? restingHr,
    bool clearRestingHr = false,
    int? clinicianMaxHr,
    bool clearClinicianMaxHr = false,
    int? measuredMaxHr,
    bool clearMeasuredMaxHr = false,
    int? lactateThresholdHr,
    bool clearLactateThresholdHr = false,
    bool? betaBlocker,
    bool? heartCondition,
    CustomZoneBoundary? customZones,
    bool clearCustomZones = false,
    MaxHrFormula? maxHrFormula,
  }) {
    return HealthProfile(
      age: clearAge ? null : (age ?? this.age),
      restingHr: clearRestingHr ? null : (restingHr ?? this.restingHr),
      clinicianMaxHr:
          clearClinicianMaxHr ? null : (clinicianMaxHr ?? this.clinicianMaxHr),
      measuredMaxHr:
          clearMeasuredMaxHr ? null : (measuredMaxHr ?? this.measuredMaxHr),
      lactateThresholdHr: clearLactateThresholdHr
          ? null
          : (lactateThresholdHr ?? this.lactateThresholdHr),
      betaBlocker: betaBlocker ?? this.betaBlocker,
      heartCondition: heartCondition ?? this.heartCondition,
      customZones: clearCustomZones ? null : (customZones ?? this.customZones),
      maxHrFormula: maxHrFormula ?? this.maxHrFormula,
    );
  }

  @override
  String toString() => 'HealthProfile('
      'age: $age, restingHr: $restingHr, measuredMaxHr: $measuredMaxHr, '
      'clinicianMaxHr: $clinicianMaxHr, '
      'lactateThresholdHr: $lactateThresholdHr, '
      'betaBlocker: $betaBlocker, '
      'heartCondition: $heartCondition, customZones: $customZones, '
      'maxHrFormula: $maxHrFormula)';
}
