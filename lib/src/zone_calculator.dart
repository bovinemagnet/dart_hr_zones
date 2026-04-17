import 'health_profile.dart';

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

/// The calculation method used to derive the zone boundaries.
enum ZoneMethod {
  /// Boundaries were supplied directly by the user or a clinician.
  custom,

  /// Boundaries are derived from a clinician-prescribed maximum heart rate,
  /// applying standard percentage bands to that cap.
  clinicianCap,

  /// Heart-Rate Reserve (Karvonen) method:
  /// `targetHR = (maxHR − restingHR) × intensity + restingHR`.
  /// Requires both a maximum heart rate (measured or estimated) and a resting
  /// heart rate.
  hrrKarvonen,

  /// Percentage-of-measured-maximum method.
  /// Requires [HealthProfile.measuredMaxHr].
  percentOfMeasuredMax,

  /// Percentage-of-estimated-maximum method.
  /// Estimates maximum HR as `220 − age`.
  /// Requires [HealthProfile.age].
  percentOfEstimatedMax,
}

/// The reliability grade for the calculated zone configuration.
enum ZoneReliability {
  /// Based on measured data (measured max HR or explicit custom zones) without
  /// any medical flags.
  high,

  /// Based on estimated data (age-predicted max HR or clinician cap) without
  /// any medical flags.
  medium,

  /// Caution mode is active (beta-blocker or heart condition) or the input
  /// data is incomplete.
  low,
}

/// A single calculated heart rate zone.
class CalculatedZone {
  /// Zone number (1 – 5).
  final int zoneNumber;

  /// Human-readable label (e.g. "Zone 1 – Recovery").
  final String label;

  /// Lower bound in beats per minute (inclusive).
  final int lowerBound;

  /// Upper bound in beats per minute (exclusive), or `null` for the top zone.
  final int? upperBound;

  /// Zone colour as a packed `0xAARRGGBB` integer.
  final int color;

  /// Creates a [CalculatedZone].
  const CalculatedZone({
    required this.zoneNumber,
    required this.label,
    required this.lowerBound,
    this.upperBound,
    required this.color,
  });

  /// Returns `true` if [bpm] falls within this zone.
  bool containsBpm(int bpm) {
    if (bpm < lowerBound) return false;
    final upper = upperBound;
    if (upper != null && bpm >= upper) return false;
    return true;
  }

  @override
  String toString() => 'CalculatedZone($zoneNumber: $lowerBound'
      '${upperBound != null ? ' – ${upperBound! - 1}' : '+'} bpm)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalculatedZone &&
          runtimeType == other.runtimeType &&
          zoneNumber == other.zoneNumber &&
          lowerBound == other.lowerBound &&
          upperBound == other.upperBound;

  @override
  int get hashCode => Object.hash(zoneNumber, lowerBound, upperBound);
}

/// The result of a zone calculation, containing all five zones and metadata.
class ZoneConfiguration {
  /// The five calculated zones, ordered from zone 1 to zone 5.
  final List<CalculatedZone> zones;

  /// The calculation method that was used.
  final ZoneMethod method;

  /// The reliability grade for this configuration.
  final ZoneReliability reliability;

  /// The maximum heart rate (in bpm) used to compute the zones.
  ///
  /// May be measured, estimated, or a clinician cap depending on [method].
  final int maxHr;

  /// Creates a [ZoneConfiguration].
  const ZoneConfiguration({
    required this.zones,
    required this.method,
    required this.reliability,
    required this.maxHr,
  });

  @override
  String toString() =>
      'ZoneConfiguration(method: $method, reliability: $reliability, '
      'maxHr: $maxHr, zones: $zones)';
}

// ---------------------------------------------------------------------------
// Default zone bands and colours
// ---------------------------------------------------------------------------

/// Default percentage bands for the five zones.
///
/// Each entry is `(lowerPercent, upperPercent)` where both values are in the
/// range 0–100.  The upper value of zone 5 is implicitly 100.
const List<(double, double)> _defaultBands = [
  (50.0, 60.0), // Zone 1 – Recovery
  (60.0, 70.0), // Zone 2 – Base Fitness
  (70.0, 80.0), // Zone 3 – Aerobic
  (80.0, 90.0), // Zone 4 – Lactate Threshold
  (90.0, 100.0), // Zone 5 – VO₂ Max
];

