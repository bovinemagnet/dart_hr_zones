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
      expect(summary.zoneDurations.every((zd) => zd.duration == Duration.zero),
          isTrue);
      expect(summary.recoveryHrDrop, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // Basic accumulation
  // -------------------------------------------------------------------------
  group('calculateTimeInZones — basic accumulation', () {
    // Profile: age 40 → estimated max 180.
    // Zone 1: 90–108, Zone 2: 108–126, Zone 3: 126–144, Zone 4: 144–162,
    // Zone 5: 162+  (50/60/70/80/90 % of 180)
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
        const HrReading(bpm: 95, elapsed: Duration.zero), // zone 1 for 5 min
        const HrReading(bpm: 130, elapsed: Duration(minutes: 5)), // zone 3 for 3 min
        const HrReading(bpm: 150, elapsed: Duration(minutes: 8)), // zone 4 for 2 min
        const HrReading(bpm: 100, elapsed: Duration(minutes: 10)),
      ];
      final summary = calculateTimeInZones(readings, config);
      expect(summary.durationInZone(1), const Duration(minutes: 5));
      expect(summary.durationInZone(3), const Duration(minutes: 3));
      expect(summary.durationInZone(4), const Duration(minutes: 2));
    });

    test('moderateOrHigher sums zones 3, 4, 5', () {
      final readings = [
        const HrReading(bpm: 95, elapsed: Duration.zero), // zone 1 for 5 min
        const HrReading(bpm: 130, elapsed: Duration(minutes: 5)), // zone 3 for 3 min
        const HrReading(bpm: 150, elapsed: Duration(minutes: 8)), // zone 4 for 2 min
        const HrReading(bpm: 170, elapsed: Duration(minutes: 10)), // zone 5 for 5 min
        const HrReading(bpm: 100, elapsed: Duration(minutes: 15)),
      ];
      final summary = calculateTimeInZones(readings, config);
      // 3 + 2 + 5 = 10 minutes in zone 3+
      expect(summary.moderateOrHigherDuration, const Duration(minutes: 10));
    });
  });

  // -------------------------------------------------------------------------
  // Recovery HR drop
  // -------------------------------------------------------------------------
  group('recoveryHrDrop', () {
    test('positive when HR decreased', () {
      final readings = [
        const HrReading(bpm: 160, elapsed: Duration.zero),
        const HrReading(bpm: 130, elapsed: Duration(minutes: 2)),
        const HrReading(bpm: 110, elapsed: Duration(minutes: 5)),
      ];
      final summary = calculateTimeInZones(readings, _config());
      expect(summary.recoveryHrDrop, 50); // 160 - 110
    });

    test('negative when HR increased (warm-up scenario)', () {
      final readings = [
        const HrReading(bpm: 80, elapsed: Duration.zero),
        const HrReading(bpm: 160, elapsed: Duration(minutes: 5)),
      ];
      final summary = calculateTimeInZones(readings, _config());
      expect(summary.recoveryHrDrop, -80);
    });

    test('zero when first and last are the same', () {
      final readings = [
        const HrReading(bpm: 120, elapsed: Duration.zero),
        const HrReading(bpm: 130, elapsed: Duration(minutes: 3)),
        const HrReading(bpm: 120, elapsed: Duration(minutes: 6)),
      ];
      final summary = calculateTimeInZones(readings, _config());
      expect(summary.recoveryHrDrop, 0);
    });
  });

  // -------------------------------------------------------------------------
  // Non-increasing elapsed times are skipped
  // -------------------------------------------------------------------------
  group('non-increasing elapsed times', () {
    test('interval with zero duration is ignored', () {
      final readings = [
        const HrReading(bpm: 120, elapsed: Duration.zero),
        const HrReading(bpm: 120, elapsed: Duration.zero), // duplicate timestamp
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
