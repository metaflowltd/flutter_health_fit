import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_health_fit/data_point_unit.dart';
import 'package:flutter_health_fit/data_pointd_output.dart';
import 'package:flutter_health_fit/workout_sample.dart';

import 'body_composition_data.dart';

abstract class HealthFitAbstractLog {
  void info(Object? message, [Object? error, StackTrace? stackTrace]);
  void warning(Object? message, [Object? error, StackTrace? stackTrace]);
  void severe(Object? message, [Object? error, StackTrace? stackTrace]);
}

enum TimeUnit { minutes, days }
enum QuantityUnit {
  percent,
  cm,
  second,
}

extension QuantityUnitExtension on QuantityUnit {
  String get stringValue {
    switch (this) {
      case QuantityUnit.cm:
        return "cm";
      case QuantityUnit.percent:
        return "%";
      case QuantityUnit.second:
        return "s";
    }
  }
}

// Current day's accumulated values
enum _ActivityType { steps, cycling, walkRun, heartRate, flights }

enum SleepSampleType { inBed, asleep, awake }

enum Flow {
  notSpecified,
  spotting, // Spotting
  light, // Light
  medium, // Medium
  heavy // Heavy
}

class MenstrualData {
  final DateTime dateTime;
  final Flow flow;

  MenstrualData(this.dateTime, this.flow);

  MenstrualData.fromRawData(this.dateTime, int rawFlowValue) : flow = _flowFromInt(rawFlowValue);

  static Flow _flowFromInt(int input) {
    switch (input) {
      case 0:
        return Flow.notSpecified;
      case 1:
        return Flow.spotting;
      case 2:
        return Flow.light;
      case 3:
        return Flow.medium;
      case 4:
        return Flow.heavy;
      default:
        throw ArgumentError("Can not map $input to Flow");
    }
  }
}

enum GFSleepSampleType {
  // Unspecified or unknown if user is sleeping.
  unspecified,
  // Awake; user is awake.
  awake,
  // Sleeping; generic or non-granular sleep description.
  sleep,
  // Out of bed; user gets out of bed in the middle of a sleep session.
  outOfBed,
  // Light sleep; user is in a light sleep cycle.
  sleepLight,
  // Deep sleep; user is in a deep sleep cycle.
  sleepDeep,
  // REM sleep; user is in a REM sleep cyle.
  sleepRem
}

class SleepSample {
  final SleepSampleType type;
  final DateTime start;
  final DateTime end;
  final String source;

  SleepSample({
    required this.type,
    required this.start,
    required this.end,
    required this.source,
  });

  @override
  String toString() {
    return 'SleepSample{type: $type, start: $start, end: $end, source: $source}';
  }

  SleepSample.fromMap(Map<String, dynamic> map)
      : type = _typeFromInt(map["type"].toInt()),
        start = DateTime.fromMillisecondsSinceEpoch(map["start"]),
        end = DateTime.fromMillisecondsSinceEpoch(map["end"]),
        source = map["source"];

  static SleepSampleType _typeFromInt(int input) {
    switch (input) {
      case 0:
        return SleepSampleType.inBed;
      case 1:
        return SleepSampleType.asleep;
      case 2:
        return SleepSampleType.awake;
      default:
        throw ArgumentError("Can not map $input to SleepSampleType");
    }
  }
}

