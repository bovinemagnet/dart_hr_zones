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

    test('open upper bound (null) includes arbitrarily high bpm', () {
      const top = CalculatedZone(
        zoneNumber: 5,
        label: 'Zone 5',
        effortLabel: 'Very Hard',
        descriptiveLabel: 'VO\u2082 Max',
        lowerBound: 162,
        color: 0xFFE57373,
      );
      expect(top.containsBpm(162), isTrue);
      expect(top.containsBpm(250), isTrue);
      expect(top.containsBpm(161), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // CalculatedZone equality & string forms
  // -------------------------------------------------------------------------
  group('CalculatedZone equality', () {
    const a = CalculatedZone(
      zoneNumber: 3,
      label: 'Zone 3',
      effortLabel: 'Moderate',
      descriptiveLabel: 'Aerobic',
      lowerBound: 126,
      upperBound: 144,
      color: 0xFFFFD54F,
    );
    const b = CalculatedZone(
      zoneNumber: 3,
      // Different cosmetic fields — equality ignores these.
      label: 'Zone Three',
      effortLabel: 'Tempo',
      descriptiveLabel: 'Custom',
      lowerBound: 126,
      upperBound: 144,
      color: 0xFF000000,
    );
    const c = CalculatedZone(
      zoneNumber: 3,
      label: 'Zone 3',
      effortLabel: 'Moderate',
      descriptiveLabel: 'Aerobic',
      lowerBound: 126,
      upperBound: 145, // differs
      color: 0xFFFFD54F,
    );

    test('equal when zoneNumber + bounds match', () {
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('unequal when upperBound differs', () {
      expect(a, isNot(equals(c)));
    });

    test('toString includes zone number and bounds', () {
      expect(a.toString(), contains('3'));
      expect(a.toString(), contains('126'));
    });
  });

  // -------------------------------------------------------------------------
  // ZoneConfiguration.toString
  // -------------------------------------------------------------------------
  group('ZoneConfiguration.toString', () {
    test('includes method, reliability, maxHr', () {
      const profile = HealthProfile(age: 40);
      final s = calculateZones(profile)!.toString();
      expect(s, contains('percentOfEstimatedMax'));
      expect(s, contains('medium'));
      expect(s, contains('180'));
    });
  });

  // -------------------------------------------------------------------------
  // Assert enforcement — override lists must have exactly 5 entries
  // -------------------------------------------------------------------------
  group('override list length asserts', () {
    const profile = HealthProfile(age: 30);

    test('bands length != 5 throws AssertionError', () {
      expect(
        () => calculateZones(
          profile,
          bands: const [(50.0, 60.0), (60.0, 70.0)],
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('labels length != 5 throws', () {
      expect(
        () => calculateZones(profile, labels: const ['a', 'b', 'c']),
        throwsA(isA<AssertionError>()),
      );
    });

    test('effortLabels length != 5 throws', () {
      expect(
        () => calculateZones(profile, effortLabels: const ['a']),
        throwsA(isA<AssertionError>()),
      );
    });

    test('descriptiveLabels length != 5 throws', () {
      expect(
        () => calculateZones(profile, descriptiveLabels: const ['a']),
        throwsA(isA<AssertionError>()),
      );
    });

    test('colors length != 5 throws', () {
      expect(
        () => calculateZones(profile, colors: const [0xFF000000]),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  // -------------------------------------------------------------------------
  // colors override is applied
  // -------------------------------------------------------------------------
  group('colors override', () {
    test('propagates supplied packed colours', () {
      const colours = <int>[
        0xFF111111,
        0xFF222222,
        0xFF333333,
        0xFF444444,
        0xFF555555,
      ];
      const profile = HealthProfile(age: 40);
      final config = calculateZones(profile, colors: colours)!;
      for (var i = 0; i < 5; i++) {
        expect(config.zones[i].color, colours[i]);
      }
    });
  });

  // -------------------------------------------------------------------------
  // Caution mode falling through to percentOfEstimatedMax (age-only profile)
  // -------------------------------------------------------------------------
  group('Caution mode with only estimated max', () {
    test('age + betaBlocker → percentOfEstimatedMax, low reliability', () {
      const profile = HealthProfile(age: 49, betaBlocker: true);
      final config = calculateZones(profile)!;
      expect(config.method, ZoneMethod.percentOfEstimatedMax);
      expect(config.reliability, ZoneReliability.low);
      expect(config.reason, contains('Caution'));
      expect(config.reason, contains('beta blocker'));
      expect(config.reason, contains('Tanaka'));
    });

    test('age + heartCondition alone also downgrades estimated-max path', () {
      const profile = HealthProfile(age: 55, heartCondition: true);
      final config = calculateZones(profile)!;
      expect(config.method, ZoneMethod.percentOfEstimatedMax);
      expect(config.reliability, ZoneReliability.low);
      expect(config.reason, contains('heart condition'));
    });
  });

  // -------------------------------------------------------------------------
  // Clinician cap reason string never mentions caution, even when flags set
  // -------------------------------------------------------------------------
  group('Clinician cap reason string', () {
    test('reason mentions clinician, not caution, with beta blocker', () {
      const profile = HealthProfile(
        age: 49,
        clinicianMaxHr: 150,
        betaBlocker: true,
      );
      final config = calculateZones(profile)!;
      expect(config.reason, contains('clinician'));
      expect(config.reason, isNot(contains('Caution')));
      expect(config.reason, isNot(contains('beta blocker')));
    });

    test('reason unchanged when both caution flags set', () {
      const profile = HealthProfile(
        clinicianMaxHr: 140,
        betaBlocker: true,
        heartCondition: true,
      );
      final config = calculateZones(profile)!;
      expect(config.reason, 'Using clinician-provided maximum heart rate');
    });
  });

  // -------------------------------------------------------------------------
  // Nes formula end-to-end via calculateZones
  // -------------------------------------------------------------------------
  group('Nes formula through calculateZones', () {
    test('age 30 with Nes → max 192, reason references Nes', () {
      const profile = HealthProfile(age: 30, maxHrFormula: MaxHrFormula.nes);
      final config = calculateZones(profile)!;
      expect(config.maxHr, 192);
      expect(config.reason, contains('Nes'));
    });
  });

  // -------------------------------------------------------------------------
  // Karvonen with fox220 opt-in (age-estimated max)
  // -------------------------------------------------------------------------
  group('Karvonen with fox220', () {
    test('uses 220 − age for max HR in Karvonen formula', () {
      // max = 220 − 40 = 180, HRR = 180 − 60 = 120.
      // zone 1 lower = 120 × 0.50 + 60 = 120.
      const profile = HealthProfile(
        age: 40,
        restingHr: 60,
        maxHrFormula: MaxHrFormula.fox220,
      );
      final config = calculateZones(profile)!;
      expect(config.method, ZoneMethod.hrrKarvonen);
      expect(config.maxHr, 180);
      expect(config.zones[0].lowerBound, 120);
    });
  });

  // -------------------------------------------------------------------------
  // Custom zones expose 0 percents (percentages are not applicable)
  // -------------------------------------------------------------------------
  group('custom zone percentages', () {
    test('lowerPercent and upperPercent are 0 for all custom zones', () {
      const profile = HealthProfile(
        customZones: CustomZoneBoundary(
          zone1Lower: 95,
          zone2Lower: 114,
          zone3Lower: 133,
          zone4Lower: 152,
          zone5Lower: 171,
        ),
      );
      final config = calculateZones(profile)!;
      for (final z in config.zones) {
        expect(z.lowerPercent, 0);
        expect(z.upperPercent, 0);
      }
    });
  });

  // -------------------------------------------------------------------------
  // currentZoneFromConfig at exclusive upper boundary crosses to next zone
  // -------------------------------------------------------------------------
  group('currentZoneFromConfig at zone boundary', () {
    test('bpm at zone N upper bound is in zone N+1 (upper is exclusive)', () {
      // Age 40, Tanaka → max 180. Zone 1 upper = 108, which is zone 2's lower.
      const profile = HealthProfile(age: 40);
      final config = calculateZones(profile)!;
      final boundary = config.zones[0].upperBound!;
      expect(config.zones[1].lowerBound, boundary);
      final zone = currentZoneFromConfig(boundary, config);
      expect(zone?.zoneNumber, 2);
    });
  });
}
