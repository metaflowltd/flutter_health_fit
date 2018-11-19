import 'package:flutter/material.dart';
//import 'package:flutter/services.dart';
import 'package:flutter_health_fit/flutter_health_fit.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  bool _isAuthorized = false;
  String _basicHealthString = "";
  String _activityData;

  @override
  initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  initPlatformState() async {
//    String platformVersion;
//    // Platform messages may fail, so we use a try/catch PlatformException.
//    try {
//      platformVersion = await FlutterHealthFit.platformVersion;
//    } on PlatformException {
//      platformVersion = 'Failed to get platform version.';
//    }
//
//    // If the widget was removed from the tree while the asynchronous platform
//    // message was in flight, we want to discard the reply rather than calling
//    // setState to update our non-existent appearance.
//    if (!mounted) return;
  }

  _authorizeHealthOrFit() async {
    bool isAuthorized = await FlutterHealthFit.authorize;
    setState(() {
      _isAuthorized = isAuthorized;
    });
  }

  _getUserBasicHealthData() async{
    var basicHealth = await FlutterHealthFit.getBasicHealthData;
    setState(() {
      _basicHealthString = basicHealth.toString();
    });
  }

  _getActivityHealthData() async {
    var steps = await FlutterHealthFit.getSteps;
    var running = await FlutterHealthFit.getWalkingAndRunningDistance;
    var cycle = await FlutterHealthFit.geCyclingDistance;
    var climbed = await FlutterHealthFit.getClimbed;
    setState(() {
      _activityData = "steps: $steps\nwalking running: $running\ncycle: $cycle climbed: $climbed";
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
              Text('Authorized Map: $_isAuthorizedMap\n'),
              RaisedButton(child: Text("Authorize Health"), onPressed: (){_authorizeHealthOrFit();
              }),
              RaisedButton(child: Text("Get basic data"), onPressed: _getUserBasicHealthData),
              Text('Basic health: $_basicHealthString\n'),
              RaisedButton(child: Text("Get Activity Data"), onPressed: _getActivityHealthData),
              Text('\n$_activityData\n'),
            ],
          ),
        ),
      ),
    );
  }
}
