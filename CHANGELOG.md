# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-04-16

### Added

- `HealthProfile` input model with age, resting HR, measured max HR, clinician
  cap, beta-blocker flag, heart-condition flag, and custom zone boundaries.
- `CustomZoneBoundary` for supplying explicit per-zone BPM lower bounds.
- `calculateZones(HealthProfile)` with a five-method priority chain:
  1. Custom zones
  2. Clinician cap
  3. HRR / Karvonen
  4. Percent of measured max
  5. Percent of estimated max (220 − age)
- `ZoneConfiguration` result type with zones, method, reliability, and max HR.
- `CalculatedZone` with label, lower/upper bounds, and `0xAARRGGBB` colour.
- `ZoneMethod` and `ZoneReliability` enums.
- Caution mode: beta-blocker and heart-condition flags cap zones at the
  clinician limit and downgrade reliability to `low`.
- Optional `bands`, `labels`, and `colors` parameters on `calculateZones` to
  override the default 5-zone percentage bands and colour palette.
- `currentZoneFromConfig(int bpm, ZoneConfiguration)` for real-time zone lookup.
- `HrReading` value type with `bpm` and `elapsed`.
- `calculateTimeInZones(List<HrReading>, ZoneConfiguration)` returning per-zone
  durations, moderate-or-higher totals, and recovery HR drop.
- `TimeInZoneSummary` and `ZoneDuration` result types.
- Full test suite (63 tests).
- CLI example (`example/hr_zones_example.dart`) demonstrating all five methods
  and time-in-zone analysis.
- GitHub Actions CI workflow (Dart analyze + test on three SDK versions).
- GitHub Actions publish workflow (pub.dev OIDC automated publishing).
