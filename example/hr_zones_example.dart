// Examples intentionally use print for CLI output.
// ignore_for_file: avoid_print

import 'package:hr_zones/hr_zones.dart';

void main() {
  print('=== hr_zones package demo ===\n');

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

  _printSection('Method 2 – Clinician cap');
  const clinicianProfile = HealthProfile(clinicianMaxHr: 160);
  _printConfig(calculateZones(clinicianProfile)!);

  _printSection('Method 3 – HRR/Karvonen (measured max HR)');
  const hrrMeasuredProfile = HealthProfile(measuredMaxHr: 185, restingHr: 60);
  _printConfig(calculateZones(hrrMeasuredProfile)!);

  _printSection('Method 4 – Percent of measured max');
  const measuredMaxProfile = HealthProfile(measuredMaxHr: 185);
  _printConfig(calculateZones(measuredMaxProfile)!);

  _printSection('Method 5a – Percent of estimated max (Tanaka, default)');
  const estimatedProfile = HealthProfile(age: 35);
  _printConfig(calculateZones(estimatedProfile)!);

  _printSection('Method 5b – Percent of estimated max (Fox 220, legacy)');
  const foxProfile = HealthProfile(age: 35, maxHrFormula: MaxHrFormula.fox220);
  _printConfig(calculateZones(foxProfile)!);

  _printSection('Method 6 – LTHR (Friel zones)');
  const frielProfile = HealthProfile(lactateThresholdHr: 160);
  _printConfig(calculateZones(frielProfile)!);

  _printSection('Clinician cap wins over caution mode');
  const cautionProfile = HealthProfile(
    age: 55,
    clinicianMaxHr: 140,
    betaBlocker: true,
  );
  _printConfig(calculateZones(cautionProfile)!);

  _printSection('Time-in-zone analysis (active session, 1 Hz cadence)');
  const timeProfile = HealthProfile(age: 40);
  final zoneConfig = calculateZones(timeProfile)!;

  // Simulate 5 minutes of 1-Hz readings climbing into zone 4 then cooling back.
  final liveReadings = <HrReading>[
    for (var s = 0; s <= 300; s++)
      // ignore: prefer_const_constructors — bpm and seconds vary per iteration
      HrReading(bpm: _bpmAt(s), elapsed: Duration(seconds: s)),
  ];
  _printTime(liveReadings, zoneConfig);

  _printSection('After appending a 60 s post-exercise recovery sample');
  final recoveryReadings = [
    ...liveReadings,
    const HrReading(bpm: 95, elapsed: Duration(seconds: 360)),
  ];
  _printTime(recoveryReadings, zoneConfig);

  _printSection('Current zone lookup');
  for (final bpm in [85, 100, 120, 140, 158, 175]) {
    final zone = currentZoneFromConfig(bpm, zoneConfig);
    final label = zone?.displayLabel ?? '(below zone 1)';
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
  print('Reason: ${config.reason}');
  for (final zone in config.zones) {
    final upper = zone.upperBound != null ? '${zone.upperBound! - 1}' : 'max';
    print('  ${zone.displayLabel.padRight(24)} '
        '${zone.lowerBound}–$upper bpm');
  }
  print('');
}

void _printTime(List<HrReading> readings, ZoneConfiguration config) {
  final summary = calculateTimeInZones(readings, config);
  print('Readings: ${readings.length}');
  print(
    'Recovery HR drop: ${summary.recoveryHrDrop ?? "(no cooldown sample)"}',
  );
  print(
    'Moderate-or-higher: ${summary.moderateOrHigherDuration.inSeconds}s',
  );
  for (final zd in summary.zoneDurations) {
    final secs = zd.duration.inSeconds;
    final bar = '█' * (secs ~/ 5);
    print('  ${zd.zone.displayLabel.padRight(24)} $bar ${secs}s');
  }
  final edwards = calculateEdwardsTrimp(summary);
  final banister = calculateBanisterTrimp(
    readings,
    const HealthProfile(age: 40, restingHr: 60),
  );
  print('Edwards TRIMP: ${edwards.toStringAsFixed(1)}');
  if (banister != null) {
    print('Banister TRIMP (male): ${banister.toStringAsFixed(1)}');
  }
  print('');
}

/// Synthetic ramp: warm-up → zone 4 peak → cool-down over 300 s.
int _bpmAt(int s) {
  if (s < 60) return 90 + s; // 90 → 150
  if (s < 180) return 150 + ((s - 60) * 10 ~/ 120); // 150 → 160
  return 160 - ((s - 180) * 60 ~/ 120); // 160 → 100
}
