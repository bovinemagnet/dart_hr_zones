// Integration tests exercising the full pipeline:
// HealthProfile → calculateZones → calculateTimeInZones and
// currentZoneFromConfig. These complement the unit tests in the sibling
// _test.dart files, which cover each piece in isolation.
import 'package:hr_zones/hr_zones.dart';
import 'package:test/test.dart';

void main() {
  // -------------------------------------------------------------------------
  // Custom zones flow through to time-in-zone attribution
  // -------------------------------------------------------------------------
  group('custom zones → time-in-zone', () {
    test('intervals are attributed to custom boundaries, not defaults', () {
      // Custom boundaries deliberately diverge from the defaults a 40-year-old
      // would receive (Tanaka max 180 → zone 1 starts at 90). Here zone 1
      // starts at 95 and zone 2 at 114, so a 100 bpm reading lands in zone 1
      // instead of zone 2, which is where it would sit under defaults.
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
      expect(config.method, ZoneMethod.custom);

      final readings = [
        const HrReading(bpm: 100, elapsed: Duration.zero),
        const HrReading(bpm: 120, elapsed: Duration(minutes: 5)),
        const HrReading(bpm: 140, elapsed: Duration(minutes: 10)),
      ];
      final summary = calculateTimeInZones(readings, config);
      expect(summary.durationInZone(1), const Duration(minutes: 5));
      expect(summary.durationInZone(2), const Duration(minutes: 5));
      expect(summary.durationInZone(3), Duration.zero);
    });
  });

  // -------------------------------------------------------------------------
  // Caution-mode end-to-end
  // -------------------------------------------------------------------------
  group('caution-mode pipeline', () {
    test(
        'beta-blocker profile produces low-reliability config that still '
        'drives a coherent time-in-zone summary', () {
      const profile = HealthProfile(
        age: 49,
        restingHr: 60,
        betaBlocker: true,
      );
      final config = calculateZones(profile)!;
      expect(config.method, ZoneMethod.hrrKarvonen);
      expect(config.reliability, ZoneReliability.low);
      expect(config.reason, contains('Caution'));

      // At age 49, Karvonen zone 1 lower ≈ 117 bpm. Keep all readings above
      // that so every interval lands in a zone and the summed total equals the
      // wall-clock span.
      final readings = [
        const HrReading(bpm: 120, elapsed: Duration.zero),
        const HrReading(bpm: 140, elapsed: Duration(minutes: 10)),
        const HrReading(bpm: 160, elapsed: Duration(minutes: 20)),
      ];
      final summary = calculateTimeInZones(readings, config);
      final total = summary.zoneDurations.fold<Duration>(
        Duration.zero,
        (acc, zd) => acc + zd.duration,
      );
      expect(total, const Duration(minutes: 20));
    });
  });

  // -------------------------------------------------------------------------
  // Clinician cap with caution flags
  // -------------------------------------------------------------------------
  group('clinician cap with beta-blocker', () {
    test('time-in-zone uses the clinician-capped max, not the age estimate',
        () {
      // Age 40 Tanaka would estimate max 180, but the clinician has capped at
      // 150. Zone 1 at 50% of 150 = 75, zone 5 at 90% = 135.
      const profile = HealthProfile(
        age: 40,
        clinicianMaxHr: 150,
        betaBlocker: true,
      );
      final config = calculateZones(profile)!;
      expect(config.method, ZoneMethod.clinicianCap);
      expect(config.reliability, ZoneReliability.high);
      expect(config.maxHr, 150);
      expect(config.zones[0].lowerBound, 75);
      expect(config.zones[4].lowerBound, 135);

      final readings = [
        const HrReading(bpm: 140, elapsed: Duration.zero),
        const HrReading(bpm: 145, elapsed: Duration(minutes: 8)),
      ];
      final summary = calculateTimeInZones(readings, config);
      // 140 bpm sits in zone 5 (≥ 135), not zone 4 it would hit under the
      // age-estimated defaults.
      expect(summary.durationInZone(5), const Duration(minutes: 8));
    });
  });

  // -------------------------------------------------------------------------
  // Consistency: time-in-zone attribution matches currentZoneFromConfig
  // -------------------------------------------------------------------------
  group('per-reading consistency', () {
    test(
        'each interval credits the zone reported by currentZoneFromConfig '
        'for the earlier reading', () {
      const profile = HealthProfile(age: 40, restingHr: 60);
      final config = calculateZones(profile)!;

      final readings = [
        const HrReading(bpm: 95, elapsed: Duration.zero),
        const HrReading(bpm: 130, elapsed: Duration(minutes: 5)),
        const HrReading(bpm: 155, elapsed: Duration(minutes: 8)),
        const HrReading(bpm: 100, elapsed: Duration(minutes: 10)),
      ];

      // Hand-compute the attribution from currentZoneFromConfig and compare
      // against the calculator's result. Both should agree on which zone each
      // interval belongs to.
      final expected = <int, Duration>{
        for (final z in config.zones) z.zoneNumber: Duration.zero,
      };
      for (var i = 0; i < readings.length - 1; i++) {
        final interval = readings[i + 1].elapsed - readings[i].elapsed;
        final zone = currentZoneFromConfig(readings[i].bpm, config);
        if (zone != null) {
          expected[zone.zoneNumber] = expected[zone.zoneNumber]! + interval;
        }
      }

      final summary = calculateTimeInZones(readings, config);
      for (final z in config.zones) {
        expect(
          summary.durationInZone(z.zoneNumber),
          expected[z.zoneNumber],
          reason: 'zone ${z.zoneNumber} attribution mismatch',
        );
      }
    });
  });
}