enum WorkoutSampleType {
  americanFootball,
  archery,
  australianFootball,
  badminton,
  baseball,
  basketball,
  bowling,
  boxing,
  climbing,
  cricket,
  crossTraining,
  curling,
  cycling,
  dance,
  danceInspiredTraining,
  elliptical,
  equestrianSports,
  fencing,
  fishing,
  functionalStrengthTraining,
  golf,
  gymnastics,
  handball,
  hiking,
  hockey,
  hunting,
  lacrosse,
  martialArts,
  mindAndBody,
  mixedMetabolicCardioTraining,
  paddleSports,
  play,
  preparationAndRecovery,
  racquetball,
  rowing,
  rugby,
  running,
  sailing,
  skatingSports,
  snowSports,
  soccer,
  softball,
  squash,
  stairClimbing,
  surfingSports,
  swimming,
  tableTennis,
  tennis,
  trackAndField,
  traditionalStrengthTraining,
  volleyball,
  walking,
  waterFitness,
  waterPolo,
  waterSports,
  wrestling,
  yoga,
  barre,
  coreTraining,
  crossCountrySkiing,
  downhillSkiing,
  flexibility,
  highIntensityIntervalTraining,
  jumpRope,
  kickboxing,
  pilates,
  snowboarding,
  stairs,
  stepTraining,
  wheelchairWalkPace,
  wheelchairRunPace,
  taiChi,
  mixedCardio,
  handCycling,
  discSports,
  fitnessGaming,
  cardioDance,
  socialDance,
  pickleball,
  cooldown,
  aerobics,
  biathlon,
  mountainCycling,
  roadCycling,
  spinning,
  stationaryCycling,
  utilityCycling,
  calisthenics,
  circuitTraining,
  diving,
  elevator,
  ergometer,
  escalator,
  frisbee,
  gardening,
  guidedBreathing,
  horsebackRiding,
  housework,
  iceSkating,
  intervalTraining,
  jumpingRope,
  kayaking,
  kettlebellTraining,
  kitesurfing,
  meditation,
  paragliding,
  polo,
  skiing,
  weightlifting,
  zumba,
  other,
}

class GFSleepSample {
  final GFSleepSampleType gfSleepSampleType;
  final DateTime start;
  final DateTime end;
  final String source;

  GFSleepSample({
    required this.gfSleepSampleType,
    required this.start,
    required this.end,
    required this.source,
  });

  GFSleepSample.fromMap(Map<String, dynamic> map)
      : gfSleepSampleType = _googleFitTypeFromInt(map["type"]),
        start = DateTime.fromMillisecondsSinceEpoch(map["start"]),
        end = DateTime.fromMillisecondsSinceEpoch(map["end"]),
        source = map["source"];

  static GFSleepSampleType _googleFitTypeFromInt(int input) {
    switch (input) {
      case 0:
        return GFSleepSampleType.unspecified;
      case 1:
        return GFSleepSampleType.awake;
      case 2:
        return GFSleepSampleType.sleep;
      case 3:
        return GFSleepSampleType.outOfBed;
      case 4:
        return GFSleepSampleType.sleepLight;
      case 5:
        return GFSleepSampleType.sleepDeep;
      case 6:
        return GFSleepSampleType.sleepRem;
      default:
        throw ArgumentError("Can not map $input to SleepSampleTypeGoogleFit");
    }
  }
}

class HeartRateSample {
  final DateTime dateTime;
  final int heartRate;
  final Map<String, dynamic>? metadata; // may be null
  final String sourceApp;
  final String? sourceDevice; // may be null

  int get motionLevel {
    if (metadata != null) {
      final heartRateMotionContext = metadata!["HKMetadataKeyHeartRateMotionContext"];
      if (heartRateMotionContext is num) {
        return heartRateMotionContext.round();
      }
    }
    return 0;
  }

  HeartRateSample({
    required this.dateTime,
    required this.heartRate,
    this.metadata,
    required this.sourceApp,
    this.sourceDevice,
  });

  @override
  String toString() =>
      "$runtimeType(dateTime: $dateTime, heartRate: $heartRate, metadata: $metadata, sourceApp: $sourceApp, sourceDevice: $sourceDevice)";

  HeartRateSample.fromMap(Map<String, dynamic> map)
      : dateTime = DateTime.fromMillisecondsSinceEpoch(map["timestamp"]),
        heartRate = map["value"].toInt(),
        metadata = map["metadata"] == null ? null : Map<String, dynamic>.from(map["metadata"]),
        sourceApp = map["sourceApp"],
        sourceDevice = map["sourceDevice"];
}

class FlutterHealthFit {
  static const MethodChannel _channel = const MethodChannel('flutter_health_fit');
  static const EventChannel _logsChannel = const EventChannel('flutter_health_fit_logs_channel');
  static HealthFitAbstractLog? logger;

  factory FlutterHealthFit() => _singleton;

  FlutterHealthFit.internal();

  static final _singleton = FlutterHealthFit.internal();



  /// NOTE: On iOS this only tells whether [authorize] has been called on the requested data types.
  /// There is no getter for the user's actual response.
  /// The caller has to ask the user before calling [authorize] and maintain the response internally.
  /// This method is only for the case when you want to collect new data types that were not asked originally
  /// (for example, in an app update).
  ///
  /// On Android this method works as expected.
  Future<bool> isAuthorized() async {
    try {
      final status = await _channel.invokeMethod("isAuthorized");
      return status;
    } catch (e) {
      _logDeviceError("isAuthorized", e);
      return false;
    }
  }

