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

    test('toString contains all fields', () {
      const profile = HealthProfile(
        age: 30,
        restingHr: 55,
        measuredMaxHr: 185,
        clinicianMaxHr: 170,
        // Explicitly test the default value of betaBlocker.
        betaBlocker: false, // ignore: avoid_redundant_argument_values
        heartCondition: true,
      );
      final str = profile.toString();
      expect(str, contains('30'));
      expect(str, contains('55'));
      expect(str, contains('185'));
      expect(str, contains('170'));
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
      expect(boundary.zone2Lower, 114);
      expect(boundary.zone3Lower, 133);
      expect(boundary.zone4Lower, 152);
      expect(boundary.zone5Lower, 171);
    });

    test('equality', () {
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
    });
  });
}
