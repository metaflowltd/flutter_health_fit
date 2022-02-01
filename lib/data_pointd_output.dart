class HealthFitDataPointValue {
  final DateTime date;
  final double value;
  final String? sourceApp;
  final String? units;

  HealthFitDataPointValue({required this.date, required this.value, this.sourceApp, this.units});
}

class HFDataPointOutput {
  final List<HealthFitDataPointValue>? values;

  HFDataPointOutput.fromMap(Map? map) : values = _valuesFromMap(map);

  static List<HealthFitDataPointValue>? _valuesFromMap(Map? map) {
    List<HealthFitDataPointValue>? values = [];

    map?.entries.forEach((element) {
      if (element.key is int == false) {
        return;
      }

      final elementValue = element.value;
      final dateTime = DateTime.fromMillisecondsSinceEpoch(element.key);

      if (elementValue is double) {
        final dataPointValue = HealthFitDataPointValue(date: dateTime, value: elementValue);
        values.add(dataPointValue);
        return;
      }

      if (elementValue is Map) {
        final value = elementValue["value"];
        final sourceApp = elementValue["sourceApp"];
        final sourceAppToUse = (sourceApp is String) ? sourceApp : null;
        final units = elementValue["units"];
        final unitsAppToUse = (units is String) ? units : null;

        if (value is double) {
          final dataPointValue = HealthFitDataPointValue(
            date: dateTime,
            value: value,
            sourceApp: sourceAppToUse,
            units: unitsAppToUse,
          );
          values.add(dataPointValue);
          return;
        }
      }
    });

    if (values.isEmpty) return  null;
    return values;
  }
}
