# hr_zones

[![pub.dev](https://img.shields.io/pub/v/hr_zones.svg)](https://pub.dev/packages/hr_zones)
[![CI](https://github.com/bovinemagnet/dart_hr_zones/actions/workflows/ci.yaml/badge.svg)](https://github.com/bovinemagnet/dart_hr_zones/actions/workflows/ci.yaml)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)

A **pure-Dart** heart rate zone calculator with five calculation methods,
automatic priority selection, reliability grading, and time-in-zone analysis.

Zero runtime dependencies. Works with every Dart target — Flutter, server,
CLI, and web.

---

## Features

| Feature | Details |
|---|---|
| **5 calculation methods** | Custom · Clinician cap · HRR/Karvonen · % of measured max · % of estimated max |
| **Modern max-HR formulas** | Tanaka (default), Fox 220, and Nes — selectable per profile |
| **Priority chain** | Automatically picks the most reliable method the data supports |
| **Reliability grading** | `high` / `medium` / `low` based on input quality and medical flags |
| **Clinician-first safety** | A clinician-prescribed cap overrides caution mode with high reliability |
| **Dual zone labels** | `"Moderate"` + `"Aerobic"` + combined `"Zone 3 – Aerobic"` + `displayLabel` |
| **Cooldown-gated recovery** | Post-exercise HR drop computed only when a real recovery sample exists |
| **Time-in-zone analysis** | Per-zone durations + moderate-or-higher totals |
| **Configurable** | Override bands, combined labels, effort labels, physiological labels, and colours per call |
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
    print('Reason: ${config.reason}');
    for (final zone in config.zones) {
      final upper = zone.upperBound?.toString() ?? 'max';
      print('${zone.displayLabel}: ${zone.lowerBound}–$upper bpm');
    }
  }
}
```

---

## Max-HR formulas

Age-based maximum heart rate is estimated by the `MaxHrFormula` selected on
the profile. The default is **Tanaka**, which is more accurate than the
legacy `220 − age` formula for adults over 40.

| Formula | Expression | Source | Use when |
|---|---|---|---|
| `tanaka` (default) | `208 − 0.7 × age` | Tanaka, Monahan & Seals, 2001 | General adult population — modern consensus |
| `fox220` | `220 − age` | Fox, Naughton & Haskell, 1971 | Legacy compatibility or educational contexts |
| `nes` | `211 − 0.64 × age` | Nes et al., 2013 | Fit adults; large Norwegian-cohort derivation |
| `gellish2007` | `207 − 0.7 × age` | Gellish et al., 2007 | General adult population — alternative to Tanaka |
| `astrand` | `216.6 − 0.84 × age` | Åstrand, 1952 | Historical baseline; steeper age-related decline |
| `millerFaulkner` | `217 − 0.85 × age` | Miller, Wallace & Eggert, 1993 | Mixed cohorts; adjustment of Fox-style formulas |

```dart
// Default — Tanaka
calculateZones(HealthProfile(age: 40));           // maxHr 180

// Opt into Fox 220 for compatibility
calculateZones(HealthProfile(
  age: 40,
  maxHrFormula: MaxHrFormula.fox220,
));                                                // maxHr 180 (same at 40)

// Numeric evaluation
MaxHrFormula.tanaka.apply(30);  // 187
MaxHrFormula.fox220.apply(30);  // 190
MaxHrFormula.nes.apply(30);     // 192
```

---

## Calculation methods

### Priority chain

`calculateZones` walks this priority list and returns the first method that has
sufficient data:

1. **Custom** — if `HealthProfile.customZones` is set.
2. **Clinician cap** — if `clinicianMaxHr` is set. **Authoritative:** wins even
   in caution mode with **high** reliability. The clinician's prescribed cap
   is taken as the definitive maximum.
3. **LTHR (Friel)** — if `lactateThresholdHr` is set. A measured threshold
   value is a stronger anchor than the HRR fallback when one is available.
4. **HRR / Karvonen** — if a max HR (measured or age-estimated) **and**
   `restingHr` are available.
5. **Percent of measured max** — if `measuredMaxHr` is set.
6. **Percent of estimated max** — using `HealthProfile.maxHrFormula` (Tanaka
   by default).

### Method descriptions

#### Custom zones

Explicit BPM lower bounds for each zone, with optional per-zone effort labels.
Reliability: **high**.

```dart
calculateZones(HealthProfile(
  customZones: CustomZoneBoundary(
    zone1Lower: 95, zone2Lower: 114, zone3Lower: 133,
    zone4Lower: 152, zone5Lower: 171,
    labels: ['Marathon', 'Endurance', 'Tempo', 'Threshold', 'VO₂'],
  ),
));
```

#### Clinician cap

Applies the default percentage bands to a prescriber-specified maximum heart
rate. Reliability: **high** (authoritative even with caution flags).

```dart
calculateZones(HealthProfile(clinicianMaxHr: 160));
```

#### LTHR (Friel) method

Anchors zones on a measured lactate threshold heart rate using Joe Friel's
five-zone bands (percentages of LTHR):

| Zone | % of LTHR | Descriptor |
|------|-----------|------------|
| 1 | 0 – 84 % | Recovery |
| 2 | 85 – 89 % | Aerobic |
| 3 | 90 – 94 % | Tempo |
| 4 | 95 – 99 % | Subthreshold |
| 5 | ≥ 100 % | Suprathreshold |

Reliability: **high** (or **low** with caution flags and no clinician cap).

```dart
// From a 30-minute time-trial LTHR test.
calculateZones(HealthProfile(lactateThresholdHr: 160));
// ZoneConfiguration.maxHr holds the LTHR value (160) for this method.
```

#### HRR / Karvonen

```
targetHR = (maxHR − restingHR) × intensity + restingHR
```

Uses the Heart Rate Reserve so zones scale correctly for fit athletes with a
low resting HR. Reliability: **high** (measured max) / **medium** (estimated
max) / **low** (caution mode without clinician cap).

```dart
calculateZones(HealthProfile(measuredMaxHr: 185, restingHr: 60));
```

#### Percent of measured max

Applies the default percentage bands to a measured maximum heart rate.
Reliability: **high** (or **low** with caution flags and no clinician cap).

```dart
calculateZones(HealthProfile(measuredMaxHr: 185));
```

#### Percent of estimated max

Uses `profile.maxHrFormula` (Tanaka by default). Reliability: **medium**
(or **low** with caution flags and no clinician cap).

```dart
calculateZones(HealthProfile(age: 35));
```

---

## Default zone bands

| Zone | % of max HR | Default label | Effort | Descriptor | Default colour |
|------|-------------|---------------|--------|------------|----------------|
| 1 | 50 – 60 % | Zone 1 – Recovery | Easy | Recovery | `0xFF4FC3F7` (light blue) |
| 2 | 60 – 70 % | Zone 2 – Base Fitness | Light | Aerobic | `0xFF81C784` (light green) |
| 3 | 70 – 80 % | Zone 3 – Aerobic | Moderate | Aerobic | `0xFFFFD54F` (amber) |
| 4 | 80 – 90 % | Zone 4 – Lactate Threshold | Hard | Anaerobic | `0xFFFF8A65` (deep orange) |
| 5 | 90 – 100 % | Zone 5 – VO₂ Max | Very Hard | VO₂ Max | `0xFFE57373` (red) |

Each `CalculatedZone` exposes `label`, `effortLabel`, `descriptiveLabel`,
`displayLabel` (`"Moderate (Aerobic)"`), `lowerBound`, nullable `upperBound`
(null for zone 5), `color`, `lowerPercent`, and `upperPercent`.

Override any of these per call:

```dart
calculateZones(
  profile,
  bands: [
    (45.0, 60.0), (60.0, 70.0), (70.0, 80.0),
    (80.0, 90.0), (90.0, 100.0),
  ],
  labels: ['Warm-up', 'Easy', 'Tempo', 'Threshold', 'Max'],
  effortLabels: ['Warm-up', 'Easy', 'Tempo', 'Threshold', 'Max'],
  descriptiveLabels: ['', '', '', '', ''],
  colors: [0xFF4FC3F7, 0xFF81C784, 0xFFFFD54F, 0xFFFF8A65, 0xFFE57373],
);
```

---

## Caution mode

Set `betaBlocker: true` or `heartCondition: true` to flag a caution profile.

- **If a `clinicianMaxHr` is set**, the clinician cap wins with **high**
  reliability — the prescribed cap is the definitive max and caution flags
  do not override the clinician's guidance.
- **If no clinician cap is set**, the chosen method still runs but reliability
  is forced to **low** and `ZoneConfiguration.reason` names the triggering
  flags, inviting the user to obtain a clinician cap.

```dart
calculateZones(HealthProfile(
  age: 55,
  clinicianMaxHr: 130,
  betaBlocker: true,
));
// → method: clinicianCap, reliability: high, maxHr: 130
```

---

## Time-in-zone analysis

```dart
final readings = [
  HrReading(bpm: 95,  elapsed: Duration.zero),
  HrReading(bpm: 130, elapsed: Duration(minutes: 5)),
  HrReading(bpm: 155, elapsed: Duration(minutes: 10)),
  // Append a post-exercise recovery sample (≥ 55 s after the last active sample)
  HrReading(bpm: 110, elapsed: Duration(minutes: 11)),
];

final config = calculateZones(HealthProfile(age: 40))!;
final summary = calculateTimeInZones(readings, config);

print('Moderate or higher: ${summary.moderateOrHigherDuration.inMinutes} min');
print('Recovery HR drop: ${summary.recoveryHrDrop} bpm'); // peak 155 − last 110 = 45

for (final zd in summary.zoneDurations) {
  print('${zd.zone.displayLabel}: ${zd.duration.inMinutes} min');
}
```

**Cooldown-gated recovery drop:** `recoveryHrDrop` is populated only when the
final interval (penultimate → last reading) is at least `cooldownGap` (default
55 s, configurable). During fast-cadence live monitoring the field stays `null`,
so UIs don't need ad-hoc rules to decide whether to display a value. The drop
is computed as `peakBpm − lastBpm`.

```dart
// Custom cooldown window
final summary = calculateTimeInZones(
  readings,
  config,
  cooldownGap: const Duration(seconds: 30),
);
```

---

## Training load

Two standard training-load scores are provided. Both are pure functions — no
new state is added to the result types.

**Edwards TRIMP** (1993) weights each zone's minutes by the zone number and
sums them:

```dart
final summary = calculateTimeInZones(readings, config);
final edwards = calculateEdwardsTrimp(summary);
// 30 minutes in zone 3 → 90
```

**Banister TRIMP** (1991) weights each interval by its HRR fraction with an
exponential term. Coefficients are sex-dependent in the literature; pass
whichever pair matches your cohort:

```dart
final banister = calculateBanisterTrimp(
  readings,
  HealthProfile(age: 40, restingHr: 60),
  coefficients: BanisterCoefficients.female(),
);
// Returns null if restingHr or a resolvable max HR is missing.
```

`BanisterCoefficients` exposes `male()` (a=0.64, b=1.92), `female()`
(a=0.86, b=1.67), and an unnamed constructor for arbitrary values.

---

## Public API

### Functions

| Function | Signature | Description |
|---|---|---|
| `calculateZones` | `(HealthProfile, {bands, labels, effortLabels, descriptiveLabels, colors}) → ZoneConfiguration?` | Calculates zones using the priority chain |
| `currentZoneFromConfig` | `(int bpm, ZoneConfiguration) → CalculatedZone?` | Finds the zone for a given BPM |
| `calculateTimeInZones` | `(List<HrReading>, ZoneConfiguration, {cooldownGap}) → TimeInZoneSummary` | Accumulates time in each zone |
| `calculateEdwardsTrimp` | `(TimeInZoneSummary) → double` | Zone-weighted Edwards (1993) training load |
| `calculateBanisterTrimp` | `(List<HrReading>, HealthProfile, {coefficients}) → double?` | HRR-weighted Banister (1991) training load |

### Classes

- `HealthProfile` — inputs: age, restingHr, measuredMaxHr, clinicianMaxHr, lactateThresholdHr, betaBlocker, heartCondition, customZones, maxHrFormula. Getters: `isCautionMode`, `estimatedMaxHr`. `copyWith` with `clear…` flags.
- `CustomZoneBoundary` — explicit zone1–5 lower bounds plus optional `labels`.
- `ZoneConfiguration` — `zones`, `method`, `reliability`, `maxHr` (holds LTHR for the LTHR method), `reason`.
- `CalculatedZone` — `zoneNumber`, `label`, `effortLabel`, `descriptiveLabel`, `displayLabel`, `lowerBound`, nullable `upperBound`, `color`, `lowerPercent`, `upperPercent`; `containsBpm` helper.
- `HrReading` — `bpm` + `elapsed` with equality and `toString`.
- `TimeInZoneSummary` — `zoneDurations`, `moderateOrHigherDuration`, `recoveryHrDrop`; `durationInZone(int)` helper.
- `ZoneDuration` — per-zone duration pair.
- `ReadingCadence` — exposes `cooldownGap` default constant.
- `BanisterCoefficients` — `a` / `b` pair with `male()` and `female()` named constructors.

### Enums

- `ZoneMethod` — `custom`, `clinicianCap`, `lthrFriel`, `hrrKarvonen`, `percentOfMeasuredMax`, `percentOfEstimatedMax`
- `ZoneReliability` — `high`, `medium`, `low`
- `MaxHrFormula` — `tanaka` (default), `fox220`, `nes`, `gellish2007`, `astrand`, `millerFaulkner`; `.apply(age)` and `.displayName` via `MaxHrFormulaApply`

---

## Installation

```yaml
dependencies:
  hr_zones: ^0.0.2
```

```bash
dart pub get
```

---

## License

[Apache 2.0](LICENSE)
