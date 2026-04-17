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

    test('reason explains custom zones', () {
      expect(config.reason, contains('custom'));
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

    test('custom zones have descriptiveLabel = "Custom"', () {
      expect(config.zones.every((z) => z.descriptiveLabel == 'Custom'), isTrue);
    });

    test('custom labels override effortLabel', () {
      const profile = HealthProfile(
        customZones: CustomZoneBoundary(
          zone1Lower: 95,
          zone2Lower: 114,
          zone3Lower: 133,
          zone4Lower: 152,
          zone5Lower: 171,
          labels: ['Marathon', 'Endurance', 'Tempo', 'Threshold', 'VO₂'],
        ),
      );
      final customConfig = calculateZones(profile)!;
      expect(customConfig.zones.first.effortLabel, 'Marathon');
      expect(customConfig.zones.first.label, 'Marathon');
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

    test('reliability is high', () {
      expect(config.reliability, ZoneReliability.high);
    });

    test('maxHr matches clinician cap', () {
      expect(config.maxHr, 160);
    });

    test('reason mentions clinician', () {
      expect(config.reason, contains('clinician'));
    });

    test('zone 1 is 50% of 160 = 80 bpm', () {
      expect(config.zones[0].lowerBound, 80);
    });

    test('zone 5 starts at 90% of 160 = 144 bpm', () {
      expect(config.zones[4].lowerBound, 144);
    });

    test('percents populated', () {
      expect(config.zones[0].lowerPercent, 0.5);
      expect(config.zones[0].upperPercent, 0.6);
    });
  });

  // -------------------------------------------------------------------------
  // Clinician cap overrides caution mode (clinician wins)
  // -------------------------------------------------------------------------
  group('Clinician cap overrides caution mode', () {
    test('betaBlocker + clinician cap → clinicianCap, high reliability', () {
      const profile = HealthProfile(
        age: 49,
        restingHr: 60,
        clinicianMaxHr: 150,
        betaBlocker: true,
      );
      final config = calculateZones(profile)!;
      expect(config.method, ZoneMethod.clinicianCap);
      expect(config.reliability, ZoneReliability.high);
      expect(config.maxHr, 150);
    });

    test('heartCondition + clinician cap → clinicianCap, high', () {
      const profile = HealthProfile(
        age: 55,
        clinicianMaxHr: 140,
        heartCondition: true,
      );
      final config = calculateZones(profile)!;
      expect(config.method, ZoneMethod.clinicianCap);
      expect(config.reliability, ZoneReliability.high);
    });
  });

  // -------------------------------------------------------------------------
  // Caution mode without clinician cap → low reliability
  // -------------------------------------------------------------------------
  group('Caution mode without clinician cap', () {
    test('falls through to hrrKarvonen with low reliability', () {
      const profile = HealthProfile(
        age: 49,
        restingHr: 60,
        betaBlocker: true,
      );
      final config = calculateZones(profile)!;
      expect(config.method, ZoneMethod.hrrKarvonen);
      expect(config.reliability, ZoneReliability.low);
      expect(config.reason, contains('Caution'));
      expect(config.reason, contains('beta blocker'));
    });

    test('falls through to percentOfMeasuredMax with low reliability', () {
      const profile = HealthProfile(
        measuredMaxHr: 185,
        heartCondition: true,
      );
      final config = calculateZones(profile)!;
      expect(config.method, ZoneMethod.percentOfMeasuredMax);
      expect(config.reliability, ZoneReliability.low);
      expect(config.reason, contains('heart condition'));
    });

    test('reason lists both flags when both set', () {
      const profile = HealthProfile(
        age: 40,
        betaBlocker: true,
        heartCondition: true,
      );
      final config = calculateZones(profile)!;
      expect(config.reason, contains('beta blocker'));
      expect(config.reason, contains('heart condition'));
    });
  });

  // -------------------------------------------------------------------------
  // ZoneMethod.hrrKarvonen
  // -------------------------------------------------------------------------
  group('ZoneMethod.hrrKarvonen', () {
    late ZoneConfiguration config;

    setUp(() {
      // maxHR = 185 (measured), restingHR = 60, HRR = 125
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
      // (185 - 60) * 0.50 + 60 = 62.5 + 60 = 122.5 -> 123
      expect(config.zones[0].lowerBound, 123);
    });

    test('zone 3 lower bound', () {
      // (185 - 60) * 0.70 + 60 = 87.5 + 60 = 147.5 -> 148
      expect(config.zones[2].lowerBound, 148);
    });
  });

  group('ZoneMethod.hrrKarvonen with age-based max', () {
    test('reliability is medium (estimated via Tanaka)', () {
      const profile = HealthProfile(age: 40, restingHr: 60);
      final config = calculateZones(profile)!;
      expect(config.method, ZoneMethod.hrrKarvonen);
      expect(config.reliability, ZoneReliability.medium);
      expect(config.maxHr, 180);
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

    test('zone 1 lower bound is 50% of 185', () {
      expect(config.zones[0].lowerBound, (185 * 0.50).round());
    });
  });

  // -------------------------------------------------------------------------
  // ZoneMethod.percentOfEstimatedMax — Tanaka by default
  // -------------------------------------------------------------------------
  group('ZoneMethod.percentOfEstimatedMax (Tanaka default)', () {
    test('age 40 → Tanaka max 180', () {
      const profile = HealthProfile(age: 40);
      final config = calculateZones(profile)!;
      expect(config.method, ZoneMethod.percentOfEstimatedMax);
      expect(config.reliability, ZoneReliability.medium);
      expect(config.maxHr, 180);
    });

    test('age 30 → Tanaka max 187 (differs from Fox 190)', () {
      const profile = HealthProfile(age: 30);
      final config = calculateZones(profile)!;
      expect(config.maxHr, 187);
    });

    test('reason references Tanaka formula', () {
      const profile = HealthProfile(age: 30);
      final config = calculateZones(profile)!;
      expect(config.reason, contains('Tanaka'));
    });

    test('fox220 opt-in yields 220 − age', () {
      const profile = HealthProfile(age: 30, maxHrFormula: MaxHrFormula.fox220);
      final config = calculateZones(profile)!;
      expect(config.maxHr, 190);
      expect(config.reason, contains('Fox'));
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

    test('clinician cap beats hrr', () {
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
  // Label overrides
  // -------------------------------------------------------------------------
  group('label overrides', () {
    test('default labels include "Zone 1 – Recovery"', () {
      const profile = HealthProfile(age: 30);
      final config = calculateZones(profile)!;
      expect(config.zones[0].label, 'Zone 1 – Recovery');
    });

    test('default effortLabels include "Moderate" at zone 3', () {
      const profile = HealthProfile(age: 30);
      final config = calculateZones(profile)!;
      expect(config.zones[2].effortLabel, 'Moderate');
      expect(config.zones[2].descriptiveLabel, 'Aerobic');
      expect(config.zones[2].displayLabel, 'Moderate (Aerobic)');
    });

    test('labels parameter overrides combined labels only', () {
      const profile = HealthProfile(age: 30);
      final config = calculateZones(
        profile,
        labels: ['Z1', 'Z2', 'Z3', 'Z4', 'Z5'],
      )!;
      expect(config.zones[0].label, 'Z1');
      expect(config.zones[0].effortLabel, 'Easy');
    });

    test('effortLabels and descriptiveLabels overrides', () {
      const profile = HealthProfile(age: 30);
      final config = calculateZones(
        profile,
        effortLabels: ['a', 'b', 'c', 'd', 'e'],
        descriptiveLabels: ['v', 'w', 'x', 'y', 'z'],
      )!;
      expect(config.zones[0].effortLabel, 'a');
      expect(config.zones[0].descriptiveLabel, 'v');
      expect(config.zones[0].displayLabel, 'a (v)');
    });
  });

  // -------------------------------------------------------------------------
  // Custom bands override
  // -------------------------------------------------------------------------
  group('custom bands override', () {
    test('accepts wider bands', () {
      const customBands = [
        (45.0, 60.0),
        (60.0, 70.0),
        (70.0, 80.0),
        (80.0, 90.0),
        (90.0, 100.0),
      ];
      const profile = HealthProfile(age: 40);
      final config = calculateZones(profile, bands: customBands)!;
      expect(config.zones[0].lowerBound, 81);
      expect(config.zones[0].lowerPercent, 0.45);
    });
  });

  // -------------------------------------------------------------------------
  // currentZoneFromConfig
  // -------------------------------------------------------------------------
  group('currentZoneFromConfig', () {
    late ZoneConfiguration config;

    setUp(() {
      const profile = HealthProfile(age: 40);
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
      final zone =
          currentZoneFromConfig(config.zones[0].lowerBound - 10, config);
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
      effortLabel: 'Light',
      descriptiveLabel: 'Aerobic',
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
}
