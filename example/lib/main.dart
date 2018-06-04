import 'package:flutter/material.dart';
//import 'package:flutter/services.dart';
import 'package:flutter_health_fit/flutter_health_fit.dart';

void main() => runApp(new MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => new _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isAuthed = false;
  String _basicHealthString = "";
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
    bool authed = await FlutterHealthFit.authorize;
    setState(() {
      _isAuthed = authed;
    });
  }


  _getUserBasicHealthData() async{
    var basicHealth = await FlutterHealthFit.getBasicHealthData;
    setState(() {
       _basicHealthString = basicHealth.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      home: new Scaffold(
        appBar: new AppBar(
          title: new Text('Plugin example app'),
        ),
        body: new Center(
          child: new Column(
            children: <Widget>[
              new Text('Authed: $_isAuthed\n'),
              new RaisedButton(child: Text("Authorize Health"), onPressed: _authorizeHealthOrFit),
              new RaisedButton(child: Text("Get basic data"), onPressed: _getUserBasicHealthData),
              new Text('Basic health: $_basicHealthString\n'),

            ],
          ),
        ),
      ),
    );
  }
}
