# hr_zones

[![pub.dev](https://img.shields.io/pub/v/hr_zones.svg)](https://pub.dev/packages/hr_zones)
[![CI](https://github.com/bovinemagnet/dart_hr_zones/actions/workflows/ci.yaml/badge.svg)](https://github.com/bovinemagnet/dart_hr_zones/actions/workflows/ci.yaml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A **pure-Dart** heart rate zone calculator with five calculation methods,
automatic priority selection, reliability grading, and time-in-zone analysis.

Zero runtime dependencies. Works with every Dart target — Flutter, server,
CLI, and web.

---

## Features

| Feature | Details |
|---|---|
| **5 calculation methods** | Custom · Clinician cap · HRR/Karvonen · % of measured max · % of estimated max |
| **Priority chain** | Automatically selects the most appropriate method from the data available |
| **Reliability grading** | `high` / `medium` / `low` based on input quality and medical flags |
| **Caution mode** | Beta-blocker & heart-condition flags cap zones at the clinician limit |
| **Time-in-zone analysis** | Per-zone durations, moderate-or-higher totals, recovery HR drop |
| **Configurable** | Override zone bands, labels, and colours per call |
| **No platform code** | Pure Dart — no `dart:ui`, no Flutter, no platform channels |

---

## Quick start

```dart
import 'package:hr_zones/hr_zones.dart';

void main() {
  final profile = HealthProfile(age: 35, restingHr: 60);
  final config = calculateZones(profile);

  if (config != null) {
    print('Method: ${config.method.name}');
    print('Reliability: ${config.reliability.name}');
    for (final zone in config.zones) {
      final upper = zone.upperBound != null ? '${zone.upperBound}' : 'max';
      print('${zone.label}: ${zone.lowerBound}–$upper bpm');
    }
  }
}
```

---

## Calculation methods

### Priority chain

`calculateZones` walks this priority list and returns the first method that has
sufficient data:

1. **Custom** — if `HealthProfile.customZones` is set.
2. **Clinician cap** — if `clinicianMaxHr` is set and caution mode is **off**.
3. **HRR / Karvonen** — if a max HR (measured or estimated) **and** `restingHr`
   are available.
4. **Percent of measured max** — if `measuredMaxHr` is set.
5. **Percent of estimated max** — `220 − age`.

### Method descriptions

#### Custom zones

The user or a clinician supplies explicit BPM lower bounds for each zone.
Reliability: **high**.

```dart
calculateZones(HealthProfile(
  customZones: CustomZoneBoundary(
    zone1Lower: 95, zone2Lower: 114, zone3Lower: 133,
    zone4Lower: 152, zone5Lower: 171,
  ),
));
```

#### Clinician cap

Applies the default percentage bands to a prescriber-specified maximum heart
rate. Skipped when caution mode is active.
Reliability: **medium**.

```dart
calculateZones(HealthProfile(clinicianMaxHr: 160));
```

#### HRR / Karvonen

```
targetHR = (maxHR − restingHR) × intensity + restingHR
```

Uses the Heart Rate Reserve so zones scale correctly for fit athletes with a
low resting HR.
Reliability: **high** (measured max) / **medium** (estimated max).

```dart
calculateZones(HealthProfile(measuredMaxHr: 185, restingHr: 60));
```

#### Percent of measured max

Applies the default percentage bands to a measured maximum heart rate.
Reliability: **high**.

```dart
calculateZones(HealthProfile(measuredMaxHr: 185));
```

#### Percent of estimated max

Estimates maximum HR as `220 − age` and applies the default percentage bands.
Reliability: **medium**.

```dart
calculateZones(HealthProfile(age: 35));
```

---

## Default zone bands

| Zone | % of max HR | Default label | Default colour |
|------|-------------|---------------|----------------|
| 1 | 50 – 60 % | Zone 1 – Recovery | `0xFF4FC3F7` (light blue) |
| 2 | 60 – 70 % | Zone 2 – Base Fitness | `0xFF81C784` (light green) |
| 3 | 70 – 80 % | Zone 3 – Aerobic | `0xFFFFD54F` (amber) |
| 4 | 80 – 90 % | Zone 4 – Lactate Threshold | `0xFFFF8A65` (deep orange) |
| 5 | 90 – 100 % | Zone 5 – VO₂ Max | `0xFFE57373` (red) |

Override the bands, labels, and colours per call:

```dart
calculateZones(
  profile,
  bands: [
    (45.0, 60.0), (60.0, 70.0), (70.0, 80.0),
    (80.0, 90.0), (90.0, 100.0),
  ],
  labels: ['Warm-up', 'Easy', 'Tempo', 'Threshold', 'Max'],
  colors: [0xFF4FC3F7, 0xFF81C784, 0xFFFFD54F, 0xFFFF8A65, 0xFFE57373],
);
```

---

## Caution mode

Set `betaBlocker: true` or `heartCondition: true` to activate caution mode.
In caution mode:

- The clinician cap method is skipped (falls through to Karvonen or % methods).
- If a `clinicianMaxHr` is present and the computed max HR would exceed it,
  the clinician cap is applied.
- Reliability is always downgraded to **low**.

```dart
calculateZones(HealthProfile(
  age: 55,
  clinicianMaxHr: 130,
  betaBlocker: true,
));
```

---

## Time-in-zone analysis

```dart
final readings = [
  HrReading(bpm: 95,  elapsed: Duration.zero),
  HrReading(bpm: 130, elapsed: Duration(minutes: 5)),
  HrReading(bpm: 155, elapsed: Duration(minutes: 10)),
  HrReading(bpm: 110, elapsed: Duration(minutes: 15)),
];

final config = calculateZones(HealthProfile(age: 40))!;
final summary = calculateTimeInZones(readings, config);

print('Moderate or higher: ${summary.moderateOrHigherDuration.inMinutes} min');
print('Recovery HR drop: ${summary.recoveryHrDrop} bpm');

for (final zd in summary.zoneDurations) {
  print('${zd.zone.label}: ${zd.duration.inMinutes} min');
}
```

---

## Public API

### Functions

| Function | Signature | Description |
|---|---|---|
| `calculateZones` | `(HealthProfile, {bands, labels, colors}) → ZoneConfiguration?` | Calculates zones using the priority chain |
| `currentZoneFromConfig` | `(int bpm, ZoneConfiguration) → CalculatedZone?` | Finds the zone for a given BPM |
| `calculateTimeInZones` | `(List<HrReading>, ZoneConfiguration) → TimeInZoneSummary` | Accumulates time in each zone |

### Classes

- `HealthProfile` — input model with all zone-calculation parameters
- `CustomZoneBoundary` — explicit BPM lower bounds for each zone
- `ZoneConfiguration` — result with zones, method, reliability, and max HR
- `CalculatedZone` — a single zone with label, bounds, and colour
- `HrReading` — a BPM sample with elapsed time
- `TimeInZoneSummary` — per-zone durations and recovery HR drop

### Enums

- `ZoneMethod` — `custom`, `clinicianCap`, `hrrKarvonen`, `percentOfMeasuredMax`, `percentOfEstimatedMax`
- `ZoneReliability` — `high`, `medium`, `low`

---

## Installation

```yaml
dependencies:
  hr_zones: ^0.0.1
```

```bash
dart pub get
```

---

## License

[MIT](LICENSE)
