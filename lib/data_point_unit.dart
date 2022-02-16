import 'package:collection/collection.dart';

enum DataPointUnit {
  count,
  kg,
  percent,
  cm,
}

extension DataPointUnitExtension on DataPointUnit {
  String get stringValue {
    switch (this) {
      case DataPointUnit.count:
        return "count";
      case DataPointUnit.kg:
        return "kg";
      case DataPointUnit.percent:
        return "percent";
      case DataPointUnit.cm:
        return "cm";
    }
  }
}

class DataPointUnitUtils {
  static DataPointUnit? getUnit({required String? fromString}) {
    return DataPointUnit.values.firstWhereOrNull((element) => element.stringValue == fromString);
  }
}