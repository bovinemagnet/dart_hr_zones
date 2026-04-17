import 'package:hr_zones/hr_zones.dart';
import 'package:test/test.dart';

/// Helper to build a [ZoneConfiguration] from a simple age-based profile.
ZoneConfiguration _config({int age = 40}) =>
    calculateZones(HealthProfile(age: age))!;

void main() {
  // -------------------------------------------------------------------------
  // Empty / single-reading edge cases
  // -------------------------------------------------------------------------
  group('calculateTimeInZones — edge cases', () {
    test('empty readings returns zero durations', () {
      final summary = calculateTimeInZones([], _config());
      for (final zd in summary.zoneDurations) {
        expect(zd.duration, Duration.zero);
      }
      expect(summary.moderateOrHigherDuration, Duration.zero);
      expect(summary.recoveryHrDrop, isNull);
    });

    test('single reading returns zero durations and null drop', () {
      final summary = calculateTimeInZones(
        [const HrReading(bpm: 120, elapsed: Duration.zero)],
        _config(),
      );
      expect(
        summary.zoneDurations.every((zd) => zd.duration == Duration.zero),
        isTrue,
      );
      expect(summary.recoveryHrDrop, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // Basic accumulation — Tanaka age 40 → 180 max.
  // Zone 1: 90–108, Zone 2: 108–126, Zone 3: 126–144, Zone 4: 144–162,
  // Zone 5: 162+
  // -------------------------------------------------------------------------
  group('calculateTimeInZones — basic accumulation', () {
    late ZoneConfiguration config;

    setUp(() {
      config = _config();
    });

    test('all time in zone 1', () {
      final readings = [
        const HrReading(bpm: 95, elapsed: Duration.zero),
        const HrReading(bpm: 97, elapsed: Duration(minutes: 5)),
        const HrReading(bpm: 99, elapsed: Duration(minutes: 10)),
      ];
      final summary = calculateTimeInZones(readings, config);
      expect(summary.durationInZone(1), const Duration(minutes: 10));
      expect(summary.durationInZone(2), Duration.zero);
    });

    test('mixed zones', () {
      final readings = [
        const HrReading(bpm: 95, elapsed: Duration.zero),
        const HrReading(bpm: 130, elapsed: Duration(minutes: 5)),
        const HrReading(bpm: 150, elapsed: Duration(minutes: 8)),
        const HrReading(bpm: 100, elapsed: Duration(minutes: 10)),
      ];
      final summary = calculateTimeInZones(readings, config);
      expect(summary.durationInZone(1), const Duration(minutes: 5));
      expect(summary.durationInZone(3), const Duration(minutes: 3));
      expect(summary.durationInZone(4), const Duration(minutes: 2));
    });

    test('moderateOrHigher sums zones 3, 4, 5', () {
      final readings = [
        const HrReading(bpm: 95, elapsed: Duration.zero),
        const HrReading(bpm: 130, elapsed: Duration(minutes: 5)),
        const HrReading(bpm: 150, elapsed: Duration(minutes: 8)),
        const HrReading(bpm: 170, elapsed: Duration(minutes: 10)),
        const HrReading(bpm: 100, elapsed: Duration(minutes: 15)),
      ];
      final summary = calculateTimeInZones(readings, config);
      expect(summary.moderateOrHigherDuration, const Duration(minutes: 10));
    });
  });

  // -------------------------------------------------------------------------
  // Recovery HR drop — cooldown-gap gated
  // -------------------------------------------------------------------------
  group('recoveryHrDrop', () {
    test('populated when last gap ≥ 55s, computed as peak − last', () {
      final readings = [
        const HrReading(bpm: 170, elapsed: Duration.zero),
        const HrReading(bpm: 175, elapsed: Duration(seconds: 10)),
        const HrReading(bpm: 160, elapsed: Duration(seconds: 20)),
        const HrReading(bpm: 120, elapsed: Duration(seconds: 80)),
      ];
      final summary = calculateTimeInZones(readings, _config());
      expect(summary.recoveryHrDrop, 55);
    });

    test('null when last gap < cooldownGap', () {
      final readings = [
        const HrReading(bpm: 170, elapsed: Duration.zero),
        const HrReading(bpm: 160, elapsed: Duration(seconds: 10)),
        const HrReading(bpm: 150, elapsed: Duration(seconds: 15)),
      ];
      final summary = calculateTimeInZones(readings, _config());
      expect(summary.recoveryHrDrop, isNull);
    });

    test('null during active monitoring with fast cadence', () {
      final readings = [
        for (var i = 0; i < 10; i++)
          HrReading(
            bpm: 120 + i,
            elapsed: Duration(seconds: i),
          ),
      ];
      final summary = calculateTimeInZones(readings, _config());
      expect(summary.recoveryHrDrop, isNull);
    });

    test('custom cooldownGap can widen or narrow the heuristic', () {
      final readings = [
        const HrReading(bpm: 170, elapsed: Duration.zero),
        const HrReading(bpm: 150, elapsed: Duration(seconds: 10)),
        const HrReading(bpm: 110, elapsed: Duration(seconds: 40)),
      ];
      final defaultSummary = calculateTimeInZones(readings, _config());
      expect(defaultSummary.recoveryHrDrop, isNull);

      final loose = calculateTimeInZones(
        readings,
        _config(),
        cooldownGap: const Duration(seconds: 20),
      );
      expect(loose.recoveryHrDrop, 60);
    });
  });

  // -------------------------------------------------------------------------
  // Non-increasing elapsed times are skipped
  // -------------------------------------------------------------------------
  group('non-increasing elapsed times', () {
    test('interval with zero duration is ignored', () {
      final readings = [
        const HrReading(bpm: 120, elapsed: Duration.zero),
        const HrReading(bpm: 120, elapsed: Duration.zero),
        const HrReading(bpm: 120, elapsed: Duration(minutes: 5)),
      ];
      final summary = calculateTimeInZones(readings, _config());
      expect(summary.durationInZone(2), const Duration(minutes: 5));
    });
  });

  // -------------------------------------------------------------------------
  // ZoneDuration helper
  // -------------------------------------------------------------------------
  group('TimeInZoneSummary.durationInZone', () {
    test('returns Duration.zero for unknown zone number', () {
      final summary = calculateTimeInZones([], _config());
      expect(summary.durationInZone(99), Duration.zero);
    });
  });

  // -------------------------------------------------------------------------
  // HrReading equality
  // -------------------------------------------------------------------------
  group('HrReading', () {
    test('equality', () {
      const a = HrReading(bpm: 120, elapsed: Duration(minutes: 1));
      const b = HrReading(bpm: 120, elapsed: Duration(minutes: 1));
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality on bpm', () {
      const a = HrReading(bpm: 120, elapsed: Duration(minutes: 1));
      const b = HrReading(bpm: 130, elapsed: Duration(minutes: 1));
      expect(a, isNot(equals(b)));
    });

    test('toString contains bpm', () {
      const r = HrReading(bpm: 145, elapsed: Duration(minutes: 3));
      expect(r.toString(), contains('145'));
    });
  });
}
