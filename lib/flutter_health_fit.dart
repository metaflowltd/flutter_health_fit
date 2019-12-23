import 'dart:async';

import 'package:flutter/services.dart';

// Current day's accumulated values
enum _ActivityType{ steps, cycling, walkRun, heartRate, flights }

class FlutterHealthFit {
  static const MethodChannel _channel =
      const MethodChannel('flutter_health_fit');

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  static Future<bool> get authorize async {
    return await _channel.invokeMethod('requestAuthorization');
  }

  static Future<Map<dynamic, dynamic>> get getBasicHealthData async {
    return await _channel.invokeMethod('getBasicHealthData');
  }

  static Future<double> get getSteps async {
    return await _getActivityData(_ActivityType.steps, "count");
  }

  static Future<Map<dynamic, dynamic>> getStepsBeforeDays(int startDateInDays) async {
    final data = await _channel.invokeMethod("startDateInDays",startDateInDays);
    return data;
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
