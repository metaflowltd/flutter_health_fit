class HFDataPointValue {
  final DateTime date;
  final double value;
  final String? sourceApp;
  final String? units;

  HFDataPointValue({required this.date, required this.value, this.sourceApp, this.units});
}

class HFDataPointOutput {
  final List<HFDataPointValue>? values;

  HFDataPointOutput.fromMap(Map? map) : values = _valuesFromMap(map);

  static List<HFDataPointValue>? _valuesFromMap(Map? map) {
    List<HFDataPointValue>? values = [];

    map?.entries.forEach((element) {
      if (element.key is int == false) {
        return;
      }

      final elementValue = element.value;
      final dateTime = DateTime.fromMillisecondsSinceEpoch(element.key);

      if (elementValue is double) {
        final dataPointValue = HFDataPointValue(date: dateTime, value: elementValue);
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
          final dataPointValue = HFDataPointValue(
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
