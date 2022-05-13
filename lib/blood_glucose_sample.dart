class BloodGlucoseSample {
  final DateTime dateTime;
  final double value;
  final BloodGlucoseReadingType readingType;
  final String sourceApp;

  BloodGlucoseSample({
    required this.dateTime,
    required this.value,
    required this.readingType,
    required this.sourceApp,
  });

  @override
  String toString() =>
      "$runtimeType(dateTime: $dateTime, value: $value, readingType: $readingType, sourceApp: $sourceApp)";

  BloodGlucoseSample.fromMap(Map<String, dynamic> map)
      : dateTime = DateTime.fromMillisecondsSinceEpoch(map["dateTime"]),
        value = map["value"] as double,
        readingType = bloodGlucoseFromName(map["readingType"] as String),
        sourceApp = map["sourceApp"];
}

enum BloodGlucoseReadingType { GENERAL, FASTING, AFTER_MEAL, BEFORE_MEAL }

BloodGlucoseReadingType bloodGlucoseFromName(String name) =>
    BloodGlucoseReadingType.values.firstWhere((element) => element.name == name);
