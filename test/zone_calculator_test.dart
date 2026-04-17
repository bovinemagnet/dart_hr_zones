import 'package:hr_zones/hr_zones.dart';
import 'package:test/test.dart';

void main() {
  // -------------------------------------------------------------------------
  // calculateZones — null when no data
  // -------------------------------------------------------------------------
  group('calculateZones returns null', () {
    test('when HealthProfile is empty', () {
      expect(calculateZones(const HealthProfile()), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // ZoneMethod.custom
  // -------------------------------------------------------------------------
  group('ZoneMethod.custom', () {
    late ZoneConfiguration config;

    setUp(() {
      const profile = HealthProfile(
        customZones: CustomZoneBoundary(
          zone1Lower: 95,
          zone2Lower: 114,
          zone3Lower: 133,
          zone4Lower: 152,
          zone5Lower: 171,
        ),
      );
      config = calculateZones(profile)!;
    });

    test('method is custom', () => expect(config.method, ZoneMethod.custom));

    test('reliability is high', () {
      expect(config.reliability, ZoneReliability.high);
    });

    test('produces 5 zones', () => expect(config.zones, hasLength(5)));

    test('zone 1 lower bound', () => expect(config.zones[0].lowerBound, 95));
    test('zone 2 lower bound', () => expect(config.zones[1].lowerBound, 114));
    test('zone 5 upper bound is null', () {
      expect(config.zones[4].upperBound, isNull);
    });

    test('zone boundaries are contiguous', () {
      for (var i = 0; i < 4; i++) {
        expect(config.zones[i].upperBound, config.zones[i + 1].lowerBound);
      }
    });
  });

  // -------------------------------------------------------------------------
  // ZoneMethod.clinicianCap
  // -------------------------------------------------------------------------
  group('ZoneMethod.clinicianCap', () {
    late ZoneConfiguration config;

    setUp(() {
      const profile = HealthProfile(clinicianMaxHr: 160);
      config = calculateZones(profile)!;
    });

    test('method is clinicianCap', () {
      expect(config.method, ZoneMethod.clinicianCap);
    });

    test('reliability is medium', () {
      expect(config.reliability, ZoneReliability.medium);
    });

    test('maxHr matches clinician cap', () {
      expect(config.maxHr, 160);
    });

    test('zone 1 is 50% of 160 = 80 bpm', () {
      expect(config.zones[0].lowerBound, 80);
    });

    test('zone 5 starts at 90% of 160 = 144 bpm', () {
      expect(config.zones[4].lowerBound, 144);
    });
  });

  // -------------------------------------------------------------------------
  // ZoneMethod.clinicianCap skipped in caution mode
  // -------------------------------------------------------------------------
  group('ZoneMethod.clinicianCap is skipped when caution mode is active', () {
    test('falls through to hrrKarvonen when resting HR available', () {
      const profile = HealthProfile(
        clinicianMaxHr: 150,
        measuredMaxHr: 185,
        restingHr: 60,
        betaBlocker: true,
      );
      final config = calculateZones(profile)!;
      expect(config.method, ZoneMethod.hrrKarvonen);
      expect(config.reliability, ZoneReliability.low);
    });

    test('falls through to percentOfMeasuredMax without resting HR', () {
      const profile = HealthProfile(
        clinicianMaxHr: 150,
        measuredMaxHr: 185,
        heartCondition: true,
      );
      final config = calculateZones(profile)!;
      expect(config.method, ZoneMethod.percentOfMeasuredMax);
      expect(config.reliability, ZoneReliability.low);
    });
  });

  // -------------------------------------------------------------------------
  // ZoneMethod.hrrKarvonen
  // -------------------------------------------------------------------------
  group('ZoneMethod.hrrKarvonen', () {
    late ZoneConfiguration config;

    setUp(() {
      // maxHR = 185 (measured), restingHR = 60, HRR = 125
      // Zone 1 lower = 125 * 0.50 + 60 = 122.5 ≈ 123
      const profile = HealthProfile(measuredMaxHr: 185, restingHr: 60);
      config = calculateZones(profile)!;
    });

    test('method is hrrKarvonen', () {
      expect(config.method, ZoneMethod.hrrKarvonen);
    });

    test('reliability is high (measured max)', () {
      expect(config.reliability, ZoneReliability.high);
    });

    test('zone 1 lower bound uses Karvonen formula', () {
      // (185 - 60) * 0.50 + 60 = 62.5 + 60 = 122.5 -> rounds to 123
      expect(config.zones[0].lowerBound, 123);
    });

    test('zone 3 lower bound', () {
      // (185 - 60) * 0.70 + 60 = 87.5 + 60 = 147.5 -> 148
      expect(config.zones[2].lowerBound, 148);
    });
  });

  group('ZoneMethod.hrrKarvonen with age-based max', () {
    test('reliability is medium (estimated max)', () {
      const profile = HealthProfile(age: 40, restingHr: 60);
      final config = calculateZones(profile)!;
      expect(config.method, ZoneMethod.hrrKarvonen);
      expect(config.reliability, ZoneReliability.medium);
    });
  });

  // -------------------------------------------------------------------------
  // ZoneMethod.percentOfMeasuredMax
  // -------------------------------------------------------------------------
  group('ZoneMethod.percentOfMeasuredMax', () {
    late ZoneConfiguration config;

    setUp(() {
      const profile = HealthProfile(measuredMaxHr: 185);
      config = calculateZones(profile)!;
    });

    test('method is percentOfMeasuredMax', () {
      expect(config.method, ZoneMethod.percentOfMeasuredMax);
    });

    test('reliability is high', () {
      expect(config.reliability, ZoneReliability.high);
    });

    test('zone 1 lower bound is 50% of 185 = 93 bpm', () {
      expect(config.zones[0].lowerBound, (185 * 0.50).round());
    });
  });

  // -------------------------------------------------------------------------
  // ZoneMethod.percentOfEstimatedMax
  // -------------------------------------------------------------------------
  group('ZoneMethod.percentOfEstimatedMax', () {
    late ZoneConfiguration config;

    setUp(() {
      // 220 - 40 = 180 estimated max
      const profile = HealthProfile(age: 40);
      config = calculateZones(profile)!;
    });

    test('method is percentOfEstimatedMax', () {
      expect(config.method, ZoneMethod.percentOfEstimatedMax);
    });

    test('reliability is medium', () {
      expect(config.reliability, ZoneReliability.medium);
    });

    test('maxHr is 180 (220 - 40)', () {
      expect(config.maxHr, 180);
    });

    test('zone 1 lower bound is 50% of 180 = 90', () {
      expect(config.zones[0].lowerBound, 90);
    });
  });

  // -------------------------------------------------------------------------
  // Priority chain
  // -------------------------------------------------------------------------
  group('priority chain', () {
    test('custom beats clinician cap', () {
      const profile = HealthProfile(
        clinicianMaxHr: 160,
        customZones: CustomZoneBoundary(
          zone1Lower: 95,
          zone2Lower: 114,
          zone3Lower: 133,
          zone4Lower: 152,
          zone5Lower: 171,
        ),
      );
      expect(calculateZones(profile)!.method, ZoneMethod.custom);
    });

    test('clinician cap beats hrr when no caution mode', () {
      const profile = HealthProfile(
        clinicianMaxHr: 160,
        measuredMaxHr: 185,
        restingHr: 60,
      );
      expect(calculateZones(profile)!.method, ZoneMethod.clinicianCap);
    });

    test('hrr beats percent-of-measured', () {
      const profile = HealthProfile(measuredMaxHr: 185, restingHr: 60);
      expect(calculateZones(profile)!.method, ZoneMethod.hrrKarvonen);
    });

    test('percent-of-measured beats percent-of-estimated', () {
      const profile = HealthProfile(age: 40, measuredMaxHr: 185);
      expect(calculateZones(profile)!.method, ZoneMethod.percentOfMeasuredMax);
    });
  });

  // -------------------------------------------------------------------------
  // Custom bands override
  // -------------------------------------------------------------------------
  group('custom bands override', () {
    test('accepts 4-zone-equivalent custom bands', () {
      // Using 5 bands but wider zones
      const customBands = [
        (45.0, 60.0),
        (60.0, 70.0),
        (70.0, 80.0),
        (80.0, 90.0),
        (90.0, 100.0),
      ];
      const profile = HealthProfile(age: 40);
      final config = calculateZones(profile, bands: customBands)!;
      // Zone 1 lower = 180 * 0.45 = 81
      expect(config.zones[0].lowerBound, 81);
    });
  });

  // -------------------------------------------------------------------------
  // currentZoneFromConfig
  // -------------------------------------------------------------------------
  group('currentZoneFromConfig', () {
    late ZoneConfiguration config;

    setUp(() {
      const profile = HealthProfile(age: 40); // estimated max 180
      config = calculateZones(profile)!;
    });

    test('returns zone 1 for bpm at lower bound of zone 1', () {
      final zone = currentZoneFromConfig(config.zones[0].lowerBound, config);
      expect(zone?.zoneNumber, 1);
    });

    test('returns zone 3 for a mid-zone 3 bpm', () {
      final z3 = config.zones[2];
      final mid = z3.lowerBound + 2;
      final zone = currentZoneFromConfig(mid, config);
      expect(zone?.zoneNumber, 3);
    });

    test('returns null for bpm below zone 1', () {
      final zone = currentZoneFromConfig(config.zones[0].lowerBound - 10, config);
      expect(zone, isNull);
    });

    test('returns zone 5 for bpm at zone 5 lower bound', () {
      final zone = currentZoneFromConfig(config.zones[4].lowerBound, config);
      expect(zone?.zoneNumber, 5);
    });

    test('returns zone 5 for very high bpm (no upper bound)', () {
      final zone = currentZoneFromConfig(250, config);
      expect(zone?.zoneNumber, 5);
    });
  });

  // -------------------------------------------------------------------------
  // CalculatedZone containsBpm
  // -------------------------------------------------------------------------
  group('CalculatedZone.containsBpm', () {
    const zone = CalculatedZone(
      zoneNumber: 2,
      label: 'Zone 2',
      lowerBound: 100,
      upperBound: 120,
      color: 0xFF81C784,
    );

    test('true at lower bound', () => expect(zone.containsBpm(100), isTrue));
    test('true inside range', () => expect(zone.containsBpm(110), isTrue));
    test('false at upper bound (exclusive)', () {
      expect(zone.containsBpm(120), isFalse);
    });
    test('false below lower', () => expect(zone.containsBpm(99), isFalse));
  });

  // -------------------------------------------------------------------------
  // Caution mode capping
  // -------------------------------------------------------------------------
  group('caution mode', () {
    test('caps estimated max at clinician cap', () {
      // estimated max = 220 - 30 = 190, but cap is 150
      const profile = HealthProfile(
        age: 30,
        clinicianMaxHr: 150,
        betaBlocker: true,
      );
      final config = calculateZones(profile)!;
      expect(config.maxHr, lessThanOrEqualTo(150));
    });

    test('reliability is low in caution mode', () {
      const profile = HealthProfile(
        age: 40,
        heartCondition: true,
      );
      final config = calculateZones(profile)!;
      expect(config.reliability, ZoneReliability.low);
    });
  });
}
