import 'package:flutter/material.dart';
import '../models/turtle_record.dart';
import '../models/turtle.dart';
import '../models/sort_option.dart';
import '../services/turtle_service.dart';
import '../services/turtle_management_service.dart';
import '../services/sort_config_service.dart';
import '../widgets/turtle_tree.dart';
import 'add_record_page.dart';
import 'turtle_management_page.dart';
import 'sort_settings_page.dart';

class TurtleGrowthHomePage extends StatefulWidget {
  const TurtleGrowthHomePage({super.key});

  @override
  State<TurtleGrowthHomePage> createState() => _TurtleGrowthHomePageState();
}

class _TurtleGrowthHomePageState extends State<TurtleGrowthHomePage> {
  List<TurtleRecord> _records = [];
  List<Turtle> _turtles = [];
  List<String> _selectedTurtleIds = [];
  SortConfig _sortConfig = SortConfig.defaultConfig;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final records = await TurtleService.getRecords();
      final turtles = await TurtleManagementService.getTurtles();
      final sortConfig = await SortConfigService.getSortConfig();
      
      setState(() {
        _records = records;
        _turtles = turtles;
        _sortConfig = sortConfig;
        // 默认选择所有乌龟
        _selectedTurtleIds = turtles.map((turtle) => turtle.id).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载数据失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showTurtleSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('选择要显示的乌龟'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 全选/全不选
                    CheckboxListTile(
                      title: const Text('全选/全不选'),
                      value: _selectedTurtleIds.length == _turtles.length,
                      onChanged: (bool? value) {
                        setDialogState(() {
                          if (value == true) {
                            _selectedTurtleIds = _turtles.map((turtle) => turtle.id).toList();
                          } else {
                            _selectedTurtleIds.clear();
                          }
                        });
                        setState(() {});
                      },
                    ),
                    const Divider(),
                    // 乌龟列表
                    ..._turtles.map((turtle) {
                      final isSelected = _selectedTurtleIds.contains(turtle.id);
                      return CheckboxListTile(
                        title: Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: turtle.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(turtle.name)),
                          ],
                        ),
                        value: isSelected,
                        onChanged: (bool? value) {
                          setDialogState(() {
                            if (value == true) {
                              _selectedTurtleIds.add(turtle.id);
                            } else {
                              _selectedTurtleIds.remove(turtle.id);
                            }
                          });
                          setState(() {});
                        },
                      );
                    }).toList(),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('完成'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(
              Icons.pets,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            if (_turtles.isEmpty)
              const Text(
                '乌龟生长记录',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              )
            else
              Expanded(
                child: GestureDetector(
                  onTap: () => _showTurtleSelectionDialog(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Expanded(
                          child: Text(
                            _selectedTurtleIds.length == _turtles.length
                                ? '显示所有乌龟 (${_turtles.length})'
                                : '已选择 ${_selectedTurtleIds.length} 只乌龟',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_drop_down,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.sort,
              color: Colors.white,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SortSettingsPage(
                    currentConfig: _sortConfig,
                    onConfigChanged: (newConfig) async {
                      await SortConfigService.saveSortConfig(newConfig);
                      setState(() {
                        _sortConfig = newConfig;
                      });
                    },
                  ),
                ),
              );
            },
            tooltip: '排序设置',
          ),
          IconButton(
            icon: const Icon(
              Icons.manage_accounts,
              color: Colors.white,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TurtleManagementPage(),
                ),
              ).then((_) => _loadData());
            },
            tooltip: '乌龟管理',
          ),
          IconButton(
            icon: const Icon(
              Icons.refresh,
              color: Colors.white,
            ),
            onPressed: _loadData,
            tooltip: '刷新',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Colors.green.shade600,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '正在加载记录...',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : TurtleTree(
              records: _records,
              turtles: _turtles,
              selectedTurtleIds: _selectedTurtleIds,
              sortConfig: _sortConfig,
              onRefresh: _loadData,
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_turtles.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('请先添加至少一只乌龟'),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddRecordPage(
                turtles: _turtles,
                onSaved: _loadData,
              ),
            ),
          );
        },
        backgroundColor: Colors.green.shade600,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