  /// This stream exposes native logs coming from the plugin, in order to be able
  /// debug
  Stream<String>? get androidNativeLogsMessages =>
      Platform.isAndroid ? _logsChannel.receiveBroadcastStream().map((event) => event as String) : null;

  /// Checks if any health permission has been authorized
  Future<bool> isAnyPermissionAuthorized() async {
    try {
      final status = await _channel.invokeMethod("isAnyPermissionAuthorized");
      return status;
    } catch (e) {
      _logDeviceError("isAnyPermissionAuthorized", e);
      return false;
    }
  }

  /// Checks if steps permission has been authorized
  Future<bool> isStepsAuthorized() async {
    try {
      final status = await _channel.invokeMethod("isStepsAuthorized");
      return status;
    } catch (e) {
      _logDeviceError("isStepsAuthorized", e);
      return false;
    }
  }

  /// Checks if cycling permission has been authorized
  Future<bool> isCyclingAuthorized() async {
    try {
      final status = await _channel.invokeMethod("isCyclingAuthorized");
      return status;
    } catch (e) {
      _logDeviceError("isCyclingAuthorized", e);
      return false;
    }
  }

  /// Checks if flights climbed permission has been authorized
  Future<bool> isFlightsAuthorized() async {
    try {
      final status = await _channel.invokeMethod("isFlightsAuthorized");
      return status;
    } catch (e) {
      _logDeviceError("isFlightsAuthorized", e);
      return false;
    }
  }

  /// Checks if sleep permission has been authorized
  Future<bool> isSleepAuthorized() async {
    try {
      final status = await _channel.invokeMethod("isSleepAuthorized");
      return status;
    } catch (e) {
      _logDeviceError("isSleepAuthorized", e);
      return false;
    }
  }

  /// Checks if workouts permission has been authorized
  Future<bool> isWorkoutsAuthorized() async {
    try {
      final status = await _channel.invokeMethod("isWorkoutsAuthorized");
      return status;
    } catch (e) {
      _logDeviceError("isWorkoutsAuthorized", e);
      return false;
    }
  }

  /// Checks if Waist Size permission has been authorized
  Future<bool> isWaistSizeAuthorized() async {
    try {
      final status = await _channel.invokeMethod("isWaistSizeAuthorized");
      return status;
    } catch (e) {
      _logDeviceError("isWaistSizeAuthorized", e);
      return false;
    }
  }

  /// Checks if Body Fat permission has been authorized
  Future<bool> isBodyFatPercentageAuthorized() async {
    try {
      final status = await _channel.invokeMethod("isBodyFatPercentageAuthorized");
      return status;
    } catch (e) {
      _logDeviceError("isBodyFatPercentageAuthorized", e);
      return false;
    }
  }

  /// Checks if HeartRateVariability permission has been authorized
  Future<bool> isHeartRateVariabilityAuthorized() async {
    if (!Platform.isIOS) return false;

    try {
      final status = await _channel.invokeMethod("isHeartRateVariabilityAuthorized");
      return status;
    } catch (e) {
      _logDeviceError("isHeartRateVariabilityAuthorized", e);
      return false;
    }
  }

  /// Checks if iBloodGlucose permission has been authorized
  Future<bool> isBloodGlucoseAuthorized() async {
    try {
      final status = await _channel.invokeMethod("isBloodGlucoseAuthorized");
      return status;
    } catch (e) {
      _logDeviceError("isBloodGlucoseAuthorized", e);
      return false;
    }
  }

  /// Checks if ForcedVitalCapacity permission has been authorized
  Future<bool> isForcedVitalCapacityAuthorized() async {
    if (!Platform.isIOS) return false;

    try {
      final status = await _channel.invokeMethod("isForcedVitalCapacityAuthorized");
      return status;
    } catch (e) {
      _logDeviceError("isForcedVitalCapacityAuthorized", e);
      return false;
    }
  }

  /// Checks if PeakExpiratoryFlowRate permission has been authorized
  Future<bool> isPeakExpiratoryFlowRateAuthorized() async {
    if (!Platform.isIOS) return false;

    try {
      final status = await _channel.invokeMethod("isPeakExpiratoryFlowRateAuthorized");
      return status;
    } catch (e) {
      _logDeviceError("isPeakExpiratoryFlowRateAuthorized", e);
      return false;
    }
  }

