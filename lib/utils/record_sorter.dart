import '../models/turtle_record.dart';
import '../models/turtle.dart';
import '../models/sort_option.dart';

class RecordSorter {
  static List<TurtleRecord> sortRecords(
    List<TurtleRecord> records,
    List<Turtle> turtles,
    SortConfig sortConfig,
  ) {
    final sortedRecords = List<TurtleRecord>.from(records);

    switch (sortConfig.option) {
      case SortOption.recordDate:
        sortedRecords.sort((a, b) {
          final comparison = a.date.compareTo(b.date);
          return sortConfig.order == SortOrder.ascending ? comparison : -comparison;
        });
        break;

      case SortOption.turtleBirthDate:
        sortedRecords.sort((a, b) {
          final turtleA = _getTurtleById(turtles, a.turtleId);
          final turtleB = _getTurtleById(turtles, b.turtleId);
          
          if (turtleA == null && turtleB == null) return 0;
          if (turtleA == null) return 1;
          if (turtleB == null) return -1;
          
          final comparison = turtleA.birthDate.compareTo(turtleB.birthDate);
          return sortConfig.order == SortOrder.ascending ? comparison : -comparison;
        });
        break;

      case SortOption.weight:
        sortedRecords.sort((a, b) {
          final weightA = a.weight;
          final weightB = b.weight;
          
          // 没有体重数据的记录排在最后
          if (weightA == null && weightB == null) return 0;
          if (weightA == null) return 1;
          if (weightB == null) return -1;
          
          final comparison = weightA.compareTo(weightB);
          return sortConfig.order == SortOrder.ascending ? comparison : -comparison;
        });
        break;

      case SortOption.length:
        sortedRecords.sort((a, b) {
          final lengthA = a.length;
          final lengthB = b.length;
          
          // 没有体长数据的记录排在最后
          if (lengthA == null && lengthB == null) return 0;
          if (lengthA == null) return 1;
          if (lengthB == null) return -1;
          
          final comparison = lengthA.compareTo(lengthB);
          return sortConfig.order == SortOrder.ascending ? comparison : -comparison;
        });
        break;

      case SortOption.width:
        sortedRecords.sort((a, b) {
          final widthA = a.width;
          final widthB = b.width;
          
          // 没有体宽数据的记录排在最后
          if (widthA == null && widthB == null) return 0;
          if (widthA == null) return 1;
          if (widthB == null) return -1;
          
          final comparison = widthA.compareTo(widthB);
          return sortConfig.order == SortOrder.ascending ? comparison : -comparison;
        });
        break;
    }

    return sortedRecords;
  }

  static Turtle? _getTurtleById(List<Turtle> turtles, String turtleId) {
    try {
      return turtles.firstWhere((turtle) => turtle.id == turtleId);
    } catch (e) {
      return null;
    }
  }

  // 获取排序维度的显示值
  static String getSortValueDisplay(
    TurtleRecord record,
    Turtle? turtle,
    SortOption sortOption,
  ) {
    switch (sortOption) {
      case SortOption.recordDate:
        return '${record.date.month}/${record.date.day}';
      
      case SortOption.turtleBirthDate:
        if (turtle == null) return '未知';
        return '${turtle.birthDate.month}/${turtle.birthDate.day}';
      
      case SortOption.weight:
        return record.weight != null ? '${record.weight}g' : '未记录';
      
      case SortOption.length:
        return record.length != null ? '${record.length}cm' : '未记录';
      
      case SortOption.width:
        return record.width != null ? '${record.width}cm' : '未记录';
    }
  }
}
