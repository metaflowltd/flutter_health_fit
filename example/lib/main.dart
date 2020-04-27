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
  String _activityData;

  Future _authorizeHealthOrFit() async {
    bool isAuthorized = await FlutterHealthFit().authorize();
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
    final last3Days = DateTime.now().add(Duration(days: -4)).millisecondsSinceEpoch;
    var lastWeight = await FlutterHealthFit().getWeight(last3Days, now);
    setState(() {
      _lastWeightString = lastWeight.toString();
    });
  }

  Future _getActivityHealthData() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    var steps = await FlutterHealthFit()
        .getStepsBySegment(yesterday.millisecondsSinceEpoch, today.millisecondsSinceEpoch, 1, TimeUnit.days);
    var running = await FlutterHealthFit().getWalkingAndRunningDistance;
    var cycle = await FlutterHealthFit()
        .getCyclingBySegment(yesterday.millisecondsSinceEpoch, today.millisecondsSinceEpoch, 1, TimeUnit.days);
    var flights = await FlutterHealthFit()
        .getFlightsBySegment(yesterday.millisecondsSinceEpoch, today.millisecondsSinceEpoch, 1, TimeUnit.days);
    setState(() {
      _activityData = "steps: $steps\nwalking running: $running\ncycle: $cycle flights: $flights";
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('Plugin example app'),
        ),
        body: Center(
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
            ],
          ),
        ),
      ),
    );
  }
}
