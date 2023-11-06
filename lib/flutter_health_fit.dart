import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_health_fit/data_point_value.dart';
import 'package:flutter_health_fit/data_pointd_output.dart';
import 'package:flutter_health_fit/user_activity_data_point_value.dart';
import 'package:flutter_health_fit/workout_sample.dart';

abstract class HealthFitLog {
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

enum HealthFitAuthorizationStatus {
  /// Stands for successful authorization.
  authorized,
  /// Stands for general unsuccessful authorization.
  unauthorized,
  /// (Android) Specific status for authorization issue due to user cancellation on Android.
  userCancelled,
  /// Stands for other possible issues during authorization process.
  error,
}

/// Authorization result data. It contains [status] which informs of the actual completion result.
/// Optionally may contain [error] in case if the status is [HealthFitAuthorizationStatus.error].
class HealthFitAuthorizationResult {
  final HealthFitAuthorizationStatus status;
  final Object? error;

  HealthFitAuthorizationResult({required this.status, this.error});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is HealthFitAuthorizationResult && runtimeType == other.runtimeType
              && status == other.status && error == other.error;

  @override
  int get hashCode => status.hashCode ^ error.hashCode;
}

// Current day's accumulated values
enum _ActivityType { steps, cycling, walkRun, heartRate, flights }

enum SleepSampleType {
  inBed,
  asleepUnspecified,
  awake,
  asleepREM,
  asleepDeep,
  asleepCore,
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
        return SleepSampleType.asleepUnspecified;
      case 2:
        return SleepSampleType.awake;
      case 3:
        return SleepSampleType.asleepCore;
      case 4:
        return SleepSampleType.asleepDeep;
      case 5:
        return SleepSampleType.asleepREM;

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
  static const aggregatedSourceProvider = "Aggregated";
  static const MethodChannel _channel = const MethodChannel('flutter_health_fit');
  static const EventChannel _workoutsChannel = const EventChannel('flutter_health_fit/workouts');
  static const EventChannel _logsChannel = const EventChannel('flutter_health_fit_logs_channel');
  static HealthFitLog? logger;

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

