// Examples intentionally use print for CLI output.
// ignore_for_file: avoid_print

import 'package:hr_zones/hr_zones.dart';

void main() {
  print('=== hr_zones package demo ===\n');

  // -------------------------------------------------------------------------
  // Method 1: Custom zones (highest priority)
  // -------------------------------------------------------------------------
  _printSection('Method 1 – Custom zones');
  const customProfile = HealthProfile(
    customZones: CustomZoneBoundary(
      zone1Lower: 95,
      zone2Lower: 114,
      zone3Lower: 133,
      zone4Lower: 152,
      zone5Lower: 171,
    ),
  );
  _printConfig(calculateZones(customProfile)!);

  // -------------------------------------------------------------------------
  // Method 2: Clinician-prescribed cap
  // -------------------------------------------------------------------------
  _printSection('Method 2 – Clinician cap');
  const clinicianProfile = HealthProfile(clinicianMaxHr: 160);
  _printConfig(calculateZones(clinicianProfile)!);

  // -------------------------------------------------------------------------
  // Method 3: HRR / Karvonen (measured max)
  // -------------------------------------------------------------------------
  _printSection('Method 3 – HRR/Karvonen (measured max HR)');
  const hrrMeasuredProfile = HealthProfile(measuredMaxHr: 185, restingHr: 60);
  _printConfig(calculateZones(hrrMeasuredProfile)!);

  // -------------------------------------------------------------------------
  // Method 4: Percent of measured max
  // -------------------------------------------------------------------------
  _printSection('Method 4 – Percent of measured max');
  const measuredMaxProfile = HealthProfile(measuredMaxHr: 185);
  _printConfig(calculateZones(measuredMaxProfile)!);

  // -------------------------------------------------------------------------
  // Method 5: Percent of estimated max (220 − age)
  // -------------------------------------------------------------------------
  _printSection('Method 5 – Percent of estimated max (220 − age)');
  const estimatedProfile = HealthProfile(age: 35);
  _printConfig(calculateZones(estimatedProfile)!);

  // -------------------------------------------------------------------------
  // Time-in-zone analysis
  // -------------------------------------------------------------------------
  _printSection('Time-in-zone analysis');
  const config = HealthProfile(age: 40);
  final zoneConfig = calculateZones(config)!;

  final readings = [
    const HrReading(bpm: 95, elapsed: Duration.zero),
    const HrReading(bpm: 112, elapsed: Duration(minutes: 5)),
    const HrReading(bpm: 135, elapsed: Duration(minutes: 10)),
    const HrReading(bpm: 155, elapsed: Duration(minutes: 20)),
    const HrReading(bpm: 170, elapsed: Duration(minutes: 25)),
    const HrReading(bpm: 140, elapsed: Duration(minutes: 30)),
    const HrReading(bpm: 115, elapsed: Duration(minutes: 35)),
    const HrReading(bpm: 95, elapsed: Duration(minutes: 40)),
  ];

  final summary = calculateTimeInZones(readings, zoneConfig);

  print('Readings: ${readings.length}');
  print(
    'Recovery HR drop: ${summary.recoveryHrDrop} bpm '
    '(${readings.first.bpm} → ${readings.last.bpm})',
  );
  print(
    'Moderate-or-higher: ${summary.moderateOrHigherDuration.inMinutes} min',
  );
  print('');

  for (final zd in summary.zoneDurations) {
    final mins = zd.duration.inMinutes;
    final bar = '█' * mins;
    print('  ${zd.zone.label.padRight(28)} $bar ${mins}m');
  }

  // -------------------------------------------------------------------------
  // Current zone lookup
  // -------------------------------------------------------------------------
  _printSection('Current zone lookup');
  for (final bpm in [85, 100, 120, 140, 158, 175]) {
    final zone = currentZoneFromConfig(bpm, zoneConfig);
    final label = zone?.label ?? '(below zone 1)';
    print('  $bpm bpm → $label');
  }
}

void _printSection(String title) {
  print('--- $title ---');
}

void _printConfig(ZoneConfiguration config) {
  print(
    'Method: ${config.method.name}  '
    'Reliability: ${config.reliability.name}  '
    'Max HR: ${config.maxHr} bpm',
  );
  for (final zone in config.zones) {
    final upper = zone.upperBound != null ? '${zone.upperBound! - 1}' : 'max';
    print('  ${zone.label}: ${zone.lowerBound}–$upper bpm');
  }
  print('');
}
