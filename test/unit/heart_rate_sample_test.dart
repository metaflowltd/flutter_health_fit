import 'package:flutter_health_fit/flutter_health_fit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group("HeartRateSample", () {
    test("when motionLevel is double, expect round to int", () {
      final sample = HeartRateSample(
        dateTime: DateTime.now(),
        heartRate: 64,
        sourceApp: "com.apple.health",
        sourceDevice: null,
        metadata: {"HKMetadataKeyHeartRateMotionContext": 1.0},
      );
      expect(sample.motionLevel, equals(1));
    });

    test("when motionLevel is int, expect same number", () {
      final sample = HeartRateSample(
        dateTime: DateTime.now(),
        heartRate: 64,
        sourceApp: "com.apple.health",
        sourceDevice: null,
        metadata: {"HKMetadataKeyHeartRateMotionContext": 2},
      );
      expect(sample.motionLevel, equals(2));
    });

    test("when motionLevel is not a number, expect 0", () {
      final sample = HeartRateSample(
        dateTime: DateTime.now(),
        heartRate: 64,
        sourceApp: "com.apple.health",
        sourceDevice: null,
        metadata: {"HKMetadataKeyHeartRateMotionContext": "not a number"},
      );
      expect(sample.motionLevel, equals(0));
    });

    test("when motionLevel key not in metadata, expect motionLevel to be 0", () {
      final sample = HeartRateSample(
        dateTime: DateTime.now(),
        heartRate: 64,
        sourceApp: "com.apple.health",
        sourceDevice: null,
        metadata: {},
      );
      expect(sample.motionLevel, equals(0));
    });

    test("when no metadata, expect motionLevel to be 0", () {
      final sample = HeartRateSample(
        dateTime: DateTime.now(),
        heartRate: 64,
        sourceApp: "com.apple.health",
        sourceDevice: null,
      );
      expect(sample.motionLevel, equals(0));
    });
  });
}
