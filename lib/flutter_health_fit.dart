import 'dart:async';

import 'package:flutter/services.dart';

// Current day's accumulated values
enum _ActivityType { steps, cycling, walkRun, heartRate, flights }

class FlutterHealthFit {
  static const MethodChannel _channel = const MethodChannel('flutter_health_fit');

  factory FlutterHealthFit() => _singleton;

  FlutterHealthFit.internal();

  static final _singleton = FlutterHealthFit.internal();

  Future<bool> get isAuthorized async {
    final status = await _channel.invokeMethod("isAuthorized");
    return status;
  }

  Future<bool> authorize() async {
    return await _channel.invokeMethod('requestAuthorization');
  }

  Future<Map<dynamic, dynamic>> get getBasicHealthData async {
    return await _channel.invokeMethod('getBasicHealthData');
  }

  Future<Map<DateTime, int>> getStepsByDay(int start, int end) async {
    Map stepsByTimestamp = await _channel.invokeMethod("getSteps", {"start": start, "end": end});
    return stepsByTimestamp.cast<int, int>().map((int key, int value) {
      var dateTime = DateTime.fromMillisecondsSinceEpoch(key);
      dateTime = DateTime(dateTime.year, dateTime.month, dateTime.day); // remove hours, minutes, seconds
      return MapEntry(dateTime, value);
    });
  }

  Future<double> get getWalkingAndRunningDistance async {
    return await _getActivityData(_ActivityType.walkRun, "m");
  }

  Future<double> get getCyclingDistance async {
    return await _getActivityData(_ActivityType.cycling, "m");
  }

  Future<double> get getFlights async {
    return await _getActivityData(_ActivityType.flights, "count");
  }

  Future<double> _getActivityData(_ActivityType activityType, String units) async {
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
}
