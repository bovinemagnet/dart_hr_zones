import 'dart:convert';

import 'package:hr_zones/hr_zones.dart';
import 'package:test/test.dart';

/// Round-trips [original] through real JSON text and back.
///
/// Asserts both the issue's contract (`fromJson(x.toJson()) == x`) and
/// full-field fidelity: the re-serialised map must deep-equal the original's,
/// which catches fields that value equality deliberately ignores (e.g.
/// [CalculatedZone]'s cosmetic fields).
T _roundTrip<T>(
  T original,
  Map<String, dynamic> Function(T) toJson,
  T Function(Map<String, dynamic>) fromJson,
) {
  final text = jsonEncode(toJson(original));
  final decodedMap = (jsonDecode(text) as Map).cast<String, dynamic>();
  final restored = fromJson(decodedMap);
  expect(restored, equals(original), reason: 'value equality after round-trip');
  expect(
    toJson(restored),
    equals(toJson(original)),
    reason: 'full-field JSON fidelity after round-trip',
  );
  return restored;
}

void main() {
  group('HrReading', () {
    test('round-trips an active sample', () {
      _roundTrip(
        const HrReading(bpm: 142, elapsed: Duration(minutes: 12, seconds: 30)),
        (r) => r.toJson(),
        HrReading.fromJson,
      );
    });

    test('round-trips a recovery sample', () {
      _roundTrip(
        const HrReading(
          bpm: 96,
          elapsed: Duration(minutes: 40),
          isRecoverySample: true,
        ),
        (r) => r.toJson(),
        HrReading.fromJson,
      );
    });

    test('elapsed is stored losslessly as microseconds', () {
      const reading =
          HrReading(bpm: 100, elapsed: Duration(microseconds: 1234567));
      expect(reading.toJson()['elapsedMicroseconds'], 1234567);
    });
  });

  group('CustomZoneBoundary', () {
    test('round-trips without labels', () {
      _roundTrip(
        const CustomZoneBoundary(
          zone1Lower: 100,
          zone2Lower: 120,
          zone3Lower: 140,
          zone4Lower: 160,
          zone5Lower: 175,
        ),
        (b) => b.toJson(),
        CustomZoneBoundary.fromJson,
      );
    });

    test('round-trips with labels', () {
      _roundTrip(
        const CustomZoneBoundary(
          zone1Lower: 100,
          zone2Lower: 120,
          zone3Lower: 140,
          zone4Lower: 160,
          zone5Lower: 175,
          labels: ['Marathon', 'Endurance', 'Tempo', 'Threshold', 'VO2'],
        ),
        (b) => b.toJson(),
        CustomZoneBoundary.fromJson,
      );
    });
  });

  group('HealthProfile', () {
    test('round-trips a fully-populated profile', () {
      _roundTrip(
        const HealthProfile(
          age: 42,
          restingHr: 55,
          clinicianMaxHr: 175,
          measuredMaxHr: 188,
          lactateThresholdHr: 165,
          betaBlocker: true,
          heartCondition: true,
          customZones: CustomZoneBoundary(
            zone1Lower: 100,
            zone2Lower: 120,
            zone3Lower: 140,
            zone4Lower: 160,
            zone5Lower: 175,
            labels: ['a', 'b', 'c', 'd', 'e'],
          ),
          maxHrFormula: MaxHrFormula.nes,
        ),
        (p) => p.toJson(),
        HealthProfile.fromJson,
      );
    });

    test('round-trips a minimal profile', () {
      _roundTrip(
        const HealthProfile(age: 30),
        (p) => p.toJson(),
        HealthProfile.fromJson,
      );
    });

    test('enum is serialised by name, not ordinal', () {
      expect(
        const HealthProfile(age: 30, maxHrFormula: MaxHrFormula.astrand)
            .toJson()['maxHrFormula'],
        'astrand',
      );
    });

    test('fromJson tolerates an empty map with sensible defaults', () {
      final p = HealthProfile.fromJson(const {});
      expect(p, const HealthProfile());
      expect(p.betaBlocker, isFalse);
      expect(p.maxHrFormula, MaxHrFormula.tanaka);
    });
  });

  group('CalculatedZone', () {
    test('round-trips a bounded zone', () {
      _roundTrip(
        const CalculatedZone(
          zoneNumber: 3,
          label: 'Zone 3 – Aerobic',
          effortLabel: 'Moderate',
          descriptiveLabel: 'Aerobic',
          lowerBound: 126,
          upperBound: 144,
          color: 0xFFFFD54F,
          lowerPercent: 0.7,
          upperPercent: 0.8,
        ),
        (z) => z.toJson(),
        CalculatedZone.fromJson,
      );
    });

    test('round-trips the open-ended top zone', () {
      _roundTrip(
        const CalculatedZone(
          zoneNumber: 5,
          label: 'Zone 5 – VO2 Max',
          effortLabel: 'Very Hard',
          descriptiveLabel: 'VO2 Max',
          lowerBound: 162,
          color: 0xFFEF5350,
          lowerPercent: 0.9,
          upperPercent: 1.1,
        ),
        (z) => z.toJson(),
        CalculatedZone.fromJson,
      );
    });

    test('cosmetic fields survive even though == ignores them', () {
      const zone = CalculatedZone(
        zoneNumber: 2,
        label: 'custom label',
        effortLabel: 'custom effort',
        descriptiveLabel: 'custom desc',
        lowerBound: 108,
        upperBound: 126,
        color: 0xDEADBEEF,
        lowerPercent: 0.6,
        upperPercent: 0.7,
      );
      final restored = CalculatedZone.fromJson(
        (jsonDecode(jsonEncode(zone.toJson())) as Map).cast<String, dynamic>(),
      );
      expect(restored.label, zone.label);
      expect(restored.effortLabel, zone.effortLabel);
      expect(restored.descriptiveLabel, zone.descriptiveLabel);
      expect(restored.color, zone.color);
      expect(restored.lowerPercent, zone.lowerPercent);
      expect(restored.upperPercent, zone.upperPercent);
    });
  });

  group('ZoneConfiguration', () {
    test('round-trips a real calculated configuration', () {
      final config = calculateZones(const HealthProfile(age: 40))!;
      _roundTrip(config, (c) => c.toJson(), ZoneConfiguration.fromJson);
    });

    test('round-trips an LTHR/Friel configuration (upperPercent > 1.0)', () {
      final config = calculateZones(
        const HealthProfile(age: 40, lactateThresholdHr: 160),
      )!;
      _roundTrip(config, (c) => c.toJson(), ZoneConfiguration.fromJson);
    });

    test('method and reliability are serialised by name', () {
      final config = calculateZones(const HealthProfile(age: 40))!;
      final json = config.toJson();
      expect(json['method'], config.method.name);
      expect(json['reliability'], config.reliability.name);
    });
  });

  group('ZoneDuration & TimeInZoneSummary', () {
    // Readings that spend time below zone 1, inside zones, and end with an
    // explicit recovery sample — exercises every field of the summary.
    List<HrReading> readings() => const [
          HrReading(bpm: 70, elapsed: Duration.zero), // below zone 1
          HrReading(bpm: 130, elapsed: Duration(minutes: 5)),
          HrReading(bpm: 165, elapsed: Duration(minutes: 20)),
          HrReading(
            bpm: 100,
            elapsed: Duration(minutes: 22),
            isRecoverySample: true,
          ),
        ];

    test('ZoneDuration round-trips', () {
      final summary =
          calculateTimeInZones(readings(), calculateZones(const HealthProfile(age: 40))!);
      _roundTrip(
        summary.zoneDurations.first,
        (zd) => zd.toJson(),
        ZoneDuration.fromJson,
      );
    });

    test('TimeInZoneSummary round-trips (below-zone-1 + recovery)', () {
      final summary =
          calculateTimeInZones(readings(), calculateZones(const HealthProfile(age: 40))!);
      // Guard: ensure the fixture actually populated the interesting fields.
      expect(summary.belowZone1Duration, greaterThan(Duration.zero));
      expect(summary.recoveryHrDrop, isNotNull);
      _roundTrip(summary, (s) => s.toJson(), TimeInZoneSummary.fromJson);
    });
  });

  group('BanisterCoefficients', () {
    test('round-trips the male preset', () {
      _roundTrip(
        const BanisterCoefficients.male(),
        (c) => c.toJson(),
        BanisterCoefficients.fromJson,
      );
    });

    test('round-trips a custom pair', () {
      _roundTrip(
        const BanisterCoefficients(a: 0.5, b: 1.5),
        (c) => c.toJson(),
        BanisterCoefficients.fromJson,
      );
    });
  });
}
