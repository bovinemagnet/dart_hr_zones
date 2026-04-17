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

  /// Lactate-Threshold-Heart-Rate method using Joe Friel's published 5-zone
  /// bands anchored on [HealthProfile.lactateThresholdHr]. Preferred over
  /// max-HR methods for athletes who have a measured threshold value.
  lthrFriel,

  /// Heart-Rate Reserve (Karvonen) method:
  /// `targetHR = (maxHR − restingHR) × intensity + restingHR`.
  /// Requires both a maximum heart rate (measured or estimated) and a resting
  /// heart rate.
  hrrKarvonen,

  /// Percentage-of-measured-maximum method.
  /// Requires [HealthProfile.measuredMaxHr].
  percentOfMeasuredMax,

  /// Percentage-of-estimated-maximum method. Estimates maximum HR from age
  /// using [HealthProfile.maxHrFormula].
  percentOfEstimatedMax,
}

/// The reliability grade for the calculated zone configuration.
enum ZoneReliability {
  /// Based on measured data (measured max HR, explicit custom zones, or a
  /// clinician-prescribed cap).
  high,

  /// Based on estimated data (age-predicted max HR via the configured
  /// formula) without any medical flags.
  medium,

  /// Caution mode is active (beta-blocker or heart condition) and no
  /// clinician cap is available to anchor the calculation.
  low,
}

/// A single calculated heart rate zone.
class CalculatedZone {
  /// Zone number (1 – 5).
  final int zoneNumber;

  /// Combined, UI-friendly label (e.g. `'Zone 1 – Recovery'`). When overridden
  /// via the `labels` parameter of [calculateZones] this reflects the caller's
  /// string verbatim.
  final String label;

  /// Short effort descriptor (e.g. `'Easy'`, `'Moderate'`, `'Hard'`).
  final String effortLabel;

  /// Physiological descriptor (e.g. `'Recovery'`, `'Aerobic'`, `'Anaerobic'`,
  /// `'VO₂ Max'`). For custom zones this is `'Custom'`.
  final String descriptiveLabel;

  /// Lower bound in beats per minute (inclusive).
  final int lowerBound;

  /// Upper bound in beats per minute (exclusive), or `null` for the top zone
  /// (which extends to the configuration's [ZoneConfiguration.maxHr]).
  final int? upperBound;

  /// Zone colour as a packed `0xAARRGGBB` integer.
  final int color;

  /// Lower bound as a fraction of the underlying max / reserve (0.0 – 1.0).
  ///
  /// Zero for [ZoneMethod.custom] zones (percentages are not applicable).
  final double lowerPercent;

  /// Upper bound as a fraction of the underlying max / reserve (0.0 – 1.0).
  ///
  /// Zero for [ZoneMethod.custom] zones (percentages are not applicable).
  final double upperPercent;

  /// Creates a [CalculatedZone].
  const CalculatedZone({
    required this.zoneNumber,
    required this.label,
    required this.effortLabel,
    required this.descriptiveLabel,
    required this.lowerBound,
    this.upperBound,
    required this.color,
    this.lowerPercent = 0,
    this.upperPercent = 0,
  });

  /// Combined "effort (descriptor)" display label, e.g. `'Moderate (Aerobic)'`.
  String get displayLabel => '$effortLabel ($descriptiveLabel)';

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

  /// The anchor heart rate (in bpm) used to compute the zones.
  ///
  /// For max-HR-based methods ([ZoneMethod.clinicianCap],
  /// [ZoneMethod.hrrKarvonen], [ZoneMethod.percentOfMeasuredMax],
  /// [ZoneMethod.percentOfEstimatedMax]) this is the maximum heart rate.
  /// For [ZoneMethod.lthrFriel] this is the lactate-threshold heart rate used
  /// as the band anchor. The `method` field disambiguates which semantic
  /// applies. [CalculatedZone.lowerPercent] / [CalculatedZone.upperPercent]
  /// remain fractions of this value.
  final int maxHr;

  /// Human-readable explanation of why this method and reliability were
  /// selected. Suitable for tooltip / subtitle text in a UI.
  final String reason;

  /// Creates a [ZoneConfiguration].
  const ZoneConfiguration({
    required this.zones,
    required this.method,
    required this.reliability,
    required this.maxHr,
    required this.reason,
  });

  @override
  String toString() =>
      'ZoneConfiguration(method: $method, reliability: $reliability, '
      'maxHr: $maxHr, zones: $zones)';
}

