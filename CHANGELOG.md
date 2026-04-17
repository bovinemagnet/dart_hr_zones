# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.1] - 2026-04-17

### Added

- `HealthProfile` input model with age, resting HR, measured max HR, clinician
  cap, beta-blocker flag, heart-condition flag, custom zone boundaries, and
  pluggable max-HR formula.
- `HealthProfile.estimatedMaxHr` and `HealthProfile.copyWith`.
- `MaxHrFormula` enum with three age-based formulas:
  - `tanaka` — `208 − 0.7 × age` (Tanaka, Monahan & Seals 2001). Default.
  - `fox220` — `220 − age` (Fox, Naughton & Haskell 1971). Legacy.
  - `nes` — `211 − 0.64 × age` (Nes et al. 2013).
- `CustomZoneBoundary` for explicit 5-zone BPM lower bounds, with optional
  per-zone effort labels.
- `calculateZones(HealthProfile, {bands, labels, effortLabels, descriptiveLabels, colors})`
  with a five-method priority chain:
  1. Custom zones
  2. Clinician cap — authoritative; wins over caution mode with high reliability
  3. HRR / Karvonen
  4. Percent of measured max
  5. Percent of estimated max (via the profile's `maxHrFormula`)
- `ZoneConfiguration` result type with zones, method, reliability, `maxHr`,
  and a human-readable `reason` string suitable for tooltips.
- `CalculatedZone` with zone number, combined `label`, short `effortLabel`,
  physiological `descriptiveLabel`, `displayLabel` getter (`"Moderate (Aerobic)"`),
  `lowerBound`, nullable `upperBound`, `lowerPercent`, `upperPercent`, and
  `0xAARRGGBB` colour.
- `ZoneMethod` and `ZoneReliability` enums.
- Caution mode: beta-blocker and heart-condition flags downgrade reliability to
  `low` *unless* a clinician cap is present (which takes precedence).
- `currentZoneFromConfig(int bpm, ZoneConfiguration)` for real-time zone lookup.
- `HrReading` value type with `bpm`, `elapsed`, equality, and `toString`.
- `calculateTimeInZones(List<HrReading>, ZoneConfiguration, {cooldownGap})`
  returning per-zone durations, moderate-or-higher totals, and cooldown-gated
  recovery HR drop (peak − last, only when the final gap ≥ `cooldownGap`,
  default 55 s).
- `TimeInZoneSummary` with `zoneDurations`, `moderateOrHigherDuration`,
  `recoveryHrDrop`, and `durationInZone(int)` helper.
- `ReadingCadence.cooldownGap` default constant.
- Full test suite (86 tests).
- CLI example (`example/hr_zones_example.dart`) demonstrating all five methods
  and time-in-zone analysis.
- GitHub Actions CI workflow (Dart analyze + test on three SDK versions).
- GitHub Actions publish workflow (pub.dev OIDC automated publishing).
