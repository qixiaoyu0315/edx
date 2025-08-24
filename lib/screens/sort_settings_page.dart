import 'package:flutter/material.dart';
import '../models/sort_option.dart';

class SortSettingsPage extends StatefulWidget {
  final SortConfig currentConfig;
  final Function(SortConfig) onConfigChanged;

  const SortSettingsPage({
    super.key,
    required this.currentConfig,
    required this.onConfigChanged,
  });

  @override
  State<SortSettingsPage> createState() => _SortSettingsPageState();
}

class _SortSettingsPageState extends State<SortSettingsPage> {
  late SortOption _selectedOption;
  late SortOrder _selectedOrder;

  @override
  void initState() {
    super.initState();
    _selectedOption = widget.currentConfig.option;
    _selectedOrder = widget.currentConfig.order;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade50,
      appBar: AppBar(
        title: const Text(
          '时间线排序设置',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () {
              final newConfig = SortConfig(
                option: _selectedOption,
                order: _selectedOrder,
              );
              widget.onConfigChanged(newConfig);
              Navigator.pop(context);
            },
            child: const Text(
              '保存',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 排序维度选择
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
                          Icons.sort,
                          color: Colors.blue.shade600,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '排序维度',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...SortOption.values.map((option) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: RadioListTile<SortOption>(
                          title: Text(
                            option.displayName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            option.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          value: option,
                          groupValue: _selectedOption,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedOption = value;
                              });
                            }
                          },
                          activeColor: Colors.green.shade600,
                          contentPadding: EdgeInsets.zero,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 排序顺序选择
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
                          Icons.swap_vert,
                          color: Colors.orange.shade600,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '排序顺序',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...SortOrder.values.map((order) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: RadioListTile<SortOrder>(
                          title: Text(
                            order.displayName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            order.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          value: order,
                          groupValue: _selectedOrder,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedOrder = value;
                              });
                            }
                          },
                          activeColor: Colors.orange.shade600,
                          contentPadding: EdgeInsets.zero,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 预览说明
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
                          Icons.info_outline,
                          color: Colors.purple.shade600,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '当前设置预览',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.purple.shade200,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '排序方式：${_selectedOption.displayName}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.purple.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '排序顺序：${_selectedOrder.displayName}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.purple.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _getPreviewDescription(),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.purple.shade600,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPreviewDescription() {
    final optionDesc = _selectedOption.description;
    final orderDesc = _selectedOrder.description;
    
    return '时间线将会$optionDesc，显示顺序为$orderDesc。\n\n'
        '注意：如果选择体重、体长或体宽排序，没有相应数据的记录将显示在最后。';
  }
}