// ---------------------------------------------------------------------------
// Default zone bands, labels and colours
// ---------------------------------------------------------------------------

/// Default percentage bands for the five zones (`(lowerPercent, upperPercent)`
/// as 0–100 values). Zone 5's upper is 100 (max HR).
const List<(double, double)> _defaultBands = [
  (50.0, 60.0), // Zone 1 – Recovery
  (60.0, 70.0), // Zone 2 – Base Fitness
  (70.0, 80.0), // Zone 3 – Aerobic
  (80.0, 90.0), // Zone 4 – Lactate Threshold
  (90.0, 100.0), // Zone 5 – VO₂ Max
];

/// Default Friel 5-zone bands expressed as percentages of the lactate
/// threshold heart rate (LTHR). Zone 5 extends above 100 % of LTHR; the
/// upper value is used to compute `upperPercent` and is not a hard cap.
const List<(double, double)> _defaultFrielBands = [
  (0.0, 85.0), // Zone 1 – Recovery (< 85 % LTHR)
  (85.0, 90.0), // Zone 2 – Aerobic
  (90.0, 95.0), // Zone 3 – Tempo
  (95.0, 100.0), // Zone 4 – Subthreshold
  (100.0, 110.0), // Zone 5 – Suprathreshold (≥ 100 % LTHR)
];

/// Default combined zone labels.
const List<String> _defaultLabels = [
  'Zone 1 – Recovery',
  'Zone 2 – Base Fitness',
  'Zone 3 – Aerobic',
  'Zone 4 – Lactate Threshold',
  'Zone 5 – VO\u2082 Max',
];

/// Default short effort descriptors.
const List<String> _defaultEffortLabels = [
  'Easy',
  'Light',
  'Moderate',
  'Hard',
  'Very Hard',
];

