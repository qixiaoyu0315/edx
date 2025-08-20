enum SortOption {
  recordDate('记录日期', '按记录添加的日期排序'),
  turtleBirthDate('乌龟生日', '按乌龟的出生日期排序'),
  weight('体重', '按记录的体重数据排序'),
  length('体长', '按记录的体长数据排序'),
  width('体宽', '按记录的体宽数据排序');

  const SortOption(this.displayName, this.description);

  final String displayName;
  final String description;
}

enum SortOrder {
  ascending('升序', '从小到大/从早到晚'),
  descending('降序', '从大到小/从晚到早');

  const SortOrder(this.displayName, this.description);

  final String displayName;
  final String description;
}

class SortConfig {
  final SortOption option;
  final SortOrder order;

  const SortConfig({
    required this.option,
    required this.order,
  });

  Map<String, dynamic> toJson() {
    return {
      'option': option.name,
      'order': order.name,
    };
  }

  factory SortConfig.fromJson(Map<String, dynamic> json) {
    return SortConfig(
      option: SortOption.values.firstWhere(
        (e) => e.name == json['option'],
        orElse: () => SortOption.recordDate,
      ),
      order: SortOrder.values.firstWhere(
        (e) => e.name == json['order'],
        orElse: () => SortOrder.descending,
      ),
    );
  }

  // 默认排序配置
  static const SortConfig defaultConfig = SortConfig(
    option: SortOption.recordDate,
    order: SortOrder.descending,
  );
}
