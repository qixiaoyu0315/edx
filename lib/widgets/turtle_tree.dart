import 'package:flutter/material.dart';
import 'dart:io';
import '../models/turtle_record.dart';
import '../models/turtle.dart';
import '../models/sort_option.dart';
import '../utils/record_sorter.dart';
import '../screens/record_detail_page.dart';

class TurtleTree extends StatelessWidget {
  final List<TurtleRecord> records;
  final List<Turtle> turtles;
  final List<String> selectedTurtleIds; // 选中显示的乌龟ID列表
  final SortConfig sortConfig; // 排序配置
  final VoidCallback onRefresh;

  const TurtleTree({
    super.key,
    required this.records,
    required this.turtles,
    required this.selectedTurtleIds,
    required this.sortConfig,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    // 过滤出选中乌龟的记录
    final filteredRecords = records
        .where((record) => selectedTurtleIds.contains(record.turtleId))
        .toList();
    
    // 应用自定义排序
    final sortedRecords = RecordSorter.sortRecords(
      filteredRecords,
      turtles,
      sortConfig,
    );

    if (sortedRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pets,
              size: 80,
              color: Colors.green.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              selectedTurtleIds.isEmpty 
                  ? '请选择要显示的乌龟'
                  : '选中的乌龟还没有记录\n点击右下角按钮添加第一条记录',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).colorScheme.secondary,
            Theme.of(context).colorScheme.onPrimary,
          ],
        ),
      ),
      child: CustomScrollView(
        reverse: true, // 从底部开始显示
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final record = sortedRecords[index];
                  final turtle = _getTurtleById(record.turtleId);
                  final isLast = index == sortedRecords.length - 1;
                  
                  return _buildTreeNode(context, record, turtle, index, isLast);
                },
                childCount: sortedRecords.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Turtle? _getTurtleById(String turtleId) {
    try {
      return turtles.firstWhere((turtle) => turtle.id == turtleId);
    } catch (e) {
      return null;
    }
  }

  Widget _buildTreeNode(BuildContext context, TurtleRecord record, Turtle? turtle, int index, bool isLast) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 左侧时间线
          SizedBox(
            width: 60,
            child: Column(
              children: [
                if (!isLast) ...[
                  Container(
                    width: 3,
                    height: 20,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          (turtle?.color ?? Colors.brown).withOpacity(0.6),
                          turtle?.color ?? Colors.brown,
                        ],
                      ),
                    ),
                  ),
                ],
                // 节点圆圈
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        (turtle?.color ?? Colors.green).withOpacity(0.7),
                        turtle?.color ?? Colors.green,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (turtle?.color ?? Colors.green).withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.pets,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
                // 树枝延伸
                Expanded(
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          turtle?.color ?? Colors.brown,
                          (turtle?.color ?? Colors.brown).withOpacity(0.6),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // 右侧内容卡片
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RecordDetailPage(
                        record: record,
                        onRefresh: onRefresh,
                      ),
                    ),
                  );
                },
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.onPrimary,
                          Theme.of(context).colorScheme.onPrimary.withOpacity(0.5),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    record.title,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  if (turtle != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      turtle.name,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: turtle.color,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${record.date.month}/${record.date.day}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                if (sortConfig.option != SortOption.recordDate) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    RecordSorter.getSortValueDisplay(
                                      record,
                                      turtle,
                                      sortConfig.option,
                                    ),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.blue.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // 照片展示（如有）
                        if (record.photoPath != null && record.photoPath!.isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(record.photoPath!),
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Text(
                          record.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (record.weight != null || record.length != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (record.weight != null) ...[
                                Icon(
                                  Icons.monitor_weight,
                                  size: 16,
                                  color: Colors.green.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${record.weight}g',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              if (record.length != null) ...[
                                Icon(
                                  Icons.straighten,
                                  size: 16,
                                  color: Colors.blue.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${record.length}cm',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
