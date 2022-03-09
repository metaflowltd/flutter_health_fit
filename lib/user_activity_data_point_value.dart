import 'data_point_value.dart';

class UserActivityDataPointValue extends DataPointValue {
  final DateTime endDate;

  UserActivityDataPointValue({
    required value,
    required date,
    required this.endDate,
    required units,
    sourceApp,
  }) : super(value: value, date: date, units: units, sourceApp: sourceApp);

  static UserActivityDataPointValue? fromMap(Map<String, Object>? map) {
    if (map == null) {
      return null;
    }

    final endDateInMillis = map["endDateInMillis"] as int?;
    if (endDateInMillis == null) {
      return null;
    }

    final dataPointValue = DataPointValue.fromMap(map);
    if (dataPointValue == null) {
      return null;
    }

    final endDate = DateTime.fromMillisecondsSinceEpoch(endDateInMillis);

    return UserActivityDataPointValue(value: dataPointValue.value,
      date: dataPointValue.date,
      units: dataPointValue.units,
      sourceApp: dataPointValue.sourceApp,
      endDate: endDate,);
  }
}