  /// Checks if BloodGlucose permission has been authorized. Blood Glucose is never authorized on Android.
  Future<bool> isBloodGlucoseAuthorized() async {
    if (!Platform.isIOS) return false;

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

  /// Checks if permissions needed for calculating carb servings have been authorized
  Future<bool> isCarbsConsumedAuthorized() async {
    try {
      final status = await _channel.invokeMethod("isCarbsConsumedAuthorized");
      return status;
    } catch (e) {
      _logDeviceError("isCarbsAuthorized", e);
      return false;
    }
  }

  /// Checks if permissions needed for calculating fiber servings have been authorized
  Future<bool> isFiberConsumedAuthorized() async {
    try {
      final status = await _channel.invokeMethod("isFiberConsumedAuthorized");
      return status;
    } catch (e) {
      _logDeviceError("isFiberConsumedAuthorized", e);
      return false;
    }
  }

  /// Checks if permissions needed for calculating fat servings have been authorized
  Future<bool> isFatConsumedAuthorized() async {
    try {
      final status = await _channel.invokeMethod("isFatConsumedAuthorized");
      return status;
    } catch (e) {
      _logDeviceError("isFatConsumedAuthorized", e);
      return false;
    }
  }

  /// Checks if permissions needed for calculating sugar servings have been authorized
  Future<bool> isSugarConsumedAuthorized() async {
    try {
      final status = await _channel.invokeMethod("isSugarConsumedAuthorized");
      return status;
    } catch (e) {
      _logDeviceError("isSugarConsumedAuthorized", e);
      return false;
    }
  }

  /// Checks if permissions needed for calculating protein servings have been authorized
  Future<bool> isProteinConsumedAuthorized() async {
    try {
      final status = await _channel.invokeMethod("isProteinConsumedAuthorized");
      return status;
    } catch (e) {
      _logDeviceError("isProteinConsumedAuthorized", e);
      return false;
    }
  }

  /// Checks if permissions needed for calculating energy servings have been authorized
  Future<bool> isEnergyConsumedAuthorized() async {
    try {
      final status = await _channel.invokeMethod("isEnergyConsumedAuthorized");
      return status;
    } catch (e) {
      _logDeviceError("isEnergyConsumedAuthorized", e);
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

  /// Checks if permissions needed for resting energy have been authorized
  Future<bool> isRestingEnergyAuthorized() async {
    try {
      final status = await _channel.invokeMethod("isRestingEnergyAuthorized");
      return status;
    } catch (e) {
      _logDeviceError("isRestingEnergyAuthorized", e);
      return false;
    }
  }

  /// Checks if permissions needed for active energy have been authorized
  Future<bool> isActiveEnergyAuthorized() async {
    if (!Platform.isIOS) return false;

    try {
      final status = await _channel.invokeMethod("isActiveEnergyAuthorized");
      return status;
    } catch (e) {
      _logDeviceError("isActiveEnergyAuthorized", e);
      return false;
    }
  }

  /// Will ask to authorize, prompting the user if necessary.
  Future<HealthFitAuthorizationResult> authorize() async {
    HealthFitAuthorizationStatus status;
    Object? error;

    try {
      final authorized = await _channel.invokeMethod('requestAuthorization');
      if (authorized) {
        status = HealthFitAuthorizationStatus.authorized;
      } else {
        status = HealthFitAuthorizationStatus.unauthorized;
      }
    } catch (e) {
      _logDeviceError("requestAuthorization", e);

      // On Android we can recognise if user cancelled the permission flow
      if (Platform.isAndroid && e is PlatformException && e.code == 'canceled') {
        status = HealthFitAuthorizationStatus.userCancelled;
      } else {
        status = HealthFitAuthorizationStatus.error;
        error = e;
      }
    }
    return HealthFitAuthorizationResult(status: status, error: error);
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

  Future<DataPointValue?> getBodyFatPercentage(int start, int end) async {
    try {
      final lastFatPercentage = await _channel.invokeMapMethod<String, Object>("getBodyFatPercentageBySegment", {"start": start, "end": end});
      return DataPointValue.fromMap(lastFatPercentage);
    } catch (e) {
      _logDeviceError("getBodyFatPercentageBySegment", e);
      return null;
    }
  }

  Future<List<DataPointValue>?> getMenstrualData(int start, int end) async {

    try {
      final dataList = await _channel.invokeListMethod<Map>("getMenstrualDataBySegment",
          {"start": start, "end": end});
      final list = dataList?.map((e) =>
          DataPointValue.fromMap(e.map((key, value) => MapEntry(key.toString(), value))))
          .whereType<DataPointValue>().toList();
      return list;
    } catch (e) {
      _logDeviceError("getMenstrualDataBySegment", e);
      return null;
    }
  }

  Future<DataPointValue?> getWaistSize(int start, int end, {QuantityUnit unit = QuantityUnit.cm}) async {
    try {
      final lastSize = await _channel.invokeMapMethod<String, Object>("getWaistSizeBySegment", {"start": start, "end": end});
      return DataPointValue.fromMap(lastSize);
    } catch (e) {
      _logDeviceError("getWaistSizeBySegment", e);
      return null;
    }
  }

  Future<DataPointValue?> getWeight(int start, int end) async {
    try {
      final lastWeight = await _channel.invokeMapMethod<String, Object>("getWeightInInterval", {"start": start, "end": end});
      return DataPointValue.fromMap(lastWeight);
    } catch (e) {
      _logDeviceError("getWeightInInterval", e);
      return null;
    }
  }

  /// Get raw heart rate samples in the period (for both Platforms).
  Future<List<HeartRateSample>?> getRawHeartRate(int start, int end) async {
    try {
      final samples = await _channel.invokeListMethod<Map>("getRawHeartRate", {"start": start, "end": end});
      if (samples == null) {
        return null;
      }

      return samples?.map((e) => HeartRateSample.fromMap(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      _logDeviceError("getLatestHeartRate", e);
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

  Future<UserActivityDataPointValue?> getStepsBySegment(int start, int end) async {
    try {
      logger?.info("calling getStepsBySegment. start: $start, end: $end");
      final dataPointMap = await _channel.invokeMapMethod<String, Object>("getStepsBySegment",
          {"start": start, "end": end});
      final dataPointValue = UserActivityDataPointValue.fromMap(dataPointMap);
      logger?.info("data from getStepsBySegment, ${dataPointValue?.value ?? ""}. start: $start, end: $end");
      return dataPointValue;
    } catch (e) {
      _logDeviceError("getStepsBySegment", e);
      return null;
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

  Future<List<WorkoutSample>?> getWorkoutsSessions(int start, int end) async {
    if (Platform.isIOS) {
      // Not supported on iOS
      return null;
    }

    try {
      List<Map>? rawSamples = await _channel.invokeListMethod<Map>("getWorkoutsSessions", {"start": start, "end": end});
      return rawSamples?.map((e) => WorkoutSample.fromMap(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      _logDeviceError("getWorkoutsSessions", e);
      return null;
    }
  }

  Stream<String> observeWorkouts() {
    try {
      return _workoutsChannel.receiveBroadcastStream().map((event) => '$event');
    } catch (e) {
      _logDeviceError("observeWorkouts", e);
      return Stream.error(e);
    }
  }

  Future<UserActivityDataPointValue?> getFlightsBySegment(int start, int end) async {
    try {
      logger?.info("calling getFlightsBySegment. start: $start, end: $end");
      final dataPointMap = await _channel.invokeMapMethod<String, Object>("getFlightsBySegment",
          {"start": start, "end": end});
      final dataPointValue = UserActivityDataPointValue.fromMap(dataPointMap);
      logger?.info("data from getFlightsBySegment, ${dataPointValue?.value ?? ""}. start: $start, end: $end");
      return dataPointValue;
    } catch (e) {
      _logDeviceError("getFlightsBySegment", e);
      return null;
    }
  }

  Future<UserActivityDataPointValue?> getCyclingBySegment(int start, int end) async {
    try {
      logger?.info("calling getCyclingBySegment. start: $start, end: $end");
      final dataPointMap = await _channel.invokeMapMethod<String, Object>("getCyclingDistanceBySegment",
          {"start": start, "end": end});
      final dataPointValue = UserActivityDataPointValue.fromMap(dataPointMap);
      logger?.info("data from getCyclingBySegment, ${dataPointValue?.value ?? ""}. start: $start, end: $end");
      return dataPointValue;
    } catch (e) {
      _logDeviceError("getCyclingBySegment", e);
      return null;
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

  Future<List<DataPointValue>?> getActiveEnergy(int start, int end) async {
    if (!Platform.isIOS) return null;

    try {
      final dataList = await _channel.invokeListMethod<Map>("getActiveEnergy",
          {"start": start, "end": end});
      final list = dataList?.map((e) =>
          DataPointValue.fromMap(e.map((key, value) => MapEntry(key.toString(), value))))
          .whereType<DataPointValue>().toList();
      return list;
    } catch (e) {
      _logDeviceError("getActiveEnergy", e);
      return null;
    }
  }

  Future<DataPointValue?> getRestingEnergy(int start, int end) async {
    try {
      final dataPointMap = await _channel.invokeMapMethod<String, Object>("getRestingEnergy",
          {"start": start, "end": end});
      final dataPointValue = DataPointValue.fromMap(dataPointMap);
      return dataPointValue;
    } catch (e) {
      _logDeviceError("getRestingEnergy", e);
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

  /// Returns the raw sleep data retrieved from the health data provider for the requested time range.
  ///
  /// params: [start], [end] in milliseconds, starting from epoch time.
  Future<List<Map<String, dynamic>>?> getRawSleepDataInRange(int start, int end) async {
    try {
      final List<Map>? rawSleepData = await _channel.invokeListMethod<Map>(
          "getRawSleepDataInRange", {"start": start, "end": end});
      return rawSleepData?.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      _logDeviceError("getRawSleepDataInRange", e);
      return null;
    }
  }


  /// Calories returned in kCal for a given dated range, separated by sources.
  /// Note: Functionality for iOS only, on Android [null] value immediately returned.
  Future<List<DataPointValue>?> getEnergyConsumed(int start, int end) async {
    try {
      final dataList = await _channel.invokeListMethod<Map>("getEnergyConsumed",
          {"start": start, "end": end});
      final list = dataList?.map((e) =>
          DataPointValue.fromMap(e.map((key, value) => MapEntry(key.toString(), value))))
          .whereType<DataPointValue>().toList();
      return list;
    } catch (e) {
      _logDeviceError("getEnergyConsumed", e);
      return null;
    }
  }

  /// Fiber returned in grams for a given dated range, separated by sources.
  /// Note: Functionality for iOS only, on Android [null] value immediately returned.
  Future<List<DataPointValue>?> getFiberConsumed(int start, int end) async {
    try {
      final dataList = await _channel.invokeListMethod<Map>("getFiberConsumed",
          {"start": start, "end": end});
      final list = dataList?.map((e) =>
          DataPointValue.fromMap(e.map((key, value) => MapEntry(key.toString(), value))))
          .whereType<DataPointValue>().toList();
      return list;
    } catch (e) {
      _logDeviceError("getFiberConsumed", e);
      return null;
    }
  }

  /// Fiber returned in grams for a given dated range, separated by sources.
  /// Note: Functionality for iOS only, on Android [null] value immediately returned.
  Future<List<DataPointValue>?> getCarbsConsumed(int start, int end) async {
    try {
      final dataList = await _channel.invokeListMethod<Map>("getCarbsConsumed",
          {"start": start, "end": end});
      final list = dataList?.map((e) =>
          DataPointValue.fromMap(e.map((key, value) => MapEntry(key.toString(), value))))
          .whereType<DataPointValue>().toList();
      return list;
    } catch (e) {
      _logDeviceError("getCarbsConsumed", e);
      return null;
    }

  }

  /// Sugar returned in grams for a given dated range, separated by sources.
  /// Note: Functionality for iOS only, on Android [null] value immediately returned.
  Future<List<DataPointValue>?> getSugarConsumed(int start, int end) async {
    try {
      final dataList = await _channel.invokeListMethod<Map>("getSugarConsumed",
          {"start": start, "end": end});
      final list = dataList?.map((e) =>
          DataPointValue.fromMap(e.map((key, value) => MapEntry(key.toString(), value))))
          .whereType<DataPointValue>().toList();
      return list;
    } catch (e) {
      _logDeviceError("getSugarConsumed", e);
      return null;
    }
  }

  /// Fat returned in grams for a given dated range, separated by sources.
  /// Note: Functionality for iOS only, on Android [null] value immediately returned.
  Future<List<DataPointValue>?> getFatConsumed(int start, int end) async {
    try {
      final dataList = await _channel.invokeListMethod<Map>("getFatConsumed",
          {"start": start, "end": end});
      final list = dataList?.map((e) =>
          DataPointValue.fromMap(e.map((key, value) => MapEntry(key.toString(), value))))
          .whereType<DataPointValue>().toList();
      return list;
    } catch (e) {
      _logDeviceError("getFatConsumed", e);
      return null;
    }
  }

  /// Protein returned in grams for a given dated range, separated by sources.
  /// Note: Functionality for iOS only, on Android [null] value immediately returned.
  Future<List<DataPointValue>?> getProteinConsumed(int start, int end) async {
    try {
      final dataList = await _channel.invokeListMethod<Map>("getProteinConsumed",
          {"start": start, "end": end});
      final list = dataList?.map((e) =>
          DataPointValue.fromMap(e.map((key, value) => MapEntry(key.toString(), value))))
          .whereType<DataPointValue>().toList();
      return list;
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
      else {
        logger?.severe("Error when calleing $method. ${e.code}: ${e.message}, details-${e.details ?? ""}");
      }
    }
    else {
      logger?.severe("Error when calleing $method. ${e.toString()}");
    }
  }
}