/// Default physiological descriptors.
const List<String> _defaultDescriptiveLabels = [
  'Recovery',
  'Aerobic',
  'Aerobic',
  'Anaerobic',
  'VO\u2082 Max',
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
/// 2. [ZoneMethod.clinicianCap] — if [HealthProfile.clinicianMaxHr] is set.
///    Always wins over the fallback chain; reliability is `high` even in
///    caution mode because the clinician's guidance is authoritative.
/// 3. [ZoneMethod.lthrFriel] — if [HealthProfile.lactateThresholdHr] is set.
///    LTHR is a measured threshold value; when available it anchors zones
///    more accurately than an HRR/Karvonen fallback that may use an
///    age-estimated max.
/// 4. [ZoneMethod.hrrKarvonen] — if both a max HR (measured or estimated) and
///    [HealthProfile.restingHr] are available.
/// 5. [ZoneMethod.percentOfMeasuredMax] — if [HealthProfile.measuredMaxHr]
///    is set.
/// 6. [ZoneMethod.percentOfEstimatedMax] — using
///    [HealthProfile.maxHrFormula] (default Tanaka `208 − 0.7 × age`).
///
/// For max-HR-based methods, [bands] entries are fractions of the resolved
/// max HR. For [ZoneMethod.lthrFriel] they are fractions of LTHR; when
/// omitted, Friel's default 5-zone bands are used.
///
/// Returns `null` if none of the methods can produce zones from the available
/// data.
ZoneConfiguration? calculateZones(
  HealthProfile profile, {
  List<(double, double)>? bands,
  List<String>? labels,
  List<String>? effortLabels,
  List<String>? descriptiveLabels,
  List<int>? colors,
}) {
  final effectiveBands = bands ?? _defaultBands;
  final effectiveFrielBands = bands ?? _defaultFrielBands;
  final effectiveLabels = labels ?? _defaultLabels;
  final effectiveEfforts = effortLabels ?? _defaultEffortLabels;
  final effectiveDescs = descriptiveLabels ?? _defaultDescriptiveLabels;
  final effectiveColors = colors ?? _defaultColors;

  assert(effectiveBands.length == 5, 'bands must have exactly 5 entries');
  assert(effectiveLabels.length == 5, 'labels must have exactly 5 entries');
  assert(
    effectiveEfforts.length == 5,
    'effortLabels must have exactly 5 entries',
  );
  assert(
    effectiveDescs.length == 5,
    'descriptiveLabels must have exactly 5 entries',
  );
  assert(effectiveColors.length == 5, 'colors must have exactly 5 entries');

  // 1. Custom zones
  final custom = profile.customZones;
  if (custom != null) {
    return _customZones(
      custom,
      effectiveLabels,
      effectiveEfforts,
      effectiveColors,
    );
  }

  // 2. Clinician cap — authoritative. Overrides caution mode; reliability is
  // high because the clinician specifically prescribed this cap.
  final clinicianMax = profile.clinicianMaxHr;
  if (clinicianMax != null) {
    return _percentOfMaxZones(
      maxHr: clinicianMax,
      method: ZoneMethod.clinicianCap,
      reliability: ZoneReliability.high,
      reason: 'Using clinician-provided maximum heart rate',
      bands: effectiveBands,
      labels: effectiveLabels,
      efforts: effectiveEfforts,
      descs: effectiveDescs,
      colors: effectiveColors,
    );
  }

  // 3. LTHR (Friel) — anchored on a measured lactate threshold value. Runs
  // below the clinician cap but above HRR/Karvonen: LTHR is measured data
  // whereas Karvonen may be falling back to an age-estimated max.
  final lthr = profile.lactateThresholdHr;
  if (lthr != null) {
    final reliability =
        profile.isCautionMode ? ZoneReliability.low : ZoneReliability.high;
    return _lthrFrielZones(
      lthr: lthr,
      reliability: reliability,
      reason: _reasonFor(profile, ZoneMethod.lthrFriel, reliability),
      bands: effectiveFrielBands,
      labels: effectiveLabels,
      efforts: effectiveEfforts,
      descs: effectiveDescs,
      colors: effectiveColors,
    );
  }

  // Resolve best available max HR for Karvonen and percentage methods.
  final resolvedMax = _resolveMaxHr(profile);

  // 4. HRR / Karvonen
  final restingHr = profile.restingHr;
  if (resolvedMax != null && restingHr != null) {
    final reliability = profile.isCautionMode
        ? ZoneReliability.low
        : _maxHrReliability(profile, resolvedMax);
    return _hrrZones(
      maxHr: resolvedMax,
      restingHr: restingHr,
      reliability: reliability,
      reason: _reasonFor(profile, ZoneMethod.hrrKarvonen, reliability),
      bands: effectiveBands,
      labels: effectiveLabels,
      efforts: effectiveEfforts,
      descs: effectiveDescs,
      colors: effectiveColors,
    );
  }

  // 5. Percent of measured max
  final measuredMax = profile.measuredMaxHr;
  if (measuredMax != null) {
    final reliability =
        profile.isCautionMode ? ZoneReliability.low : ZoneReliability.high;
    return _percentOfMaxZones(
      maxHr: measuredMax,
      method: ZoneMethod.percentOfMeasuredMax,
      reliability: reliability,
      reason: _reasonFor(profile, ZoneMethod.percentOfMeasuredMax, reliability),
      bands: effectiveBands,
      labels: effectiveLabels,
      efforts: effectiveEfforts,
      descs: effectiveDescs,
      colors: effectiveColors,
    );
  }

  // 6. Percent of estimated max (via profile.maxHrFormula)
  final estimated = profile.estimatedMaxHr;
  if (estimated != null) {
    final reliability =
        profile.isCautionMode ? ZoneReliability.low : ZoneReliability.medium;
    return _percentOfMaxZones(
      maxHr: estimated,
      method: ZoneMethod.percentOfEstimatedMax,
      reliability: reliability,
      reason:
          _reasonFor(profile, ZoneMethod.percentOfEstimatedMax, reliability),
      bands: effectiveBands,
      labels: effectiveLabels,
      efforts: effectiveEfforts,
      descs: effectiveDescs,
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

/// Resolves the best max HR available for Karvonen / percentage methods.
/// Measured max takes priority; otherwise falls back to the configured
/// age-based formula. Returns `null` when neither is available.
int? _resolveMaxHr(HealthProfile profile) {
  if (profile.measuredMaxHr != null) return profile.measuredMaxHr;
  return profile.estimatedMaxHr;
}

/// Derives reliability from the type of max HR available (non-caution).
ZoneReliability _maxHrReliability(HealthProfile profile, int resolvedMax) {
  if (profile.measuredMaxHr != null && resolvedMax == profile.measuredMaxHr) {
    return ZoneReliability.high;
  }
  return ZoneReliability.medium;
}

/// Builds the reason string for non-custom / non-clinician methods.
String _reasonFor(
  HealthProfile profile,
  ZoneMethod method,
  ZoneReliability reliability,
) {
  final baseReason = switch (method) {
    ZoneMethod.hrrKarvonen => 'Using heart rate reserve (Karvonen) method',
    ZoneMethod.percentOfMeasuredMax => 'Using measured maximum heart rate',
    ZoneMethod.percentOfEstimatedMax =>
      'Using age-estimated maximum heart rate '
          '(${profile.maxHrFormula.displayName})',
    ZoneMethod.custom => 'Using custom zone boundaries',
    ZoneMethod.clinicianCap => 'Using clinician-provided maximum heart rate',
    ZoneMethod.lthrFriel => 'Using lactate threshold heart rate (Friel) method',
  };

  if (reliability != ZoneReliability.low) return baseReason;

  final flags = <String>[];
  if (profile.betaBlocker) flags.add('beta blocker medication');
  if (profile.heartCondition) flags.add('heart condition');
  final flagsText = flags.isEmpty ? '' : ' (${flags.join(' and ')} reported)';
  return 'Caution mode$flagsText. $baseReason. '
      'Consider setting a clinician-provided maximum heart rate.';
}

ZoneConfiguration _customZones(
  CustomZoneBoundary custom,
  List<String> labels,
  List<String> efforts,
  List<int> colors,
) {
  final lowers = [
    custom.zone1Lower,
    custom.zone2Lower,
    custom.zone3Lower,
    custom.zone4Lower,
    custom.zone5Lower,
  ];
  final customLabels = custom.labels;

  final zones = <CalculatedZone>[];
  for (var i = 0; i < 5; i++) {
    final effort = customLabels != null ? customLabels[i] : efforts[i];
    final label = customLabels != null ? customLabels[i] : labels[i];
    zones.add(
      CalculatedZone(
        zoneNumber: i + 1,
        label: label,
        effortLabel: effort,
        descriptiveLabel: 'Custom',
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
    reason: 'Using custom zone boundaries',
  );
}

ZoneConfiguration _percentOfMaxZones({
  required int maxHr,
  required ZoneMethod method,
  required ZoneReliability reliability,
  required String reason,
  required List<(double, double)> bands,
  required List<String> labels,
  required List<String> efforts,
  required List<String> descs,
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
        effortLabel: efforts[i],
        descriptiveLabel: descs[i],
        lowerBound: lowerBpm,
        upperBound: upperBpm,
        color: colors[i],
        lowerPercent: lower / 100,
        upperPercent: upper / 100,
      ),
    );
  }
  return ZoneConfiguration(
    zones: zones,
    method: method,
    reliability: reliability,
    maxHr: maxHr,
    reason: reason,
  );
}

ZoneConfiguration _hrrZones({
  required int maxHr,
  required int restingHr,
  required ZoneReliability reliability,
  required String reason,
  required List<(double, double)> bands,
  required List<String> labels,
  required List<String> efforts,
  required List<String> descs,
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
        effortLabel: efforts[i],
        descriptiveLabel: descs[i],
        lowerBound: lowerBpm,
        upperBound: upperBpm,
        color: colors[i],
        lowerPercent: lower / 100,
        upperPercent: upper / 100,
      ),
    );
  }
  return ZoneConfiguration(
    zones: zones,
    method: ZoneMethod.hrrKarvonen,
    reliability: reliability,
    maxHr: maxHr,
    reason: reason,
  );
}

ZoneConfiguration _lthrFrielZones({
  required int lthr,
  required ZoneReliability reliability,
  required String reason,
  required List<(double, double)> bands,
  required List<String> labels,
  required List<String> efforts,
  required List<String> descs,
  required List<int> colors,
}) {
  final zones = <CalculatedZone>[];
  for (var i = 0; i < 5; i++) {
    final (lower, upper) = bands[i];
    final lowerBpm = (lthr * lower / 100).round();
    final upperBpm = i < 4 ? (lthr * upper / 100).round() : null;
    zones.add(
      CalculatedZone(
        zoneNumber: i + 1,
        label: labels[i],
        effortLabel: efforts[i],
        descriptiveLabel: descs[i],
        lowerBound: lowerBpm,
        upperBound: upperBpm,
        color: colors[i],
        lowerPercent: lower / 100,
        upperPercent: upper / 100,
      ),
    );
  }
  return ZoneConfiguration(
    zones: zones,
    method: ZoneMethod.lthrFriel,
    reliability: reliability,
    maxHr: lthr,
    reason: reason,
  );
}