  /// Checks if menstrual data permission has been authorized
  Future<bool> isMenstrualDataAuthorized() async {
    try {
      final status = await _channel.invokeMethod("isMenstrualDataAuthorized");
      return status;
    } catch (e) {
      _logDeviceError("isMenstrualDataAuthorized", e);
      return false;
    }
  }

  /// Checks if weight permission has been authorized
  Future<bool> isWeightAuthorized() async {
    try {
      final status = await _channel.invokeMethod("isWeightAuthorized");
      return status;
    } catch (e) {
      _logDeviceError("isWeightAuthorized", e);
      return false;
    }
  }

  /// Checks if heart rate permission has been authorized
  Future<bool> isHeartRateAuthorized() async {
    try {
      final status = await _channel.invokeMethod("isHeartRateAuthorized");
      return status;
    } catch (e) {
      _logDeviceError("isHeartRateAuthorized", e);
      return false;
    }
  }

  /// Checks if all permissions needed for calculating carb servings have been authorized
  Future<bool> isCarbsAuthorized() async {
    try {
      final status = await _channel.invokeMethod("isCarbsAuthorized");
      return status;
    } catch (e) {
      _logDeviceError("isCarbsAuthorized", e);
      return false;
    }
  }

  /// Checks if android.permission.BODY_SENSORS is granted.
  /// on iOS returns always true.
  Future<bool> isBodySensorsAuthorized() async {
    if (Platform.isIOS) return true; // irrelevant for iOS. Assume authorized.
    try {
      final status = await _channel.invokeMethod("isBodySensorsAuthorized");
      return status;
    } catch (e) {
      _logDeviceError("isBodySensorsAuthorized", e);
      return false;
    }
  }

  /// Will ask to authorize, prompting the user if necessary.
  Future<bool> authorize() async {
    try {
      return await _channel.invokeMethod('requestAuthorization');
    } catch (e) {
      _logDeviceError("requestAuthorization", e);
      return false;
    }
  }

  /// Will ask to authorize android.permission.BODY_SENSORS permission on Android.
  /// Returns true if user authorized, false if not.
  /// on iOS, returns true immediately and does nothing.
  Future<bool> authorizeBodySensors() async {
    if (Platform.isIOS) return true; // irrelevant for iOS. Assume authorized.

    try {
      return await _channel.invokeMethod<bool>('requestBodySensorsPermission') ?? false;
    } catch (e) {
      _logDeviceError("requestBodySensorsPermission", e);
      return false;
    }
  }

  Future<Map<dynamic, dynamic>> get getBasicHealthData async {
    try {
      return await _channel.invokeMethod('getBasicHealthData');
    } catch (e) {
      _logDeviceError("getBasicHealthData", e);
      return {};
    }
  }

  Future<BodyCompositionData?> getBodyFatPercentage(int start, int end) async {
    try {
      final lastFatPercentage = await _channel.invokeMapMethod<String, Object>("getBodyFatPercentageBySegment", {"start": start, "end": end});
      return BodyCompositionData.fromMap(lastFatPercentage);
    } catch (e) {
      _logDeviceError("getBodyFatPercentageBySegment", e);
      return null;
    }
  }

  Future<List<MenstrualData>> getMenstrualData(int start, int end) async {
    List<MenstrualData> result = [];

    // TODO remove after approval of reproductive_health scope
    if (!Platform.isIOS) return result;

    try {
      Map? monthlyCycle = await _channel.invokeMethod('getMenstrualDataBySegment', {"start": start, "end": end});

      monthlyCycle?.cast<int, int>().forEach((int key, int value) {
        final dateTime = DateTime.fromMillisecondsSinceEpoch(key);
        result.add(MenstrualData.fromRawData(dateTime, value));
      });

      return result;
    } catch (e) {
      _logDeviceError("getMenstrualDataBySegment", e);
      return [];
    }
  }

  Future<Map<DateTime, double>?> getWaistSize(int start, int end, {QuantityUnit unit = QuantityUnit.cm}) async {
    try {
      Map? last =
      await _channel.invokeMethod('getWaistSizeBySegment', {"start": start, "end": end, "unit": unit.stringValue});
      return last?.cast<int, double>().map((int key, double value) {
        final dateTime = DateTime.fromMillisecondsSinceEpoch(key);
        return MapEntry(dateTime, value);
      });
    } catch (e) {
      _logDeviceError("getWaistSizeBySegment", e);
      return null;
    }
  }

