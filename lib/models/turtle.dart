import 'package:flutter/material.dart';

class Turtle {
  final String id;
  final String name;
  final String species; // 品种
  final DateTime birthDate; // 出生日期
  final Color color; // 时间轴颜色
  final String? description; // 描述
  final String? photoPath; // 照片路径

  Turtle({
    required this.id,
    required this.name,
    required this.species,
    required this.birthDate,
    required this.color,
    this.description,
    this.photoPath,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'species': species,
      'birthDate': birthDate.toIso8601String(),
      'color': color.value,
      'description': description,
      'photoPath': photoPath,
    };
  }

  factory Turtle.fromJson(Map<String, dynamic> json) {
    return Turtle(
      id: json['id'],
      name: json['name'],
      species: json['species'],
      birthDate: DateTime.parse(json['birthDate']),
      color: Color(json['color']),
      description: json['description'],
      photoPath: json['photoPath'],
    );
  }

  // SQLite mapping
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'species': species,
      'birthDate': birthDate.toIso8601String(),
      'color': color.value,
      'description': description,
      'photoPath': photoPath,
    };
  }

  factory Turtle.fromMap(Map<String, dynamic> map) {
    return Turtle(
      id: map['id'] as String,
      name: map['name'] as String,
      species: map['species'] as String,
      birthDate: DateTime.parse(map['birthDate'] as String),
      color: Color((map['color'] as num).toInt()),
      description: map['description'] as String?,
      photoPath: map['photoPath'] as String?,
    );
  }

  // 预定义的颜色选项
  static const List<Color> availableColors = [
    Colors.green,
    Colors.blue,
    Colors.orange,
    Colors.purple,
    Colors.red,
    Colors.teal,
    Colors.indigo,
    Colors.pink,
    Colors.amber,
    Colors.cyan,
    Colors.deepOrange,
    Colors.lightGreen,
    Colors.deepPurple,
    Colors.brown,
    Colors.blueGrey,
  ];

  // 获取未使用的随机颜色
  static Color getRandomUnusedColor(List<Turtle> existingTurtles) {
    final usedColors = existingTurtles.map((turtle) => turtle.color).toSet();
    final unusedColors = availableColors.where((color) => !usedColors.contains(color)).toList();
    
    if (unusedColors.isNotEmpty) {
      unusedColors.shuffle();
      return unusedColors.first;
    } else {
      // 如果所有预定义颜色都用完了，生成随机颜色
      final random = DateTime.now().millisecondsSinceEpoch;
      return Color((random & 0xFFFFFF) | 0xFF000000);
    }
  }

  // 获取年龄（天数）
  int get ageInDays {
    return DateTime.now().difference(birthDate).inDays;
  }

  // 获取年龄描述
  String get ageDescription {
    final days = ageInDays;
    if (days < 30) {
      return '$days天';
    } else if (days < 365) {
      final months = (days / 30).floor();
      return '$months个月';
    } else {
      final years = (days / 365).floor();
      final remainingMonths = ((days % 365) / 30).floor();
      if (remainingMonths > 0) {
        return '$years年$remainingMonths个月';
      } else {
        return '$years年';
      }
    }
  }
}