/// Default zone labels.
const List<String> _defaultLabels = [
  'Zone 1 – Recovery',
  'Zone 2 – Base Fitness',
  'Zone 3 – Aerobic',
  'Zone 4 – Lactate Threshold',
  'Zone 5 – VO₂ Max',
];

/// Default zone colours (`0xAARRGGBB`).
const List<int> _defaultColors = [
  0xFF4FC3F7, // Zone 1 – light blue
  0xFF81C784, // Zone 2 – light green
  0xFFFFD54F, // Zone 3 – amber
  0xFFFF8A65, // Zone 4 – deep orange
  0xFFE57373, // Zone 5 – red
];

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Calculates heart rate zones from the supplied [profile].
///
/// Attempts each method in priority order and returns the first that succeeds:
///
/// 1. [ZoneMethod.custom] — if [HealthProfile.customZones] is set.
/// 2. [ZoneMethod.clinicianCap] — if [HealthProfile.clinicianMaxHr] is set and
///    caution mode is not active.
/// 3. [ZoneMethod.hrrKarvonen] — if both a max HR and
///    [HealthProfile.restingHr] are available.
/// 4. [ZoneMethod.percentOfMeasuredMax] — if [HealthProfile.measuredMaxHr]
///    is set.
/// 5. [ZoneMethod.percentOfEstimatedMax] — if [HealthProfile.age] is set.
///
/// Returns `null` if none of the methods can produce zones from the available
/// data.
///
/// **Optional overrides**
///
/// - [bands]: five `(lowerPercent, upperPercent)` tuples overriding the
///   default zone widths.
/// - [labels]: five zone label strings.
/// - [colors]: five `0xAARRGGBB` colour integers.
ZoneConfiguration? calculateZones(
  HealthProfile profile, {
  List<(double, double)>? bands,
  List<String>? labels,
  List<int>? colors,
}) {
  final effectiveBands = bands ?? _defaultBands;
  final effectiveLabels = labels ?? _defaultLabels;
  final effectiveColors = colors ?? _defaultColors;

  assert(effectiveBands.length == 5, 'bands must have exactly 5 entries');
  assert(effectiveLabels.length == 5, 'labels must have exactly 5 entries');
  assert(effectiveColors.length == 5, 'colors must have exactly 5 entries');

  // 1. Custom zones
  final custom = profile.customZones;
  if (custom != null) {
    return _customZones(custom, effectiveLabels, effectiveColors);
  }

  // 2. Clinician cap (only when caution mode is not active)
  final clinicianMax = profile.clinicianMaxHr;
  if (clinicianMax != null && !profile.isCautionMode) {
    return _percentOfMaxZones(
      maxHr: clinicianMax,
      method: ZoneMethod.clinicianCap,
      reliability: ZoneReliability.medium,
      bands: effectiveBands,
      labels: effectiveLabels,
      colors: effectiveColors,
    );
  }

  // Resolve best available max HR for Karvonen and percentage methods.
  // In caution mode cap at clinicianMaxHr if present.
  final int? resolvedMax = _resolveMaxHr(profile);

  // 3. HRR / Karvonen
  final restingHr = profile.restingHr;
  if (resolvedMax != null && restingHr != null) {
    return _hrrZones(
      maxHr: resolvedMax,
      restingHr: restingHr,
      reliability: profile.isCautionMode
          ? ZoneReliability.low
          : _maxHrReliability(profile, resolvedMax),
      bands: effectiveBands,
      labels: effectiveLabels,
      colors: effectiveColors,
    );
  }

  // 4. Percent of measured max
  final measuredMax = profile.measuredMaxHr;
  if (measuredMax != null) {
    final capped =
        (clinicianMax != null && profile.isCautionMode && measuredMax > clinicianMax)
            ? clinicianMax
            : measuredMax;
    return _percentOfMaxZones(
      maxHr: capped,
      method: ZoneMethod.percentOfMeasuredMax,
      reliability: profile.isCautionMode
          ? ZoneReliability.low
          : ZoneReliability.high,
      bands: effectiveBands,
      labels: effectiveLabels,
      colors: effectiveColors,
    );
  }

  // 5. Percent of estimated max (220 – age)
  final age = profile.age;
  if (age != null) {
    final estimated = 220 - age;
    final capped =
        (clinicianMax != null && profile.isCautionMode && estimated > clinicianMax)
            ? clinicianMax
            : estimated;
    return _percentOfMaxZones(
      maxHr: capped,
      method: ZoneMethod.percentOfEstimatedMax,
      reliability: profile.isCautionMode
          ? ZoneReliability.low
          : ZoneReliability.medium,
      bands: effectiveBands,
      labels: effectiveLabels,
      colors: effectiveColors,
    );
  }

  return null;
}