  Future<BodyCompositionData?> getWeight(int start, int end) async {
    try {
      final lastWeight = await _channel.invokeMapMethod<String, Object>("getWeightInInterval", {"start": start, "end": end});
      return BodyCompositionData.fromMap(lastWeight);
    } catch (e) {
      _logDeviceError("getWeightInInterval", e);
      return null;
    }
  }

  /// Get latest heart rate sample in the period (for both Platforms).
  Future<HeartRateSample?> getLatestHeartRate(int start, int end) async {
    try {
      final sample = await _channel.invokeMapMethod<String, dynamic>("getLatestHeartRate", {"start": start, "end": end});
      return sample == null ? null : HeartRateSample.fromMap(sample);
    } catch (e) {
      _logDeviceError("getLatestHeartRate", e);
      return null;
    }
  }

  /// This method is for iOS only, on Android we only have [HeartRateSample.getAverageHeartRate]
  /// and [HeartRateSample.getLatestHeartRate].
  Future<HeartRateSample?> getAverageWalkingHeartRate(int start, int end) async {
    if (!Platform.isIOS) return null;

    try {
      final sample =
      await _channel.invokeMapMethod<String, dynamic>("getAverageWalkingHeartRate", {"start": start, "end": end});
      return sample == null ? null : HeartRateSample.fromMap(sample);
    } catch (e) {
      _logDeviceError("getAverageWalkingHeartRate", e);
      return null;
    }
  }

  /// This method is for iOS only, on Android we only have [HeartRateSample.getAverageHeartRate].
  /// and [HeartRateSample.getLatestHeartRate]
  Future<HeartRateSample?> getAverageRestingHeartRate(int start, int end) async {
    if (!Platform.isIOS) return null;

    try {
      final sample =
      await _channel.invokeMapMethod<String, dynamic>("getAverageRestingHeartRate", {"start": start, "end": end});
      return sample == null ? null : HeartRateSample.fromMap(sample);
    } catch (e) {
      _logDeviceError("getAverageRestingHeartRate", e);
      return null;
    }
  }

  Future<HeartRateSample?> getAverageHeartRate(int start, int end) async {
    try {
      final sample = await _channel.invokeMapMethod<String, dynamic>("getAverageHeartRate", {"start": start, "end": end});
      return sample == null ? null : HeartRateSample.fromMap(sample);
    } catch (e) {
      _logDeviceError("getAverageHeartRate", e);
      return null;
    }
  }

  /// This method is for iOS only, no heart rate variability available on Android.
  Future<HeartRateSample?> getAverageHeartRateVariability(int start, int end) async {
    if (!Platform.isIOS) return null;

    try {
      final sample =
      await _channel.invokeMapMethod<String, dynamic>("getAverageHeartRateVariability", {"start": start, "end": end});
      return sample == null ? null : HeartRateSample.fromMap(sample);
    } catch (e) {
      _logDeviceError("getAverageHeartRateVariability", e);
      return null;
    }
  }

  /// This method is for iOS only, Blood Glucose not authorized on Android.
  Future<List<HealthFitDataPointValue>?> getBloodGlucose(int start, int end) async {
    if (!Platform.isIOS) return null;

    try {
      Map? samples = await _channel.invokeMethod('getBloodGlucose', {"start": start, "end": end});
      return HFDataPointOutput.fromMap(samples).values;
    } catch (e) {
      _logDeviceError("getBloodGlucose", e);
      return null;
    }
  }

  /// This method is for iOS only, no forced vital capacity available on Android.
  Future<List<HealthFitDataPointValue>?> getForcedVitalCapacity(int start, int end) async {
    if (!Platform.isIOS) return null;

    try {
      Map? samples = await _channel.invokeMethod('getForcedVitalCapacity', {"start": start, "end": end});
      return HFDataPointOutput.fromMap(samples).values;
    } catch (e) {
      _logDeviceError("getForcedVitalCapacity", e);
      return null;
    }
  }

