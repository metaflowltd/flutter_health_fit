import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

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
  other,
}

class WorkoutSample {
  final String id;
  final WorkoutSampleType type;
  final DateTime start;
  final DateTime end;
  final double? energy; // kilo-Calories
  final double? distance; // meters
  final String source;

  WorkoutSample({
    required this.id,
    required this.type,
    required this.start,
    required this.end,
    required this.energy,
    required this.distance,
    required this.source,
  });

  @override
  String toString() {
    return 'WorkoutSample{id: $id, type: $type, start: $start, end: $end, energy: $energy, distance: $distance, source: $source}';
  }

  WorkoutSample.fromMap(Map<String, dynamic> map)
      : id = map["id"].toString(),
        type = _typeFromInt(map["type"].toInt()),
        start = DateTime.fromMillisecondsSinceEpoch(map["start"]),
        end = DateTime.fromMillisecondsSinceEpoch(map["end"]),
        energy = map["energy"],
        distance = map["distance"],
        source = map["source"];

  static WorkoutSampleType _typeFromInt(int input) {
    switch (input) {
      case 1:
        return WorkoutSampleType.americanFootball;
      case 2:
        return WorkoutSampleType.archery;
      case 3:
        return WorkoutSampleType.australianFootball;
      case 4:
        return WorkoutSampleType.badminton;
      case 5:
        return WorkoutSampleType.baseball;
      case 6:
        return WorkoutSampleType.basketball;
      case 7:
        return WorkoutSampleType.bowling;
      case 8:
        return WorkoutSampleType.boxing;
      case 9:
        return WorkoutSampleType.climbing;
      case 10:
        return WorkoutSampleType.cricket;
      case 11:
        return WorkoutSampleType.crossTraining;
      case 12:
        return WorkoutSampleType.curling;
      case 13:
        return WorkoutSampleType.cycling;
      case 14:
        return WorkoutSampleType.dance;
      case 15:
        return WorkoutSampleType.danceInspiredTraining;
      case 16:
        return WorkoutSampleType.elliptical;
      case 17:
        return WorkoutSampleType.equestrianSports;
      case 18:
        return WorkoutSampleType.fencing;
      case 19:
        return WorkoutSampleType.fishing;
      case 20:
        return WorkoutSampleType.functionalStrengthTraining;
      case 21:
        return WorkoutSampleType.golf;
      case 22:
        return WorkoutSampleType.gymnastics;
      case 23:
        return WorkoutSampleType.handball;
      case 24:
        return WorkoutSampleType.hiking;
      case 25:
        return WorkoutSampleType.hockey;
      case 26:
        return WorkoutSampleType.hunting;
      case 27:
        return WorkoutSampleType.lacrosse;
      case 28:
        return WorkoutSampleType.martialArts;
      case 29:
        return WorkoutSampleType.mindAndBody;
      case 30:
        return WorkoutSampleType.mixedMetabolicCardioTraining;
      case 31:
        return WorkoutSampleType.paddleSports;
      case 32:
        return WorkoutSampleType.play;
      case 33:
        return WorkoutSampleType.preparationAndRecovery;
      case 34:
        return WorkoutSampleType.racquetball;
      case 35:
        return WorkoutSampleType.rowing;
      case 36:
        return WorkoutSampleType.rugby;
      case 37:
        return WorkoutSampleType.running;
      case 38:
        return WorkoutSampleType.sailing;
      case 39:
        return WorkoutSampleType.skatingSports;
      case 40:
        return WorkoutSampleType.snowSports;
      case 41:
        return WorkoutSampleType.soccer;
      case 42:
        return WorkoutSampleType.softball;
      case 43:
        return WorkoutSampleType.squash;
      case 44:
        return WorkoutSampleType.stairClimbing;
      case 45:
        return WorkoutSampleType.surfingSports;
      case 46:
        return WorkoutSampleType.swimming;
      case 47:
        return WorkoutSampleType.tableTennis;
      case 48:
        return WorkoutSampleType.tennis;
      case 49:
        return WorkoutSampleType.trackAndField;
      case 50:
        return WorkoutSampleType.traditionalStrengthTraining;
      case 51:
        return WorkoutSampleType.volleyball;
      case 52:
        return WorkoutSampleType.walking;
      case 53:
        return WorkoutSampleType.waterFitness;
      case 54:
        return WorkoutSampleType.waterPolo;
      case 55:
        return WorkoutSampleType.waterSports;
      case 56:
        return WorkoutSampleType.wrestling;
      case 57:
        return WorkoutSampleType.yoga;
      case 58:
        return WorkoutSampleType.barre;
      case 59:
        return WorkoutSampleType.coreTraining;
      case 60:
        return WorkoutSampleType.crossCountrySkiing;
      case 61:
        return WorkoutSampleType.downhillSkiing;
      case 62:
        return WorkoutSampleType.flexibility;
      case 63:
        return WorkoutSampleType.highIntensityIntervalTraining;
      case 64:
        return WorkoutSampleType.jumpRope;
      case 65:
        return WorkoutSampleType.kickboxing;
      case 66:
        return WorkoutSampleType.pilates;
      case 67:
        return WorkoutSampleType.snowboarding;
      case 68:
        return WorkoutSampleType.stairs;
      case 69:
        return WorkoutSampleType.stepTraining;
      case 70:
        return WorkoutSampleType.wheelchairWalkPace;
      case 71:
        return WorkoutSampleType.wheelchairRunPace;
      case 72:
        return WorkoutSampleType.taiChi;
      case 73:
        return WorkoutSampleType.mixedCardio;
      case 74:
        return WorkoutSampleType.handCycling;
      case 75:
        return WorkoutSampleType.discSports;
      case 76:
        return WorkoutSampleType.fitnessGaming;
      case 77:
        return WorkoutSampleType.cardioDance;
      case 78:
        return WorkoutSampleType.socialDance;
      case 79:
        return WorkoutSampleType.pickleball;
      case 80:
        return WorkoutSampleType.cooldown;
      case 3000:
        return WorkoutSampleType.other;
      default:
        print("ERROR unable to detect workout type");
        return WorkoutSampleType.other;
    }
  }
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
    final status = await _channel.invokeMethod("isAuthorized");
    return status;
  }

  /// This stream exposes native logs coming from the plugin, in order to be able
  /// debug
  Stream<String>? get androidNativeLogsMessages =>
      Platform.isAndroid ? _logsChannel.receiveBroadcastStream().map((event) => event as String) : null;

  /// Checks if any health permission has been authorized
  Future<bool> isAnyPermissionAuthorized() async {
    final status = await _channel.invokeMethod("isAnyPermissionAuthorized");
    return status;
  }

  /// Checks if steps permission has been authorized
  Future<bool> isStepsAuthorized() async {
    final status = await _channel.invokeMethod("isStepsAuthorized");
    return status;
  }

  /// Checks if cycling permission has been authorized
  Future<bool> isCyclingAuthorized() async {
    final status = await _channel.invokeMethod("isCyclingAuthorized");
    return status;
  }

  /// Checks if flights climbed permission has been authorized
  Future<bool> isFlightsAuthorized() async {
    final status = await _channel.invokeMethod("isFlightsAuthorized");
    return status;
  }

  /// Checks if sleep permission has been authorized
  Future<bool> isSleepAuthorized() async {
    final status = await _channel.invokeMethod("isSleepAuthorized");
    return status;
  }

  /// Checks if workouts permission has been authorized
  Future<bool> isWorkoutsAuthorized() async {
    final status = await _channel.invokeMethod("isWorkoutsAuthorized");
    return status;
  }

  /// Checks if Waist Size permission has been authorized
  Future<bool> isWaistSizeAuthorized() async {
    final status = await _channel.invokeMethod("isWaistSizeAuthorized");
    return status;
  }

  /// Checks if Body Fat permission has been authorized
  Future<bool> isBodyFatPercentageAuthorized() async {
    final status = await _channel.invokeMethod("isBodyFatPercentageAuthorized");
    return status;
  }

  /// Checks if HRV permission has been authorized
  Future<bool> isHRVAuthorized() async {
    if (!Platform.isIOS) return false;

    final status = await _channel.invokeMethod("isHRVAuthorized");
    return status;
  }

  /// Checks if menstrual data permission has been authorized
  Future<bool> isMenstrualDataAuthorized() async {
    final status = await _channel.invokeMethod("isMenstrualDataAuthorized");
    return status;
  }

  /// Checks if weight permission has been authorized
  Future<bool> isWeightAuthorized() async {
    final status = await _channel.invokeMethod("isWeightAuthorized");
    return status;
  }

  /// Checks if heart rate permission has been authorized
  Future<bool> isHeartRateAuthorized() async {
    final status = await _channel.invokeMethod("isHeartRateAuthorized");
    return status;
  }

  /// Checks if all permissions needed for calculating carb servings have been authorized
  Future<bool> isCarbsAuthorized() async {
    final status = await _channel.invokeMethod("isCarbsAuthorized");
    return status;
  }

  /// Checks if android.permission.BODY_SENSORS is granted.
  /// on iOS returns always true.
  Future<bool> isBodySensorsAuthorized() async {
    if (Platform.isIOS) return true; // irrelevant for iOS. Assume authorized.
    final status = await _channel.invokeMethod("isBodySensorsAuthorized");
    return status;
  }

  /// Will ask to authorize, prompting the user if necessary.
  Future<bool> authorize() async {
    return await _channel.invokeMethod('requestAuthorization');
  }

  /// Will ask to authorize android.permission.BODY_SENSORS permission on Android.
  /// Returns true if user authorized, false if not.
  /// on iOS, returns true immediately and does nothing.
  Future<bool> authorizeBodySensors() async {
    if (Platform.isIOS) return true; // irrelevant for iOS. Assume authorized.
    return await _channel.invokeMethod<bool>('requestBodySensorsPermission') ?? false;
  }

  Future<Map<dynamic, dynamic>> get getBasicHealthData async {
    return await _channel.invokeMethod('getBasicHealthData');
  }

  Future<Map<DateTime, double>?> getBodyFatPercentage(int start, int end) async {
    Map? last = await _channel.invokeMethod(
        'getBodyFatPercentageBySegment', {"start": start, "end": end, "unit": QuantityUnit.percent.stringValue});
    return last?.cast<int, double>().map((int key, double value) {
      final dateTime = DateTime.fromMillisecondsSinceEpoch(key);
      return MapEntry(dateTime, value);
    });
  }

  Future<Map<DateTime, double>?> getHRV(int start, int end, {QuantityUnit unit = QuantityUnit.second}) async {
    if (!Platform.isIOS) return null;

    Map? last = await _channel.invokeMethod('getHRVBySegment', {"start": start, "end": end, "unit": unit.stringValue});
    return last?.cast<int, double>().map((int key, double value) {
      final dateTime = DateTime.fromMillisecondsSinceEpoch(key);
      return MapEntry(dateTime, value);
    });
  }

  Future<Map<DateTime, double>?> getWaistSize(int start, int end, {QuantityUnit unit = QuantityUnit.cm}) async {
    Map? last =
        await _channel.invokeMethod('getWaistSizeBySegment', {"start": start, "end": end, "unit": unit.stringValue});
    return last?.cast<int, double>().map((int key, double value) {
      final dateTime = DateTime.fromMillisecondsSinceEpoch(key);
      return MapEntry(dateTime, value);
    });
  }

  Future<Map<DateTime, double>?> getWeight(int start, int end) async {
    Map? lastWeight = await _channel.invokeMethod('getWeightInInterval', {"start": start, "end": end});
    return lastWeight?.cast<int, double>().map((int key, double value) {
      final dateTime = DateTime.fromMillisecondsSinceEpoch(key);
      return MapEntry(dateTime, value);
    });
  }

  Future<List<MenstrualData>> getMenstrualData(int start, int end) async {
    final List<MenstrualData> result = [];

    Map? monthlyCycle = await _channel.invokeMethod('getMenstrualData', {
      "start": start,
      "end": end,
    });

    monthlyCycle?.cast<int, int>().forEach((int key, int value) {
      final dateTime = DateTime.fromMillisecondsSinceEpoch(key);
      result.add(MenstrualData.fromRawData(dateTime, value));
    });

    return result;
  }

  Future<HeartRateSample?> getLatestHeartRateSample(int start, int end) =>
      _getHeartRate("getHeartRateSample", start, end);

  Future<List<HeartRateSample>> getAverageWalkingHeartRate(int start, int end) =>
      _getAverageHeartRates("getAverageWalkingHeartRate", start, end);

  Future<List<HeartRateSample>> getAverageRestingHeartRate(int start, int end) =>
      _getAverageHeartRates("getAverageRestingHeartRate", start, end);

  Future<HeartRateSample?> _getHeartRate(String methodName, int start, int end) async {
    final sample = await _channel.invokeMapMethod<String, dynamic>(methodName, {"start": start, "end": end});
    return sample == null ? null : HeartRateSample.fromMap(sample);
  }

  Future<List<HeartRateSample>> _getAverageHeartRates(String methodName, int start, int end) async {
    final averageBySource = await _channel.invokeListMethod<Map>(methodName, {"start": start, "end": end});

    if (averageBySource == null || averageBySource.isEmpty) return [];

    return averageBySource.map((Map average) => HeartRateSample.fromMap(Map<String, dynamic>.from(average))).toList();
  }

  Future<Map<DateTime, int>> getStepsBySegment(int start, int end, int duration, TimeUnit unit) async {
    Map stepsByTimestamp = await _channel
        .invokeMethod("getStepsBySegment", {"start": start, "end": end, "duration": duration, "unit": unit.index});
    return stepsByTimestamp.cast<int, int>().map((int key, int value) {
      var dateTime = DateTime.fromMillisecondsSinceEpoch(key);
      dateTime = DateTime(dateTime.year, dateTime.month, dateTime.day); // remove hours, minutes, seconds
      return MapEntry(dateTime, value);
    });
  }

  Future<List<WorkoutSample>?> getWorkoutsBySegment(int start, int end) async {
    if (!Platform.isIOS) return null;
    List<Map>? rawSamples = await _channel.invokeListMethod<Map>("getWorkoutsBySegment", {"start": start, "end": end});
    return rawSamples?.map((e) => WorkoutSample.fromMap(Map<String, dynamic>.from(e))).toList();
  }

  Future<Map<DateTime, int>> getFlightsBySegment(int start, int end, int duration, TimeUnit unit) async {
    Map flightsByTimestamp = await _channel
        .invokeMethod("getFlightsBySegment", {"start": start, "end": end, "duration": duration, "unit": unit.index});
    return flightsByTimestamp.cast<int, int>().map((int key, int value) {
      var dateTime = DateTime.fromMillisecondsSinceEpoch(key);
      dateTime = DateTime(dateTime.year, dateTime.month, dateTime.day); // remove hours, minutes, seconds
      return MapEntry(dateTime, value);
    });
  }

  Future<Map<DateTime, double>> getCyclingBySegment(int start, int end, int duration, TimeUnit unit) async {
    Map cyclingByTimestamp = await _channel.invokeMethod(
        "getCyclingDistanceBySegment", {"start": start, "end": end, "duration": duration, "unit": unit.index});
    return cyclingByTimestamp.cast<int, double>().map((int key, double value) {
      var dateTime = DateTime.fromMillisecondsSinceEpoch(key);
      dateTime = DateTime(dateTime.year, dateTime.month, dateTime.day); // remove hours, minutes, seconds
      return MapEntry(dateTime, value);
    });
  }

  Future<int?> getTotalStepsInInterval(int start, int end) async {
    final steps = await _channel.invokeMethod("getTotalStepsInInterval", {"start": start, "end": end});
    return steps;
  }

  /// On Android we want to sign out from Google Fit on the logout
  Future<void> signOut() async {
    if (!Platform.isAndroid) return;
    return _channel.invokeMethod("signOut");
  }

  /// Returns the sleep data from HealthKit.
  ///
  /// params: [start], [end] in milliseconds, starting from epoch time.
  Future<List<SleepSample>?> getSleepIOS(int start, int end) async {
    if (!Platform.isIOS) return null;
    List<Map>? rawSamples = await _channel.invokeListMethod<Map>("getSleepBySegment", {"start": start, "end": end});
    return rawSamples?.map((e) => SleepSample.fromMap(Map<String, dynamic>.from(e))).toList();
  }

  /// Returns the sleep data from GoogleFit.
  ///
  /// params: [start], [end] in milliseconds, starting from epoch time.
  Future<List<GFSleepSample>?> getSleepAndroid(int start, int end) async {
    if (!Platform.isAndroid) return null;
    List<Map>? rawSamples = await _channel.invokeListMethod<Map>("getSleepBySegment", {"start": start, "end": end});
    return rawSamples?.map((e) => GFSleepSample.fromMap(Map<String, dynamic>.from(e))).toList();
  }

  /// Calories returned in kCal for a given dated range, separated by sources.
  /// Note: Functionality for iOS only, on Android [null] value immediately returned.
  Future<Map<String, int>?> getEnergyConsumed(int start, int end) async {
    if (!Platform.isIOS) return null;

    return await _channel.invokeMapMethod<String, int>("getEnergyConsumed", {"start": start, "end": end});
  }

  /// Fiber returned in grams for a given dated range, separated by sources.
  /// Note: Functionality for iOS only, on Android [null] value immediately returned.
  Future<Map<String, int>?> getFiberConsumed(int start, int end) async {
    if (!Platform.isIOS) return null;

    return await _channel.invokeMapMethod<String, int>("getFiberConsumed", {"start": start, "end": end});
  }

  /// Fiber returned in grams for a given dated range, separated by sources.
  /// Note: Functionality for iOS only, on Android [null] value immediately returned.
  Future<Map<String, int>?> getCarbsConsumed(int start, int end) async {
    if (!Platform.isIOS) return null;

    return await _channel.invokeMapMethod<String, int>("getCarbsConsumed", {"start": start, "end": end});
  }

  /// Sugar returned in grams for a given dated range, separated by sources.
  /// Note: Functionality for iOS only, on Android [null] value immediately returned.
  Future<Map<String, int>?> getSugarConsumed(int start, int end) async {
    if (!Platform.isIOS) return null;

    return await _channel.invokeMapMethod<String, int>("getSugarConsumed", {"start": start, "end": end});
  }

  /// Fat returned in grams for a given dated range, separated by sources.
  /// Note: Functionality for iOS only, on Android [null] value immediately returned.
  Future<Map<String, int>?> getFatConsumed(int start, int end) async {
    if (!Platform.isIOS) return null;

    return await _channel.invokeMapMethod<String, int>("getFatConsumed", {"start": start, "end": end});
  }

  /// Protein returned in grams for a given dated range, separated by sources.
  /// Note: Functionality for iOS only, on Android [null] value immediately returned.
  Future<Map<String, int>?> getProteinConsumed(int start, int end) async {
    if (!Platform.isIOS) return null;

    return _channel.invokeMapMethod<String, int>("getProteinConsumed", {"start": start, "end": end});
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
      print(e.toString());
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
        return null;
      }
    } else {
      return null;
    }
  }
}
