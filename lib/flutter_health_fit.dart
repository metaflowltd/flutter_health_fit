import 'dart:async';

import 'package:flutter/services.dart';

// Current day's accumulated values
enum _ActivityType{ cycling, walkRun, heartRate, flights }

class FlutterHealthFit {
  static const MethodChannel _channel =
      const MethodChannel('flutter_health_fit');

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  static Future<bool> get isAuthorized async {
    return await _channel.invokeMethod("isAuthorized");
  }

  static Future<bool> authorize() async {
    return await _channel.invokeMethod('requestAuthorization');
  }

  static Future<Map<dynamic, dynamic>> get getBasicHealthData async {
    return await _channel.invokeMethod('getBasicHealthData');
  }

  static Future<Map<DateTime, int>> getStepsByDay(int start, int end) async {
    Map stepsByTimestamp = await _channel.invokeMethod("getSteps", {"start": start, "end": end});
    return stepsByTimestamp.cast<int, int>().map((int key, int value) {
      var dateTime = DateTime.fromMillisecondsSinceEpoch(key);
      dateTime = DateTime(dateTime.year, dateTime.month, dateTime.day); // remove hours, minutes, seconds
      return MapEntry(dateTime, value);
    });
  }

  static Future<double> get getWalkingAndRunningDistance async {
    return await _getActivityData(_ActivityType.walkRun, "m");
  }

  static Future<double> get geCyclingDistance async {
    return await _getActivityData(_ActivityType.cycling, "m");
  }

  static Future<double> get getFlights async {
    return await _getActivityData(_ActivityType.flights, "count");
  }

  static Future<double> _getActivityData(_ActivityType activityType, String units) async {
    var result;

    try {
      result = await _channel.invokeMethod(
          'getActivity',
          {
            "name": activityType
                .toString()
                .split(".")
                .last,
            "units": units
          }
      );
    }
    catch (e) {
      print(e.toString());
      return null;
    }

    if (result == null || result.isEmpty){
      return null;
    }

    return result["value"];
  }
}
