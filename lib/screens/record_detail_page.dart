import 'package:flutter/material.dart';
import '../models/turtle_record.dart';
import '../services/turtle_service.dart';
import '../services/turtle_management_service.dart';
import 'add_record_page.dart';

class RecordDetailPage extends StatelessWidget {
  final TurtleRecord record;
  final VoidCallback onRefresh;

  const RecordDetailPage({
    Key? key,
    required this.record,
    required this.onRefresh,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade50,
      appBar: AppBar(
        title: Text(record.title),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final turtles = await TurtleManagementService.getTurtles();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddRecordPage(
                    recordToEdit: record,
                    turtles: turtles,
                    onSaved: () {
                      onRefresh();
                      Navigator.pop(context);
                    },
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _showDeleteDialog(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 日期卡片
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [Colors.green.shade400, Colors.green.shade600],
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: Colors.white,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${record.date.year}年${record.date.month}月${record.date.day}日',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 描述卡片
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.description,
                          color: Colors.green.shade600,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '记录描述',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      record.description,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 测量数据卡片
            if (record.weight != null || record.length != null || record.width != null)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.straighten,
                            color: Colors.blue.shade600,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '测量数据',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (record.weight != null)
                        _buildMeasurementRow(
                          Icons.monitor_weight,
                          '体重',
                          '${record.weight} 克',
                          Colors.orange,
                        ),
                      if (record.length != null)
                        _buildMeasurementRow(
                          Icons.straighten,
                          '体长',
                          '${record.length} 厘米',
                          Colors.blue,
                        ),
                      if (record.width != null)
                        _buildMeasurementRow(
                          Icons.width_full,
                          '体宽',
                          '${record.width} 厘米',
                          Colors.purple,
                        ),
                    ],
                  ),
                ),
              ),

            // 备注卡片
            if (record.notes != null && record.notes!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.note,
                            color: Colors.amber.shade600,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '备注',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        record.notes!,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMeasurementRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('删除记录'),
          content: const Text('确定要删除这条记录吗？删除后无法恢复。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                await TurtleService.deleteRecord(record.id);
                onRefresh();
                Navigator.pop(context); // 关闭对话框
                Navigator.pop(context); // 返回主页面
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
  }
}
