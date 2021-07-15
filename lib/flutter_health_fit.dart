import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

enum TimeUnit { minutes, days }

// Current day's accumulated values
enum _ActivityType { steps, cycling, walkRun, heartRate, flights }

enum SleepSampleType { inBed, asleep, awake }

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
  ///
  /// [useSensitive] on Android, if this is true, will also check missing permissions of sensitive and restricted scopes, such as heart rate.
  /// https://support.google.com/cloud/answer/9110914#sensitive-scopes
  /// https://support.google.com/cloud/answer/9110914#restricted-scopes
  /// On iOS has no meaning.
  Future<bool> isAuthorized({bool? useSensitive}) async {
    final status = await _channel.invokeMethod("isAuthorized", {"useSensitive": useSensitive});
    return status;
  }

  /// Checks if any health permission has been authorized
  Future<bool> isAnyPermissionAuthorized({bool? useSensitive}) async {
    final status = await _channel.invokeMethod("isAnyPermissionAuthorized", {"useSensitive": useSensitive});
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

  /// Will ask to authorize, prompting the user if necessary.
  /// [useSensitive] on Android, if this is true, will also ask permissions of sensitive and restricted scopes, such as heart rate.
  /// https://support.google.com/cloud/answer/9110914#sensitive-scopes
  /// https://support.google.com/cloud/answer/9110914#restricted-scopes
  /// On iOS has no meaning.
  Future<bool> authorize(bool? useSensitive) async {
    return await _channel.invokeMethod('requestAuthorization', {"useSensitive": useSensitive});
  }

  Future<Map<dynamic, dynamic>> get getBasicHealthData async {
    return await _channel.invokeMethod('getBasicHealthData');
  }

  Future<Map<DateTime, double>?> getWeight(int start, int end) async {
    Map? lastWeight = await _channel.invokeMethod('getWeightInInterval', {"start": start, "end": end});
    return lastWeight?.cast<int, double>().map((int key, double value) {
      final dateTime = DateTime.fromMillisecondsSinceEpoch(key);
      return MapEntry(dateTime, value);
    });
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

  Future<int> getTotalStepsInInterval(int start, int end) async {
    final steps = await _channel.invokeMethod("getTotalStepsInInterval", {"start": start, "end": end});
    return steps;
  }

  /// Returns the sleep data from HealthKit.
  ///
  /// params: [start], [end] in milliseconds, starting from epoch time.
  Future<List<SleepSample>?> getSleep(int start, int end) async {
    if (!Platform.isIOS) return null;

    List<Map>? rawSamples = await _channel.invokeListMethod<Map>("getSleepBySegment", {"start": start, "end": end});
    return rawSamples?.map((e) => SleepSample.fromMap(Map<String, dynamic>.from(e))).toList();
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
