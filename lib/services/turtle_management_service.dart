import '../models/turtle.dart';
import 'turtle_database_helper.dart';

class TurtleManagementService {
  // 获取所有乌龟
  static Future<List<Turtle>> getTurtles() async {
    return TurtleDatabaseHelper.instance.getAllTurtles();
  }

  // 添加新乌龟
  static Future<void> addTurtle(Turtle turtle) async {
    await TurtleDatabaseHelper.instance.insertTurtle(turtle);
  }

  // 删除乌龟
  static Future<void> deleteTurtle(String id) async {
    await TurtleDatabaseHelper.instance.deleteTurtle(id);
  }

  // 更新乌龟
  static Future<void> updateTurtle(Turtle updatedTurtle) async {
    await TurtleDatabaseHelper.instance.updateTurtle(updatedTurtle);
  }

  // 根据ID获取乌龟
  static Future<Turtle?> getTurtleById(String id) async {
    return TurtleDatabaseHelper.instance.getTurtleById(id);
  }
}
