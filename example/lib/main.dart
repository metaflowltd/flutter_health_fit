import 'package:flutter/material.dart';
import 'package:flutter_health_fit/flutter_health_fit.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isAuthorized = false;
  bool _isBodyAuthorized = false;
  String _basicHealthString = "";
  String _lastWeightString = "";
  String _activityData = "";
  String _heartData = "";
  String _cycleData = "";
  bool _isAllAuth = false;
  bool _isAnyAuth = false;
  bool _isSleep = false;
  bool _isHeart = false;
  bool _isWeight = false;
  bool _isSteps = false;
  bool _isCycle = false;

  Future _getAuthorized() async {
    final flutterHealthFit = FlutterHealthFit();
    final isAllAuth = await flutterHealthFit.isAuthorized();
    final isAnyAuth = await flutterHealthFit.isAnyPermissionAuthorized();
    final isSleep = await flutterHealthFit.isSleepAuthorized();
    final isHeart = await flutterHealthFit.isHeartRateAuthorized();
    final isWeight = await flutterHealthFit.isWeightAuthorized();
    final isSteps = await flutterHealthFit.isStepsAuthorized();
    final isCycle = await flutterHealthFit.isMensturalCycleAuthorized();
    setState(() {
      _isAllAuth = isAllAuth;
      _isAnyAuth = isAnyAuth;
      _isSleep = isSleep;
      _isHeart = isHeart;
      _isWeight = isWeight;
      _isSteps = isSteps;
      _isCycle = isCycle;
    });
  }

  Future _authorizeHealthOrFit() async {
    bool isAuthorized = await FlutterHealthFit().authorize(true);
    setState(() {
      _isAuthorized = isAuthorized;
    });
  }

  Future _authorizeBodySensors() async {
    bool isAuthorized = await FlutterHealthFit().authorizeBodySensors();
    setState(() {
      _isBodyAuthorized = isAuthorized;
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

  void _getCycleData() async {
    final current = await FlutterHealthFit().getLatestMenstrualCycle();
    setState(() {
      _cycleData = current.toString();
    });
  }

  @override
  void initState() {
    super.initState();
    _getAuthorized();
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
          child: SingleChildScrollView(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  Text('Health/Fit Authorized: $_isAuthorized\n'),
                  ElevatedButton(child: Text("Authorize Health"), onPressed: _authorizeHealthOrFit),
                  Text(
                      "isAllAuth: $_isAllAuth, isAnyAuth: $_isAnyAuth, isSleep: $_isSleep, isHeart: $_isHeart, isWeight: $_isWeight, isSteps: $_isSteps, isCycle: $_isCycle"),
                  Text('Body sensors Authorized: $_isBodyAuthorized\n'),
                  ElevatedButton(child: Text("Authorize Body Sensors (Google)"), onPressed: _authorizeBodySensors),
                  ElevatedButton(child: Text("Get basic data"), onPressed: _getUserBasicHealthData),
                  Text('Basic health: $_basicHealthString\n'),
                  ElevatedButton(child: Text("Get Last 3 Days Weight"), onPressed: _getLast3DaysWeight),
                  Text('last weight: $_lastWeightString\n'),
                  ElevatedButton(child: Text("Get Activity Data"), onPressed: _getActivityHealthData),
                  Text('\n$_activityData\n'),
                  ElevatedButton(child: Text("Get heart Data"), onPressed: _getHeartData),
                  Text('\n$_heartData\n'),
                  ElevatedButton(child: Text("Get Cycle"), onPressed: _getCycleData),
                  Text('\n$_cycleData\n'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
