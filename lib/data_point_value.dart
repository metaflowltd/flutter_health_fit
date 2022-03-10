import 'package:flutter_health_fit/data_point_unit.dart';

class DataPointValue {
  final DateTime date;
  final double value;
  final DataPointUnit units;
  final String? sourceApp;

  DataPointValue({
    required this.value,
    required this.date,
    required this.units,
    this.sourceApp,
  });

  static DataPointValue? fromMap(Map<String, Object>? map) {
    if (map == null) {
      return null;
    }

    final dateInMillis = map["dateInMillis"] as int?;
    if (dateInMillis == null) {
      return null;
    }
    final date = DateTime.fromMillisecondsSinceEpoch(dateInMillis);
    final value = map["value"] as double?;
    final units =  DataPointUnitUtils.getUnit(fromString: map["units"] as String?);
    final sourceApp = map["sourceApp"] as String?;
    final endDateInMillis = map["endDateInMillis"] as int?;

    if (value == null || units == null) {
      return null;
    }

    return DataPointValue(value: value, date: date, units: units, sourceApp: sourceApp);
  }
}
