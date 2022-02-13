

import 'package:flutter_health_fit/data_point_unit.dart';

class BodyCompositionData {
  final DateTime date;
  final double value;
  final DataPointUnit units;
  final String? sourceApp;

  BodyCompositionData({
    required this.value,
    required this.date,
    required this.units,
    this.sourceApp,
  });

  static BodyCompositionData? fromMap(Map<String, Object>? map) {
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

    if (date == null || value == null || units == null) {
      return null;
    }

    return BodyCompositionData(
        value: value, date: date, units: units, sourceApp: sourceApp);
  }
}
