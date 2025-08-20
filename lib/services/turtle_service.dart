import '../models/turtle_record.dart';
import 'turtle_database_helper.dart';

class TurtleService {
  // 获取所有记录
  static Future<List<TurtleRecord>> getRecords() async {
    return TurtleDatabaseHelper.instance.getAllRecords();
  }

  // 根据乌龟ID获取记录列表
  static Future<List<TurtleRecord>> getRecordsByTurtle(String turtleId) async {
    return TurtleDatabaseHelper.instance.getRecordsByTurtle(turtleId);
  }

  // 添加新记录
  static Future<void> addRecord(TurtleRecord record) async {
    await TurtleDatabaseHelper.instance.insertRecord(record);
  }

  // 删除记录
  static Future<void> deleteRecord(String id) async {
    await TurtleDatabaseHelper.instance.deleteRecord(id);
  }

  // 更新记录
  static Future<void> updateRecord(TurtleRecord updatedRecord) async {
    await TurtleDatabaseHelper.instance.updateRecord(updatedRecord);
  }
}
