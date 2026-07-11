import 'package:hr_zones/hr_zones.dart';
import 'package:test/test.dart';

void main() {
  // -------------------------------------------------------------------------
  // Construction-time validation. Profiles are typically built from user input
  // at runtime, where `assert` is stripped in release AOT builds — so
  // impossible inputs are rejected with ArgumentError from the constructor
  // rather than being allowed to produce nonsensical zones downstream.
  // -------------------------------------------------------------------------
  group('HealthProfile validation', () {
    test('non-positive age throws ArgumentError', () {
      expect(() => HealthProfile(age: 0), throwsArgumentError);
      expect(() => HealthProfile(age: -1), throwsArgumentError);
    });

    test('non-positive heart rate fields throw ArgumentError', () {
      expect(() => HealthProfile(restingHr: 0), throwsArgumentError);
      expect(() => HealthProfile(measuredMaxHr: -5), throwsArgumentError);
      expect(() => HealthProfile(clinicianMaxHr: 0), throwsArgumentError);
      expect(() => HealthProfile(lactateThresholdHr: -2), throwsArgumentError);
    });

    test('restingHr at or above measuredMaxHr throws ArgumentError', () {
      expect(
        () => HealthProfile(measuredMaxHr: 120, restingHr: 130),
        throwsArgumentError,
      );
      expect(
        () => HealthProfile(measuredMaxHr: 120, restingHr: 120),
        throwsArgumentError,
      );
    });

    test('restingHr at or above lactateThresholdHr throws ArgumentError', () {
      expect(
        () => HealthProfile(lactateThresholdHr: 150, restingHr: 155),
        throwsArgumentError,
      );
    });

    test('restingHr at or above clinicianMaxHr is accepted', () {
      // A conservative prescribed cap may legitimately sit at or below resting
      // HR; calculateZones degrades to flat percentage bands rather than
      // failing, so the constructor must not reject this.
      expect(
        () => HealthProfile(clinicianMaxHr: 120, restingHr: 130),
        returnsNormally,
      );
    });

    test('resting HR above an age-estimated max is not rejected here', () {
      // The estimated max depends on the resolution order (a measured max can
      // outrank the age estimate), so that consistency check belongs to
      // calculateZones, not the constructor.
      expect(() => HealthProfile(age: 60, restingHr: 170), returnsNormally);
    });

    test('error message names the offending field', () {
      expect(
        () => HealthProfile(age: -1),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'age')),
      );
    });

    test('a plausible profile is accepted', () {
      final profile = HealthProfile(
        age: 40,
        restingHr: 55,
        measuredMaxHr: 185,
        lactateThresholdHr: 165,
      );
      expect(profile.age, 40);
      expect(profile.restingHr, 55);
    });

    test('copyWith validates the resulting profile', () {
      final profile = HealthProfile(measuredMaxHr: 180, restingHr: 50);
      expect(() => profile.copyWith(restingHr: 190), throwsArgumentError);
    });

    test('fromJson validates the decoded profile', () {
      expect(
        () => HealthProfile.fromJson(const {'age': -1}),
        throwsArgumentError,
      );
    });
  });

  group('CustomZoneBoundary validation', () {
    test('non-positive lower bounds throw ArgumentError', () {
      expect(
        () => CustomZoneBoundary(
          zone1Lower: 0,
          zone2Lower: 114,
          zone3Lower: 133,
          zone4Lower: 152,
          zone5Lower: 171,
        ),
        throwsArgumentError,
      );
    });

    test('non-monotonic lower bounds throw ArgumentError', () {
      expect(
        () => CustomZoneBoundary(
          zone1Lower: 171,
          zone2Lower: 152,
          zone3Lower: 133,
          zone4Lower: 114,
          zone5Lower: 95,
        ),
        throwsArgumentError,
      );
    });

    test('equal adjacent lower bounds throw ArgumentError', () {
      expect(
        () => CustomZoneBoundary(
          zone1Lower: 95,
          zone2Lower: 114,
          zone3Lower: 114,
          zone4Lower: 152,
          zone5Lower: 171,
        ),
        throwsArgumentError,
      );
    });

    test('labels length other than five throws ArgumentError', () {
      expect(
        () => CustomZoneBoundary(
          zone1Lower: 95,
          zone2Lower: 114,
          zone3Lower: 133,
          zone4Lower: 152,
          zone5Lower: 171,
          labels: const ['a', 'b'],
        ),
        throwsArgumentError,
      );
    });

    test('strictly increasing positive bounds are accepted', () {
      expect(
        () => CustomZoneBoundary(
          zone1Lower: 95,
          zone2Lower: 114,
          zone3Lower: 133,
          zone4Lower: 152,
          zone5Lower: 171,
        ),
        returnsNormally,
      );
    });
  });

  group('HealthProfile', () {
    test('default values', () {
      final profile = HealthProfile();
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
      final profile = HealthProfile(betaBlocker: true);
      expect(profile.isCautionMode, isTrue);
    });

    test('isCautionMode true when heartCondition is set', () {
      final profile = HealthProfile(heartCondition: true);
      expect(profile.isCautionMode, isTrue);
    });

    test('isCautionMode false when neither flag is set', () {
      final profile = HealthProfile(age: 40, restingHr: 60);
      expect(profile.isCautionMode, isFalse);
    });

    test('estimatedMaxHr uses Tanaka by default (208 − 0.7 × age)', () {
      final profile = HealthProfile(age: 40);
      // 208 - 0.7*40 = 180
      expect(profile.estimatedMaxHr, 180);
    });

    test('estimatedMaxHr is null when age is null', () {
      final profile = HealthProfile();
      expect(profile.estimatedMaxHr, isNull);
    });

    test('estimatedMaxHr respects fox220 formula', () {
      final profile = HealthProfile(age: 30, maxHrFormula: MaxHrFormula.fox220);
      expect(profile.estimatedMaxHr, 190);
    });

    test('estimatedMaxHr respects nes formula', () {
      final profile = HealthProfile(age: 30, maxHrFormula: MaxHrFormula.nes);
      // 211 - 0.64*30 = 191.8 → 192
      expect(profile.estimatedMaxHr, 192);
    });

    test('Tanaka at age 30 differs from Fox 220', () {
      final tanakaProfile = HealthProfile(age: 30);
      final foxProfile = HealthProfile(
        age: 30,
        maxHrFormula: MaxHrFormula.fox220,
      );
      // Tanaka: 208 - 21 = 187; Fox: 220 - 30 = 190
      expect(tanakaProfile.estimatedMaxHr, 187);
      expect(foxProfile.estimatedMaxHr, 190);
    });

    test('copyWith preserves formula', () {
      final profile = HealthProfile(
        age: 30,
        maxHrFormula: MaxHrFormula.nes,
      );
      final copy = profile.copyWith(age: 40);
      expect(copy.maxHrFormula, MaxHrFormula.nes);
    });

    test('copyWith can change formula', () {
      final profile = HealthProfile(age: 30);
      final copy = profile.copyWith(maxHrFormula: MaxHrFormula.fox220);
      expect(copy.maxHrFormula, MaxHrFormula.fox220);
      expect(copy.age, 30);
    });

    test('copyWith clearRestingHr resets to null', () {
      final profile = HealthProfile(age: 40, restingHr: 60);
      final copy = profile.copyWith(clearRestingHr: true);
      expect(copy.restingHr, isNull);
      expect(copy.age, 40);
    });

    test('copyWith clearAge resets age', () {
      final profile = HealthProfile(age: 40, restingHr: 60);
      final copy = profile.copyWith(clearAge: true);
      expect(copy.age, isNull);
      expect(copy.restingHr, 60);
    });

    test('copyWith clearClinicianMaxHr resets clinician cap', () {
      final profile = HealthProfile(age: 40, clinicianMaxHr: 150);
      final copy = profile.copyWith(clearClinicianMaxHr: true);
      expect(copy.clinicianMaxHr, isNull);
      expect(copy.age, 40);
    });

    test('copyWith clearMeasuredMaxHr resets measured max', () {
      final profile = HealthProfile(measuredMaxHr: 185);
      final copy = profile.copyWith(clearMeasuredMaxHr: true);
      expect(copy.measuredMaxHr, isNull);
    });

    test('copyWith clearCustomZones resets custom zones', () {
      final profile = HealthProfile(
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
      final profile = HealthProfile(age: 40);
      final beta = profile.copyWith(betaBlocker: true);
      expect(beta.betaBlocker, isTrue);
      expect(beta.isCautionMode, isTrue);
      expect(beta.heartCondition, isFalse);

      final condition = profile.copyWith(heartCondition: true);
      expect(condition.heartCondition, isTrue);
      expect(condition.isCautionMode, isTrue);
    });

    test('isCautionMode true when both flags set', () {
      final profile = HealthProfile(betaBlocker: true, heartCondition: true);
      expect(profile.isCautionMode, isTrue);
    });

    test('toString surfaces key fields', () {
      final profile = HealthProfile(age: 42, restingHr: 58, betaBlocker: true);
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

    test('gellish2007.apply rounds correctly', () {
      expect(MaxHrFormula.gellish2007.apply(30), 186); // 207-21=186
      expect(MaxHrFormula.gellish2007.apply(40), 179); // 207-28=179
      expect(MaxHrFormula.gellish2007.apply(49), 173); // 207-34.3=172.7→173
    });

    test('astrand.apply rounds correctly', () {
      expect(MaxHrFormula.astrand.apply(30), 191); // 216.6-25.2=191.4→191
      expect(MaxHrFormula.astrand.apply(40), 183); // 216.6-33.6=183.0→183
      expect(MaxHrFormula.astrand.apply(49), 175); // 216.6-41.16=175.44→175
    });

    test('millerFaulkner.apply rounds correctly', () {
      expect(MaxHrFormula.millerFaulkner.apply(30), 192); // 217-25.5=191.5→192
      expect(MaxHrFormula.millerFaulkner.apply(40), 183); // 217-34=183
      expect(
          MaxHrFormula.millerFaulkner.apply(49), 175); // 217-41.65=175.35→175
    });

    test('displayName is human readable', () {
      expect(MaxHrFormula.tanaka.displayName, contains('Tanaka'));
      expect(MaxHrFormula.fox220.displayName, contains('Fox'));
      expect(MaxHrFormula.nes.displayName, contains('Nes'));
      expect(MaxHrFormula.gellish2007.displayName, contains('Gellish'));
      expect(MaxHrFormula.astrand.displayName, contains('strand'));
      expect(MaxHrFormula.millerFaulkner.displayName, contains('Miller'));
    });
  });

  group('CustomZoneBoundary', () {
    test('stores all boundaries', () {
      final boundary = CustomZoneBoundary(
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
      final boundary = CustomZoneBoundary(
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
      final a = CustomZoneBoundary(
        zone1Lower: 95,
        zone2Lower: 114,
        zone3Lower: 133,
        zone4Lower: 152,
        zone5Lower: 171,
      );
      final b = CustomZoneBoundary(
        zone1Lower: 95,
        zone2Lower: 114,
        zone3Lower: 133,
        zone4Lower: 152,
        zone5Lower: 171,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));

      final c = CustomZoneBoundary(
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
      final a = CustomZoneBoundary(
        zone1Lower: 95,
        zone2Lower: 114,
        zone3Lower: 133,
        zone4Lower: 152,
        zone5Lower: 171,
      );
      final b = CustomZoneBoundary(
        zone1Lower: 95,
        zone2Lower: 115, // differs
        zone3Lower: 133,
        zone4Lower: 152,
        zone5Lower: 171,
      );
      expect(a, isNot(equals(b)));
    });

    test('toString lists every boundary', () {
      final boundary = CustomZoneBoundary(
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