  /// This method is for iOS only, no peak expiratory flow rate available on Android.
  Future<List<HealthFitDataPointValue>?> getPeakExpiratoryFlowRate(int start, int end) async {
    if (!Platform.isIOS) return null;

    try {
      Map? samples = await _channel.invokeMethod('getPeakExpiratoryFlowRate', {"start": start, "end": end});
      return HFDataPointOutput.fromMap(samples).values;
    } catch (e) {
      _logDeviceError("getPeakExpiratoryFlowRate", e);
      return null;
    }
  }

  Future<Map<DateTime, int>> getStepsBySegment(int start, int end, int duration, TimeUnit unit) async {
    try {
      Map stepsByTimestamp = await _channel
          .invokeMethod("getStepsBySegment", {"start": start, "end": end, "duration": duration, "unit": unit.index});
      return stepsByTimestamp.cast<int, int>().map((int key, int value) {
        var dateTime = DateTime.fromMillisecondsSinceEpoch(key);
        dateTime = DateTime(dateTime.year, dateTime.month, dateTime.day); // remove hours, minutes, seconds
        return MapEntry(dateTime, value);
      });
    } catch (e) {
      _logDeviceError("getStepsBySegment", e);
      return {};
    }
  }

  Future<List<WorkoutSample>?> getWorkoutsBySegment(int start, int end) async {
    try {
      List<Map>? rawSamples = await _channel.invokeListMethod<Map>("getWorkoutsBySegment", {"start": start, "end": end});
      return rawSamples?.map((e) => WorkoutSample.fromMap(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      _logDeviceError("getWorkoutsBySegment", e);
      return null;
    }
  }

  Future<Map<DateTime, int>> getFlightsBySegment(int start, int end, int duration, TimeUnit unit) async {
    try {
      Map flightsByTimestamp = await _channel
          .invokeMethod("getFlightsBySegment", {"start": start, "end": end, "duration": duration, "unit": unit.index});
      return flightsByTimestamp.cast<int, int>().map((int key, int value) {
        var dateTime = DateTime.fromMillisecondsSinceEpoch(key);
        dateTime = DateTime(dateTime.year, dateTime.month, dateTime.day); // remove hours, minutes, seconds
        return MapEntry(dateTime, value);
      });
    } catch (e) {
      _logDeviceError("getFlightsBySegment", e);
      return {};
    }
  }

  Future<Map<DateTime, double>> getCyclingBySegment(int start, int end, int duration, TimeUnit unit) async {
    try {
      Map cyclingByTimestamp = await _channel.invokeMethod(
          "getCyclingDistanceBySegment", {"start": start, "end": end, "duration": duration, "unit": unit.index});
      return cyclingByTimestamp.cast<int, double>().map((int key, double value) {
        var dateTime = DateTime.fromMillisecondsSinceEpoch(key);
        dateTime = DateTime(dateTime.year, dateTime.month, dateTime.day); // remove hours, minutes, seconds
        return MapEntry(dateTime, value);
      });
    } catch (e) {
      _logDeviceError("getCyclingDistanceBySegment", e);
      return {};
    }
  }

  Future<int?> getTotalStepsInInterval(int start, int end) async {
    try {
      final steps = await _channel.invokeMethod("getTotalStepsInInterval", {"start": start, "end": end});
      return steps;
    } catch (e) {
      _logDeviceError("getTotalStepsInInterval", e);
      return null;
    }
  }

  /// On Android we want to sign out from Google Fit on the logout
  Future<void> signOut() async {
    if (!Platform.isAndroid) return;

    try {
      return _channel.invokeMethod("signOut");
    } catch (e) {
      _logDeviceError("signOut", e);
      return;
    }
  }

  /// Returns the sleep data from HealthKit.
  ///
  /// params: [start], [end] in milliseconds, starting from epoch time.
  Future<List<SleepSample>?> getSleepIOS(int start, int end) async {
    if (!Platform.isIOS) return null;

    try {
      List<Map>? rawSamples = await _channel.invokeListMethod<Map>("getSleepBySegment", {"start": start, "end": end});
      return rawSamples?.map((e) => SleepSample.fromMap(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      _logDeviceError("getSleepBySegment", e);
      return null;
    }
  }

  /// Returns the sleep data from GoogleFit.
  ///
  /// params: [start], [end] in milliseconds, starting from epoch time.
  Future<List<GFSleepSample>?> getSleepAndroid(int start, int end) async {
    if (!Platform.isAndroid) return null;

    try {
      List<Map>? rawSamples = await _channel.invokeListMethod<Map>("getSleepBySegment", {"start": start, "end": end});
      return rawSamples?.map((e) => GFSleepSample.fromMap(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      _logDeviceError("getSleepBySegment", e);
      return null;
    }
  }

  /// Calories returned in kCal for a given dated range, separated by sources.
  /// Note: Functionality for iOS only, on Android [null] value immediately returned.
  Future<Map<String, int>?> getEnergyConsumed(int start, int end) async {
    if (!Platform.isIOS) return null;

    try {
      return await _channel.invokeMapMethod<String, int>("getEnergyConsumed", {"start": start, "end": end});
    } catch (e) {
      _logDeviceError("getEnergyConsumed", e);
      return null;
    }
  }

  /// Fiber returned in grams for a given dated range, separated by sources.
  /// Note: Functionality for iOS only, on Android [null] value immediately returned.
  Future<Map<String, int>?> getFiberConsumed(int start, int end) async {
    if (!Platform.isIOS) return null;

    try {
      return await _channel.invokeMapMethod<String, int>("getFiberConsumed", {"start": start, "end": end});
    } catch (e) {
      _logDeviceError("getFiberConsumed", e);
      return null;
    }
  }

  /// Fiber returned in grams for a given dated range, separated by sources.
  /// Note: Functionality for iOS only, on Android [null] value immediately returned.
  Future<Map<String, int>?> getCarbsConsumed(int start, int end) async {
    if (!Platform.isIOS) return null;

    try {
      return await _channel.invokeMapMethod<String, int>("getCarbsConsumed", {"start": start, "end": end});
    } catch (e) {
      _logDeviceError("getCarbsConsumed", e);
      return null;
    }

  }

  /// Sugar returned in grams for a given dated range, separated by sources.
  /// Note: Functionality for iOS only, on Android [null] value immediately returned.
  Future<Map<String, int>?> getSugarConsumed(int start, int end) async {
    if (!Platform.isIOS) return null;

    try {
      return await _channel.invokeMapMethod<String, int>("getSugarConsumed", {"start": start, "end": end});
    } catch (e) {
      _logDeviceError("getSugarConsumed", e);
      return null;
    }
  }

  /// Fat returned in grams for a given dated range, separated by sources.
  /// Note: Functionality for iOS only, on Android [null] value immediately returned.
  Future<Map<String, int>?> getFatConsumed(int start, int end) async {
    if (!Platform.isIOS) return null;

    try {
      return await _channel.invokeMapMethod<String, int>("getFatConsumed", {"start": start, "end": end});
    } catch (e) {
      _logDeviceError("getFatConsumed", e);
      return null;
    }
  }

  /// Protein returned in grams for a given dated range, separated by sources.
  /// Note: Functionality for iOS only, on Android [null] value immediately returned.
  Future<Map<String, int>?> getProteinConsumed(int start, int end) async {
    if (!Platform.isIOS) return null;

    try {
      return _channel.invokeMapMethod<String, int>("getProteinConsumed", {"start": start, "end": end});
    } catch (e) {
      _logDeviceError("getProteinConsumed", e);
      return null;
    }
  }

  Future<double?> get getWalkingAndRunningDistance async {
    return await _getActivityData(_ActivityType.walkRun, "m");
  }

  Future<double?> _getActivityData(_ActivityType activityType, String units) async {
    var result;

    try {
      result =
          await _channel.invokeMethod('getActivity', {"name": activityType.toString().split(".").last, "units": units});
    } catch (e) {
      _logDeviceError("getActivity", e);
      return null;
    }

    if (result == null || result.isEmpty) {
      return null;
    }

    return result["value"];
  }

  Future<List<String>?> getStepSourceList() async {
    ///
    /// Not supported for Android yet
    if (Platform.isIOS) {
      try {
        return List<String>.from(await _channel.invokeMethod('getStepsSources'));
      } catch (e) {
        _logDeviceError("getStepsSources", e);
        return null;
      }
    } else {
      return null;
    }
  }

  void _logDeviceError(String method, Object e) {
    if (e is PlatformException) {
      if (e.code == "healthkit not available") {
        logger?.info("healthkit not available");
      }
      else if (e.code == "background call") {
        logger?.info("$method was called in background");
      }
      else {
        logger?.severe("Error when calleing $method. ${e.code}: ${e.message}");
      }
    }
    else {
      logger?.severe("Error when calleing $method. ${e.toString()}");
    }
  }
}
