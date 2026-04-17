import 'package:hr_zones/hr_zones.dart';
import 'package:test/test.dart';

/// Shared Tanaka-40 configuration. Zone 1 90-108, Z2 108-126, Z3 126-144,
/// Z4 144-162, Z5 162+ bpm.
ZoneConfiguration _config() => calculateZones(const HealthProfile(age: 40))!;

void main() {
  // -------------------------------------------------------------------------
  // Edwards TRIMP
  // -------------------------------------------------------------------------
  group('calculateEdwardsTrimp', () {
    test('empty summary → 0', () {
      final summary = calculateTimeInZones(const [], _config());
      expect(calculateEdwardsTrimp(summary), 0);
    });

    test('1×10 + 2×10 + 3×10 + 4×10 + 5×10 = 150 minutes', () {
      // Construct readings that deposit 10 minutes in each of the five zones.
      final readings = [
        const HrReading(bpm: 95, elapsed: Duration.zero), // z1
        const HrReading(bpm: 115, elapsed: Duration(minutes: 10)), // z2
        const HrReading(bpm: 130, elapsed: Duration(minutes: 20)), // z3
        const HrReading(bpm: 150, elapsed: Duration(minutes: 30)), // z4
        const HrReading(bpm: 170, elapsed: Duration(minutes: 40)), // z5
        const HrReading(bpm: 180, elapsed: Duration(minutes: 50)), // end
      ];
      final summary = calculateTimeInZones(readings, _config());
      expect(calculateEdwardsTrimp(summary), 150.0);
    });

    test('result is in minutes, not seconds or hours', () {
      final readings = [
        const HrReading(bpm: 95, elapsed: Duration.zero), // zone 1
        const HrReading(bpm: 95, elapsed: Duration(minutes: 30)),
      ];
      final summary = calculateTimeInZones(readings, _config());
      // 30 minutes in zone 1 → 1 × 30 = 30.
      expect(calculateEdwardsTrimp(summary), 30.0);
    });
  });

  // -------------------------------------------------------------------------
  // Banister TRIMP
  // -------------------------------------------------------------------------
  group('calculateBanisterTrimp', () {
    test('null when restingHr is missing', () {
      const profile = HealthProfile(age: 40);
      final trimp = calculateBanisterTrimp(const [], profile);
      expect(trimp, isNull);
    });

    test('null when neither measuredMaxHr nor age is available', () {
      const profile = HealthProfile(restingHr: 60);
      final trimp = calculateBanisterTrimp(const [], profile);
      expect(trimp, isNull);
    });

    test('0 when readings has fewer than two samples', () {
      const profile = HealthProfile(age: 40, restingHr: 60);
      expect(calculateBanisterTrimp(const [], profile), 0.0);
      expect(
        calculateBanisterTrimp(
          const [HrReading(bpm: 120, elapsed: Duration.zero)],
          profile,
        ),
        0.0,
      );
    });

    test('steady HRR 0.5 for 10 minutes matches hand-computed value', () {
      // Age 40 Tanaka → max 180. restingHr 60 → HRR range 120.
      // HRR fraction = (120 - 60) / 120 = 0.5.
      // Male weighting = 0.64 × exp(1.92 × 0.5) = 0.64 × exp(0.96).
      // TRIMP = 10 × 0.5 × 0.64 × exp(0.96) ≈ 8.357.
      const profile = HealthProfile(age: 40, restingHr: 60);
      final readings = [
        const HrReading(bpm: 120, elapsed: Duration.zero),
        const HrReading(bpm: 120, elapsed: Duration(minutes: 10)),
      ];
      final trimp = calculateBanisterTrimp(readings, profile)!;
      expect(trimp, closeTo(8.357, 0.01));
    });

    test('male vs female coefficients produce different scores', () {
      const profile = HealthProfile(age: 40, restingHr: 60);
      final readings = [
        const HrReading(bpm: 150, elapsed: Duration.zero),
        const HrReading(bpm: 150, elapsed: Duration(minutes: 15)),
      ];
      final male = calculateBanisterTrimp(readings, profile)!;
      final female = calculateBanisterTrimp(
        readings,
        profile,
        coefficients: const BanisterCoefficients.female(),
      )!;
      expect(male, isNot(closeTo(female, 0.001)));
    });

    test('bpm below resting HR is clamped to zero contribution', () {
      const profile = HealthProfile(age: 40, restingHr: 60);
      final belowRest = [
        const HrReading(bpm: 50, elapsed: Duration.zero),
        const HrReading(bpm: 50, elapsed: Duration(minutes: 10)),
      ];
      // HRR fraction clamps to 0 → TRIMP = 0 (0 × anything = 0).
      expect(calculateBanisterTrimp(belowRest, profile), 0.0);
    });

    test('uses measuredMaxHr when available instead of age estimate', () {
      const age40Profile = HealthProfile(age: 40, restingHr: 60);
      const measuredProfile = HealthProfile(
        age: 40,
        restingHr: 60,
        measuredMaxHr: 200,
      );
      final readings = [
        const HrReading(bpm: 150, elapsed: Duration.zero),
        const HrReading(bpm: 150, elapsed: Duration(minutes: 10)),
      ];
      final estimate = calculateBanisterTrimp(readings, age40Profile)!;
      final measured = calculateBanisterTrimp(readings, measuredProfile)!;
      // Different max values → different HRR fractions → different TRIMPs.
      expect(estimate, isNot(closeTo(measured, 0.001)));
    });

    test('non-increasing intervals are skipped', () {
      const profile = HealthProfile(age: 40, restingHr: 60);
      // Two readings with the same elapsed time produce a zero-length
      // interval that must not contribute. The non-zero interval that
      // follows uses bpm 120 (the earlier of the two remaining readings).
      final readings = [
        const HrReading(bpm: 120, elapsed: Duration.zero),
        const HrReading(bpm: 120, elapsed: Duration.zero),
        const HrReading(bpm: 120, elapsed: Duration(minutes: 10)),
      ];
      final trimp = calculateBanisterTrimp(readings, profile)!;
      expect(trimp, closeTo(8.357, 0.01));
    });
  });

  // -------------------------------------------------------------------------
  // BanisterCoefficients
  // -------------------------------------------------------------------------
  group('BanisterCoefficients', () {
    test('male preset', () {
      const c = BanisterCoefficients.male();
      expect(c.a, 0.64);
      expect(c.b, 1.92);
    });

    test('female preset', () {
      const c = BanisterCoefficients.female();
      expect(c.a, 0.86);
      expect(c.b, 1.67);
    });

    test('custom constructor accepts arbitrary values', () {
      const c = BanisterCoefficients(a: 0.5, b: 1.5);
      expect(c.a, 0.5);
      expect(c.b, 1.5);
    });

    test('toString surfaces coefficients', () {
      const c = BanisterCoefficients.female();
      expect(c.toString(), contains('0.86'));
      expect(c.toString(), contains('1.67'));
    });
  });
}
