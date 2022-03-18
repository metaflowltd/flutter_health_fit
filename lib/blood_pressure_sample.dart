class BloodPressureSample {
  final DateTime dateTime;
  final double systolic;
  final double diastolic;
  final String sourceApp;

  BloodPressureSample({
    required this.dateTime,
    required this.systolic,
    required this.diastolic,
    required this.sourceApp,
  });

  @override
  String toString() =>
      "$runtimeType(dateTime: $dateTime, systolic: $systolic, diastolic: $diastolic, sourceApp: $sourceApp)";

  BloodPressureSample.fromMap(Map<String, dynamic> map)
      : dateTime = DateTime.fromMillisecondsSinceEpoch(map["dateTime"]),
        systolic = map["systolic"] as double,
        diastolic = map["diastolic"] as double,
        sourceApp = map["sourceApp"];
}
