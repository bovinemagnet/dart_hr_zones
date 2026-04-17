import 'package:hr_zones/hr_zones.dart';
import 'package:test/test.dart';

void main() {
  group('HealthProfile', () {
    test('default values', () {
      const profile = HealthProfile();
      expect(profile.age, isNull);
      expect(profile.restingHr, isNull);
      expect(profile.measuredMaxHr, isNull);
      expect(profile.clinicianMaxHr, isNull);
      expect(profile.betaBlocker, isFalse);
      expect(profile.heartCondition, isFalse);
      expect(profile.customZones, isNull);
      expect(profile.isCautionMode, isFalse);
      expect(profile.maxHrFormula, MaxHrFormula.tanaka);
    });

    test('isCautionMode true when betaBlocker is set', () {
      const profile = HealthProfile(betaBlocker: true);
      expect(profile.isCautionMode, isTrue);
    });

    test('isCautionMode true when heartCondition is set', () {
      const profile = HealthProfile(heartCondition: true);
      expect(profile.isCautionMode, isTrue);
    });

    test('isCautionMode false when neither flag is set', () {
      const profile = HealthProfile(age: 40, restingHr: 60);
      expect(profile.isCautionMode, isFalse);
    });

    test('estimatedMaxHr uses Tanaka by default (208 − 0.7 × age)', () {
      const profile = HealthProfile(age: 40);
      // 208 - 0.7*40 = 180
      expect(profile.estimatedMaxHr, 180);
    });

    test('estimatedMaxHr is null when age is null', () {
      const profile = HealthProfile();
      expect(profile.estimatedMaxHr, isNull);
    });

    test('estimatedMaxHr respects fox220 formula', () {
      const profile = HealthProfile(age: 30, maxHrFormula: MaxHrFormula.fox220);
      expect(profile.estimatedMaxHr, 190);
    });

    test('estimatedMaxHr respects nes formula', () {
      const profile = HealthProfile(age: 30, maxHrFormula: MaxHrFormula.nes);
      // 211 - 0.64*30 = 191.8 → 192
      expect(profile.estimatedMaxHr, 192);
    });

    test('Tanaka at age 30 differs from Fox 220', () {
      const tanakaProfile = HealthProfile(age: 30);
      const foxProfile = HealthProfile(
        age: 30,
        maxHrFormula: MaxHrFormula.fox220,
      );
      // Tanaka: 208 - 21 = 187; Fox: 220 - 30 = 190
      expect(tanakaProfile.estimatedMaxHr, 187);
      expect(foxProfile.estimatedMaxHr, 190);
    });

    test('copyWith preserves formula', () {
      const profile = HealthProfile(
        age: 30,
        maxHrFormula: MaxHrFormula.nes,
      );
      final copy = profile.copyWith(age: 40);
      expect(copy.maxHrFormula, MaxHrFormula.nes);
    });

    test('copyWith can change formula', () {
      const profile = HealthProfile(age: 30);
      final copy = profile.copyWith(maxHrFormula: MaxHrFormula.fox220);
      expect(copy.maxHrFormula, MaxHrFormula.fox220);
      expect(copy.age, 30);
    });

    test('copyWith clearRestingHr resets to null', () {
      const profile = HealthProfile(age: 40, restingHr: 60);
      final copy = profile.copyWith(clearRestingHr: true);
      expect(copy.restingHr, isNull);
      expect(copy.age, 40);
    });

    test('copyWith clearAge resets age', () {
      const profile = HealthProfile(age: 40, restingHr: 60);
      final copy = profile.copyWith(clearAge: true);
      expect(copy.age, isNull);
      expect(copy.restingHr, 60);
    });

    test('copyWith clearClinicianMaxHr resets clinician cap', () {
      const profile = HealthProfile(age: 40, clinicianMaxHr: 150);
      final copy = profile.copyWith(clearClinicianMaxHr: true);
      expect(copy.clinicianMaxHr, isNull);
      expect(copy.age, 40);
    });

    test('copyWith clearMeasuredMaxHr resets measured max', () {
      const profile = HealthProfile(measuredMaxHr: 185);
      final copy = profile.copyWith(clearMeasuredMaxHr: true);
      expect(copy.measuredMaxHr, isNull);
    });

    test('copyWith clearCustomZones resets custom zones', () {
      const profile = HealthProfile(
        customZones: CustomZoneBoundary(
          zone1Lower: 95,
          zone2Lower: 114,
          zone3Lower: 133,
          zone4Lower: 152,
          zone5Lower: 171,
        ),
      );
      final copy = profile.copyWith(clearCustomZones: true);
      expect(copy.customZones, isNull);
    });

    test('copyWith can set betaBlocker / heartCondition', () {
      const profile = HealthProfile(age: 40);
      final beta = profile.copyWith(betaBlocker: true);
      expect(beta.betaBlocker, isTrue);
      expect(beta.isCautionMode, isTrue);
      expect(beta.heartCondition, isFalse);

      final condition = profile.copyWith(heartCondition: true);
      expect(condition.heartCondition, isTrue);
      expect(condition.isCautionMode, isTrue);
    });

    test('isCautionMode true when both flags set', () {
      const profile = HealthProfile(betaBlocker: true, heartCondition: true);
      expect(profile.isCautionMode, isTrue);
    });

    test('toString surfaces key fields', () {
      const profile = HealthProfile(age: 42, restingHr: 58, betaBlocker: true);
      final s = profile.toString();
      expect(s, contains('42'));
      expect(s, contains('58'));
      expect(s, contains('betaBlocker: true'));
    });
  });

  group('MaxHrFormula', () {
    test('tanaka.apply rounds correctly', () {
      expect(MaxHrFormula.tanaka.apply(40), 180);
      expect(MaxHrFormula.tanaka.apply(30), 187); // 208-21=187
      expect(MaxHrFormula.tanaka.apply(49), 174); // 208-34.3=173.7→174
    });

    test('fox220.apply is 220 − age', () {
      expect(MaxHrFormula.fox220.apply(30), 190);
      expect(MaxHrFormula.fox220.apply(49), 171);
    });

    test('nes.apply rounds correctly', () {
      expect(MaxHrFormula.nes.apply(30), 192); // 211-19.2=191.8→192
      expect(MaxHrFormula.nes.apply(40), 185); // 211-25.6=185.4→185
    });

    test('displayName is human readable', () {
      expect(MaxHrFormula.tanaka.displayName, contains('Tanaka'));
      expect(MaxHrFormula.fox220.displayName, contains('Fox'));
      expect(MaxHrFormula.nes.displayName, contains('Nes'));
    });
  });

  group('CustomZoneBoundary', () {
    test('stores all boundaries', () {
      const boundary = CustomZoneBoundary(
        zone1Lower: 95,
        zone2Lower: 114,
        zone3Lower: 133,
        zone4Lower: 152,
        zone5Lower: 171,
      );
      expect(boundary.zone1Lower, 95);
      expect(boundary.zone5Lower, 171);
      expect(boundary.labels, isNull);
    });

    test('stores optional labels', () {
      const boundary = CustomZoneBoundary(
        zone1Lower: 95,
        zone2Lower: 114,
        zone3Lower: 133,
        zone4Lower: 152,
        zone5Lower: 171,
        labels: ['Marathon', 'Endurance', 'Tempo', 'Threshold', 'VO₂'],
      );
      expect(boundary.labels, hasLength(5));
      expect(boundary.labels!.first, 'Marathon');
    });

    test('equality with and without labels', () {
      const a = CustomZoneBoundary(
        zone1Lower: 95,
        zone2Lower: 114,
        zone3Lower: 133,
        zone4Lower: 152,
        zone5Lower: 171,
      );
      const b = CustomZoneBoundary(
        zone1Lower: 95,
        zone2Lower: 114,
        zone3Lower: 133,
        zone4Lower: 152,
        zone5Lower: 171,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));

      const c = CustomZoneBoundary(
        zone1Lower: 95,
        zone2Lower: 114,
        zone3Lower: 133,
        zone4Lower: 152,
        zone5Lower: 171,
        labels: ['A', 'B', 'C', 'D', 'E'],
      );
      expect(a, isNot(equals(c)));
    });

    test('inequality when a single boundary differs', () {
      const a = CustomZoneBoundary(
        zone1Lower: 95,
        zone2Lower: 114,
        zone3Lower: 133,
        zone4Lower: 152,
        zone5Lower: 171,
      );
      const b = CustomZoneBoundary(
        zone1Lower: 95,
        zone2Lower: 115, // differs
        zone3Lower: 133,
        zone4Lower: 152,
        zone5Lower: 171,
      );
      expect(a, isNot(equals(b)));
    });

    test('toString lists every boundary', () {
      const boundary = CustomZoneBoundary(
        zone1Lower: 95,
        zone2Lower: 114,
        zone3Lower: 133,
        zone4Lower: 152,
        zone5Lower: 171,
      );
      final s = boundary.toString();
      expect(s, contains('95'));
      expect(s, contains('171'));
    });
  });
}
