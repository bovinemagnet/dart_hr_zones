# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- JSON serialisation across every public value type. `toJson()` and a
  `fromJson` factory are now available on `HealthProfile`,
  `CustomZoneBoundary`, `ZoneConfiguration`, `CalculatedZone`, `HrReading`,
  `TimeInZoneSummary`, `ZoneDuration`, and `BanisterCoefficients`. Uses only
  `dart:convert` (no code generation, zero runtime dependencies); enums are
  serialised by `name`, `Duration`s as integer microseconds, and every type
  round-trips (`fromJson(x.toJson()) == x`).
- Value `==`/`hashCode` on `HealthProfile`, `ZoneConfiguration`,
  `TimeInZoneSummary`, `ZoneDuration`, and `BanisterCoefficients` (previously
  identity-only), underpinning the serialisation round-trip contract.
- `HrReading.isRecoverySample` flag. When set on the final reading,
  `calculateTimeInZones` excludes the preceding cooldown interval from the
  per-zone totals and populates `recoveryHrDrop` deterministically, avoiding
  the misclassification of a late sensor dropout as a recovery measurement.
- `TimeInZoneSummary.belowZone1Duration` surfaces the time whose starting
  reading fell below zone 1, which was previously discarded without being
  reported, so a caller can account for the whole session.

### Changed

- **Breaking:** raised the minimum Dart SDK to `^3.8.0` (was `^3.4.0`) to
  match the `lints: ^6.1.0` dev-dependency, which requires SDK `>=3.8.0`.
  The CI matrix now tests `3.8.0` and `stable`. The previous constraint was
  internally inconsistent and left `dart pub get` unable to resolve on
  3.4.x–3.7.x.
- `calculateZones` now personalises the clinician-cap method with the
  Karvonen/HRR formula when a `restingHr` is available (positive reserve
  against the cap), so the lower zones sit above the resting heart rate
  instead of a flat percentage that could fall below it. `method` remains
  `ZoneMethod.clinicianCap` and reliability remains `high`.
- **Breaking:** `calculateZones` now throws `ArgumentError` when `restingHr`
  is at or above the resolved max HR (an inconsistent profile with no
  heart-rate reserve). Previously it silently fell through to the percentage
  methods and returned nonsensical zones at high/medium reliability.
- `calculateBanisterTrimp` now resolves the maximum heart rate as
  `clinicianMaxHr ?? measuredMaxHr ?? estimatedMaxHr`, so clinician-capped
  profiles get a training-load score instead of `null`.
- Override lists (`bands`/`labels`/`effortLabels`/`descriptiveLabels`/
  `colors`) and `CustomZoneBoundary.labels` now throw `ArgumentError` when
  their length is not exactly 5. The list-length checks were previously
  `assert`s (stripped in release builds); custom labels had no check and
  crashed with a bare `RangeError`.
- `calculateZones` now throws `ArgumentError` when `CustomZoneBoundary`
  lower bounds are not strictly increasing, instead of silently building
  inverted zones that never match any reading.
- Custom zone `labels` are now combined into the UI label as
  `'Zone N – <label>'` (previously the bare label replaced it), and an
  explicit `labels:` argument to `calculateZones` now takes precedence over
  `CustomZoneBoundary.labels` for the combined label.
- `ZoneConfiguration.zones` and `TimeInZoneSummary.zoneDurations` are now
  unmodifiable lists.

### Documentation

- Corrected the `CalculatedZone.upperPercent` contract to note that the
  `ZoneMethod.lthrFriel` top zone can exceed 1.0 (default Friel zone 5 runs
  to 110 % of LTHR).
- Corrected stale worked examples and expected outputs in the Antora docs
  (Edwards TRIMP example, getting-started version pin and output, Åstrand /
  Miller–Faulkner formula values, and method `reason` strings).
- Documented `ZoneConfiguration.maxHr` semantics for custom zones
  (`zone5Lower`), the dual interpretation of the `bands` parameter
  (percent-of-max vs percent-of-LTHR), and the assumed-valid input contract
  on `HealthProfile` and `MaxHrFormula.apply`.

## [0.0.3] - 2026-04-17

### Added

- `.pubignore` file excluding the Antora documentation source
  (`src/docs/`, `antora-playbook.yml`), CI workflows (`.github/`), and
  editor config from the pub.dev archive. Archive size drops from
  roughly 51 KB to 32 KB; consumers no longer download an unused
  AsciiDoc documentation tree.

### Changed

- Commented out the automated `dart pub publish` step in
  `.github/workflows/publish.yaml`. Publishing to pub.dev is now manual
  (`dart pub publish`) until automated publishing from GitHub Actions is
  enabled in the package admin. Tag pushes still run analyze, test, and
  `pub publish --dry-run`.

## [0.0.2] - 2026-04-17

### Added

- Three additional `MaxHrFormula` entries:
  - `gellish2007` — `207 − 0.7 × age` (Gellish et al. 2007).
  - `astrand` — `216.6 − 0.84 × age` (Åstrand 1952).
  - `millerFaulkner` — `217 − 0.85 × age` (Miller, Wallace & Eggert 1993).
- `HealthProfile.lactateThresholdHr` optional input, plus
  `copyWith(..., lactateThresholdHr, clearLactateThresholdHr)` support.
- `ZoneMethod.lthrFriel` — sixth calculation method using Joe Friel's 5-zone
  LTHR-anchored bands. Priority-chain position: after clinician cap, before
  HRR/Karvonen.
- `ZoneConfiguration.maxHr` dartdoc clarifies that for `ZoneMethod.lthrFriel`
  the field holds the LTHR anchor value; method disambiguates semantics.
- New `lib/src/training_load.dart` (exported from `lib/hr_zones.dart`):
  - `calculateEdwardsTrimp(TimeInZoneSummary) → double` — zone-weighted
    training load (Edwards 1993).
  - `calculateBanisterTrimp(readings, profile, {coefficients}) → double?` —
    exponentially-weighted HRR training load (Banister 1991).
  - `BanisterCoefficients` with `male()` / `female()` named constructors and
    a custom constructor for cohort-specific weighting pairs.
- Example CLI exercises every method including LTHR and prints Edwards and
  Banister TRIMP scores alongside the time-in-zone summary.

### Changed

- Shortened the pubspec description to fit pub.dev's 60–180 character limit so
  the package scores full marks for the "Follow Dart file conventions" check.

### Fixed

- Removed the `document_ignores` lint rule from `analysis_options.yaml` so the
  analyzer passes on the Dart 3.4.0 SDK floor; the rule was only added in
  Dart 3.5.

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
- Full test suite (123 tests) covering the zone calculator, health profile,
  time-in-zone calculator, and end-to-end integration pipeline.
- CLI example (`example/hr_zones_example.dart`) demonstrating all five methods
  and time-in-zone analysis.
- GitHub Actions CI workflow (Dart analyze + test on three SDK versions).
- GitHub Actions publish workflow (pub.dev OIDC automated publishing).
