/// Heart rate zone calculation for Dart and Flutter apps.
///
/// The package provides five calculation methods — custom zones, clinician cap,
/// HRR/Karvonen, percent-of-measured-max, and percent-of-estimated-max — with
/// automatic priority selection, reliability grading, and time-in-zone analysis.
///
/// ## Quick start
///
/// ```dart
/// import 'package:hr_zones/hr_zones.dart';
///
/// void main() {
///   final profile = HealthProfile(age: 35, restingHr: 60);
///   final config = calculateZones(profile);
///   if (config != null) {
///     for (final zone in config.zones) {
///       print('${zone.label}: ${zone.lowerBound}–'
///           '${zone.upperBound ?? 'max'} bpm');
///     }
///   }
/// }
/// ```
library;

export 'src/health_profile.dart'
    show CustomZoneBoundary, HealthProfile, MaxHrFormula, MaxHrFormulaApply;
export 'src/hr_reading.dart' show HrReading;
export 'src/time_in_zone_calculator.dart'
    show ReadingCadence, TimeInZoneSummary, ZoneDuration, calculateTimeInZones;
export 'src/training_load.dart'
    show BanisterCoefficients, calculateBanisterTrimp, calculateEdwardsTrimp;
export 'src/zone_calculator.dart'
    show
        CalculatedZone,
        ZoneConfiguration,
        ZoneMethod,
        ZoneReliability,
        calculateZones,
        currentZoneFromConfig;