/// Returns the [CalculatedZone] from [config] that contains [bpm], or `null`
/// if [bpm] is below the lowest zone boundary.
CalculatedZone? currentZoneFromConfig(int bpm, ZoneConfiguration config) {
  for (final zone in config.zones) {
    if (zone.containsBpm(bpm)) return zone;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

/// Resolves the best max HR available (measured takes priority over estimated).
/// In caution mode, caps at clinicianMaxHr if it is lower.
int? _resolveMaxHr(HealthProfile profile) {
  int? max;
  if (profile.measuredMaxHr != null) {
    max = profile.measuredMaxHr;
  } else if (profile.age != null) {
    max = 220 - profile.age!;
  }

  if (max == null) return null;

  final cap = profile.clinicianMaxHr;
  if (cap != null && profile.isCautionMode && max > cap) {
    return cap;
  }
  return max;
}

/// Derives reliability from the type of max HR available.
ZoneReliability _maxHrReliability(HealthProfile profile, int resolvedMax) {
  if (profile.measuredMaxHr != null && resolvedMax == profile.measuredMaxHr) {
    return ZoneReliability.high;
  }
  return ZoneReliability.medium;
}

/// Builds a [ZoneConfiguration] from explicit custom zone boundaries.
ZoneConfiguration _customZones(
  CustomZoneBoundary custom,
  List<String> labels,
  List<int> colors,
) {
  final lowers = [
    custom.zone1Lower,
    custom.zone2Lower,
    custom.zone3Lower,
    custom.zone4Lower,
    custom.zone5Lower,
  ];

  final zones = <CalculatedZone>[];
  for (var i = 0; i < 5; i++) {
    zones.add(
      CalculatedZone(
        zoneNumber: i + 1,
        label: labels[i],
        lowerBound: lowers[i],
        upperBound: i < 4 ? lowers[i + 1] : null,
        color: colors[i],
      ),
    );
  }

  return ZoneConfiguration(
    zones: zones,
    method: ZoneMethod.custom,
    reliability: ZoneReliability.high,
    maxHr: custom.zone5Lower,
  );
}

/// Builds a [ZoneConfiguration] using a percentage-of-max-HR approach.
ZoneConfiguration _percentOfMaxZones({
  required int maxHr,
  required ZoneMethod method,
  required ZoneReliability reliability,
  required List<(double, double)> bands,
  required List<String> labels,
  required List<int> colors,
}) {
  final zones = <CalculatedZone>[];
  for (var i = 0; i < 5; i++) {
    final (lower, upper) = bands[i];
    final lowerBpm = (maxHr * lower / 100).round();
    final upperBpm = i < 4 ? (maxHr * upper / 100).round() : null;
    zones.add(
      CalculatedZone(
        zoneNumber: i + 1,
        label: labels[i],
        lowerBound: lowerBpm,
        upperBound: upperBpm,
        color: colors[i],
      ),
    );
  }
  return ZoneConfiguration(
    zones: zones,
    method: method,
    reliability: reliability,
    maxHr: maxHr,
  );
}

/// Builds a [ZoneConfiguration] using the HRR (Karvonen) method.
///
/// `targetHR = (maxHR − restingHR) × intensity + restingHR`
ZoneConfiguration _hrrZones({
  required int maxHr,
  required int restingHr,
  required ZoneReliability reliability,
  required List<(double, double)> bands,
  required List<String> labels,
  required List<int> colors,
}) {
  final hrr = maxHr - restingHr;
  final zones = <CalculatedZone>[];
  for (var i = 0; i < 5; i++) {
    final (lower, upper) = bands[i];
    final lowerBpm = (hrr * lower / 100 + restingHr).round();
    final upperBpm = i < 4 ? (hrr * upper / 100 + restingHr).round() : null;
    zones.add(
      CalculatedZone(
        zoneNumber: i + 1,
        label: labels[i],
        lowerBound: lowerBpm,
        upperBound: upperBpm,
        color: colors[i],
      ),
    );
  }
  return ZoneConfiguration(
    zones: zones,
    method: ZoneMethod.hrrKarvonen,
    reliability: reliability,
    maxHr: maxHr,
  );
}
