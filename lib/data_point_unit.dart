import 'package:collection/collection.dart';

enum DataPointUnit {
  count,
  kg,
}

extension DataPointUnitExtension on DataPointUnit {
  String get stringValue {
    switch (this) {
      case DataPointUnit.count:
        return "count";
      case DataPointUnit.kg:
        return "kg";
    }
  }
}

class DataPointUnitUtils {
  static DataPointUnit? getUnit({required String? fromString}) {
    return DataPointUnit.values.firstWhereOrNull((element) => element.stringValue == fromString);
  }
}