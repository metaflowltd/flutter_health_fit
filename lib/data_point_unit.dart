import 'package:collection/collection.dart';

enum DataPointUnit {
  count,
  kg,
  g,
  kCal,
  percent,
  cm,
  l,
  km,
}

extension DataPointUnitExtension on DataPointUnit {
  String get stringValue {
    switch (this) {
      case DataPointUnit.count:
        return "count";
      case DataPointUnit.kg:
        return "kg";
      case DataPointUnit.g:
        return "g";
      case DataPointUnit.kCal:
        return "kCal";
      case DataPointUnit.percent:
        return "percent";
      case DataPointUnit.cm:
        return "cm";
      case DataPointUnit.l:
        return "l";
      case DataPointUnit.km:
        return "km";
    }
  }
}

class DataPointUnitUtils {
  static DataPointUnit? getUnit({required String? fromString}) {
    return DataPointUnit.values.firstWhereOrNull((element) => element.stringValue == fromString);
  }
}
