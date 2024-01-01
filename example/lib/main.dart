import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_health_fit/flutter_health_fit.dart';
import 'package:flutter_health_fit_example/date_picker_edittext.dart';

void main() => runApp(
      MaterialApp(
        home: MyApp(),
      ),
    );

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
  String _stepsData = "";
  List<String> _menstrualData = [];
  List<String> _bodyFatData = [];
  Iterable<String> _workoutData = [];
  bool _isAllAuth = false;
  bool _isAnyAuth = false;
  bool _isSleep = false;
  bool _isHeart = false;
  bool _isWeight = false;
  bool _isSteps = false;
  bool _isWorkouts = false;
  bool _isMenstrualData = false;
  bool _isBodyFatPercentage = false;

  TextEditingController _menstrualDaysController = TextEditingController(text: '7');
  TextEditingController _bodyFatPercentageDaysController = TextEditingController(text: '7');
  TextEditingController _workoutsDaysController = TextEditingController(text: '7');

  List<String> _workoutUpdates = [];
  StreamSubscription? _workoutsObserverSubscription;
  DateTime? _selectedStepsDate;

  Future _getAuthorized() async {
    final flutterHealthFit = FlutterHealthFit();
    final isAllAuth = await flutterHealthFit.isAuthorized();
    final isAnyAuth = await flutterHealthFit.isAnyPermissionAuthorized();
    final isSleep = await flutterHealthFit.isSleepAuthorized();
    final isHeart = await flutterHealthFit.isHeartRateAuthorized();
    final isWeight = await flutterHealthFit.isWeightAuthorized();
    final isBodyFatPercentage = await flutterHealthFit.isBodyFatPercentageAuthorized();
    final isSteps = await flutterHealthFit.isStepsAuthorized();
    final isWorkouts = await flutterHealthFit.isWorkoutsAuthorized();
    final isMenstrualData = await flutterHealthFit.isMenstrualDataAuthorized();
    setState(() {
      _isAllAuth = isAllAuth;
      _isAnyAuth = isAnyAuth;
      _isSleep = isSleep;
      _isHeart = isHeart;
      _isWeight = isWeight;
      _isSteps = isSteps;
      _isWorkouts = isWorkouts;
      _isMenstrualData = isMenstrualData;
      _isBodyFatPercentage = isBodyFatPercentage;
    });
  }

  Future _authorizeHealthOrFit() async {
    bool isAuthorized = (await FlutterHealthFit().authorize()).status == HealthFitAuthorizationStatus.authorized;
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
      _lastWeightString = "${lastWeight?.value}";
    });
  }

  Future _getActivityHealthData() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final steps =
        await FlutterHealthFit().getStepsBySegment(yesterday.millisecondsSinceEpoch, today.millisecondsSinceEpoch);
    final running = await FlutterHealthFit().getWalkingAndRunningDistance;
    final cycle =
        await FlutterHealthFit().getCyclingBySegment(yesterday.millisecondsSinceEpoch, today.millisecondsSinceEpoch);
    final flights =
        await FlutterHealthFit().getFlightsBySegment(yesterday.millisecondsSinceEpoch, today.millisecondsSinceEpoch);
    setState(() {
      _activityData = "steps: $steps\nwalking running: $running\ncycle: $cycle flights: $flights";
    });
  }

  _getHeartData() async {
    final now = DateTime.now();
    final yesterday = now.subtract(Duration(days: 100));
    final current =
        await FlutterHealthFit().getLatestHeartRate(yesterday.millisecondsSinceEpoch, now.millisecondsSinceEpoch);
    final resting = await FlutterHealthFit()
        .getAverageRestingHeartRate(yesterday.millisecondsSinceEpoch, now.millisecondsSinceEpoch);
    final walking = await FlutterHealthFit()
        .getAverageWalkingHeartRate(yesterday.millisecondsSinceEpoch, now.millisecondsSinceEpoch);
    setState(() {
      _heartData = "current: $current\nresting: $resting\nwalking: $walking";
    });
  }

  _getMenstrualData() async {
    final now = DateTime.now();
    final daysBack = now.subtract(Duration(days: int.tryParse(_menstrualDaysController.value.text) ?? 7));
    final menstrualData = await FlutterHealthFit().getMenstrualData(
      daysBack.millisecondsSinceEpoch,
      now.millisecondsSinceEpoch,
    );
    setState(() {
      if (menstrualData != null) {
        _menstrualData = menstrualData.map((element) => "${element.date} : ${element.value}").toList();
      }
    });
  }

  _getStepsData() async {
    if (_selectedStepsDate == null) {
      _showErrorBottomSheet(context, "Please select a date for steps");
      return;
    }

    final DateTime selectedDate = _selectedStepsDate!;
    final start = _getStartOfDay(selectedDate).millisecondsSinceEpoch;
    final end = _getEndOfDay(selectedDate).millisecondsSinceEpoch;
    final steps = await FlutterHealthFit().getStepsBySegment(
      start,
      end,
    );
    setState(() {
      if (steps != null) {
        _stepsData = steps.toString();
      }
    });
  }

  void _showErrorBottomSheet(BuildContext context, String errorMessage) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(20),
          height: 150, // Adjust height as needed
          color: Colors.red, // Color to indicate error (e.g., red)
          child: Center(
            child: Text(
              errorMessage,
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }

  DateTime _getStartOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime _getEndOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59);
  }

  _getBodyFatPercentage() async {
    final now = DateTime.now();
    final daysBack = now.subtract(Duration(days: int.tryParse(_bodyFatPercentageDaysController.value.text) ?? 7));
    final bodyFatData = await FlutterHealthFit().getBodyFatPercentage(
      daysBack.millisecondsSinceEpoch,
      now.millisecondsSinceEpoch,
    );
    setState(() {
      _bodyFatData = [bodyFatData?.value.toString() ?? ""];
    });
  }

  _getWorkouts() async {
    final now = DateTime.now();
    final daysBack = now.subtract(Duration(days: int.tryParse(_workoutsDaysController.value.text) ?? 7));
    final workoutsData = await FlutterHealthFit().getWorkoutsBySegment(
      daysBack.millisecondsSinceEpoch,
      now.millisecondsSinceEpoch,
    );
    setState(() {
      _workoutData = workoutsData?.map((element) => element.toString()) ?? [];
    });
  }

  void _subscribeToWorkouts() {
    setState(() {
      _workoutsObserverSubscription = FlutterHealthFit().observeWorkouts().listen(
        (event) async {
          setState(() {
            _workoutUpdates = [..._workoutUpdates, "${DateTime.now()} : $event"];
          });
        },
        onDone: () => _workoutsObserverSubscription = null,
        onError: (error, st) => print('error in workouts observer $error'),
      );
    });
  }

  void _unsubscribeFromWorkouts() {
    _workoutsObserverSubscription?.cancel();

    setState(() {
      _workoutUpdates = [];
      _workoutsObserverSubscription = null;
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
          child: Center(
            child: ListView(
              children: <Widget>[
                Text('Health/Fit Authorized: $_isAuthorized\n'),
                ElevatedButton(child: Text("Authorize Health"), onPressed: _authorizeHealthOrFit),
                Text("isAllAuth: $_isAllAuth,\n"
                    " isAnyAuth: $_isAnyAuth,\n"
                    " isSleep: $_isSleep,\n"
                    " isHeart: $_isHeart,\n"
                    " isWeight: $_isWeight,\n"
                    " isSteps: $_isSteps,\n"
                    " isWorkouts: $_isWorkouts,\n"
                    " isMenstrualData: $_isMenstrualData,\n"
                    " isBodyFatPercentage: $_isBodyFatPercentage,\n"),
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
                Divider(height: 1),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(child: Text("Get Menstrual Data For Days"), onPressed: _getMenstrualData),
                    SizedBox(
                      width: 10,
                    ),
                    Container(
                      width: 30,
                      child: TextField(
                        keyboardType: TextInputType.numberWithOptions(signed: false, decimal: false),
                        controller: _menstrualDaysController,
                      ),
                    ),
                  ],
                ),
                ListView.builder(
                  itemCount: _menstrualData.length,
                  shrinkWrap: true,
                  physics: ScrollPhysics(),
                  itemBuilder: (context, index) => Text('\n${_menstrualData[index]}\n'),
                ),
                Divider(height: 1),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(child: Text("Get Steps for date"), onPressed: _getStepsData),
                    SizedBox(
                      width: 10,
                    ),
                    DatePickerEditText(
                      onDateSelected: (selectedDate) {
                        _selectedStepsDate = selectedDate;
                      },
                    ),
                  ],
                ),
                Text('\n$_stepsData\n'),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(child: Text("Get body fat percentage for fays"), onPressed: _getBodyFatPercentage),
                    SizedBox(
                      width: 10,
                    ),
                    Container(
                      width: 30,
                      child: TextField(
                        keyboardType: TextInputType.numberWithOptions(signed: false, decimal: false),
                        controller: _bodyFatPercentageDaysController,
                      ),
                    ),
                  ],
                ),
                ListView.builder(
                  itemCount: _bodyFatData.length,
                  shrinkWrap: true,
                  physics: ScrollPhysics(),
                  itemBuilder: (context, index) => Text('\n${_bodyFatData[index]}\n'),
                ),
                Divider(height: 1),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(child: Text("Get workouts for days"), onPressed: _getWorkouts),
                    SizedBox(
                      width: 10,
                    ),
                    Container(
                      width: 30,
                      child: TextField(
                        keyboardType: TextInputType.numberWithOptions(signed: false, decimal: false),
                        controller: _workoutsDaysController,
                      ),
                    ),
                  ],
                ),
                ListView.builder(
                  itemCount: _workoutData.length,
                  shrinkWrap: true,
                  physics: ScrollPhysics(),
                  itemBuilder: (context, index) => Text('\n${_workoutData.elementAt(index)}\n'),
                ),
                if (_workoutsObserverSubscription == null)
                  ElevatedButton(child: Text("Subscribe To Workouts"), onPressed: _subscribeToWorkouts)
                else
                  ElevatedButton(child: Text("Unsubscribe From Workouts"), onPressed: _unsubscribeFromWorkouts),
                ListView.builder(
                  itemCount: _workoutUpdates.length,
                  shrinkWrap: true,
                  physics: ScrollPhysics(),
                  itemBuilder: (context, index) => Text('\n${_workoutUpdates.elementAt(index)}\n'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
