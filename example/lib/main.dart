import 'package:flutter/material.dart';
import 'package:flutter_health_fit/flutter_health_fit.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isAuthorized = false;
  String _basicHealthString = "";
  String _lastWeightString = "";
  String _activityData = "";
  String _heartData = "";

  Future _authorizeHealthOrFit() async {
    bool isAuthorized = await FlutterHealthFit().authorize(true);
    setState(() {
      _isAuthorized = isAuthorized;
    });
  }

  Future _getUserBasicHealthData() async {
    var basicHealth = await FlutterHealthFit().getBasicHealthData;
    setState(() {
      _basicHealthString = basicHealth.toString();
    });
  }

  Future _getLast3DaysWeight() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final last3Days = DateTime.now().subtract(Duration(days: 4)).millisecondsSinceEpoch;
    final lastWeight = await FlutterHealthFit().getWeight(last3Days, now);
    setState(() {
      _lastWeightString = lastWeight.toString();
    });
  }

  Future _getActivityHealthData() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final steps = await FlutterHealthFit()
        .getStepsBySegment(yesterday.millisecondsSinceEpoch, today.millisecondsSinceEpoch, 1, TimeUnit.days);
    final running = await FlutterHealthFit().getWalkingAndRunningDistance;
    final cycle = await FlutterHealthFit()
        .getCyclingBySegment(yesterday.millisecondsSinceEpoch, today.millisecondsSinceEpoch, 1, TimeUnit.days);
    final flights = await FlutterHealthFit()
        .getFlightsBySegment(yesterday.millisecondsSinceEpoch, today.millisecondsSinceEpoch, 1, TimeUnit.days);
    setState(() {
      _activityData = "steps: $steps\nwalking running: $running\ncycle: $cycle flights: $flights";
    });
  }

  _getHeartData() async {
    final now = DateTime.now();
    final yesterday = now.subtract(Duration(days: 1));
    final current =
        await FlutterHealthFit().getLatestHeartRateSample(yesterday.millisecondsSinceEpoch, now.millisecondsSinceEpoch);
    final resting = await FlutterHealthFit()
        .getAverageRestingHeartRate(yesterday.millisecondsSinceEpoch, now.millisecondsSinceEpoch);
    final walking = await FlutterHealthFit()
        .getAverageWalkingHeartRate(yesterday.millisecondsSinceEpoch, now.millisecondsSinceEpoch);
    setState(() {
      _heartData = "current: $current\nresting: $resting\nwalking: $walking";
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('Plugin example app'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                Text('Authorized: $_isAuthorized\n'),
                RaisedButton(child: Text("Authorize Health"), onPressed: _authorizeHealthOrFit),
                RaisedButton(child: Text("Get basic data"), onPressed: _getUserBasicHealthData),
                Text('Basic health: $_basicHealthString\n'),
                RaisedButton(child: Text("Get Last 3 Days Weight"), onPressed: _getLast3DaysWeight),
                Text('last weight: $_lastWeightString\n'),
                RaisedButton(child: Text("Get Activity Data"), onPressed: _getActivityHealthData),
                Text('\n$_activityData\n'),
                RaisedButton(child: Text("Get heart Data"), onPressed: _getHeartData),
                Text('\n$_heartData\n'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
