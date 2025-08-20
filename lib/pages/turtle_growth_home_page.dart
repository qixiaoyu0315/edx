import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
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
    setState(() => _isLoading = true);
    try {
      final records = await TurtleService.getRecords();
      final turtles = await TurtleManagementService.getTurtles();
      final sortConfig = await SortConfigService.getSortConfig();
      if (mounted) {
        setState(() {
          _records = records;
          _turtles = turtles;
          _sortConfig = sortConfig;
          _selectedTurtleIds = turtles.map((turtle) => turtle.id).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ShadToaster.of(context).show(
          ShadToast(
            description: Text('加载数据失败: $e'),
          ),
        );
      }
    }
  }

  void _showTurtleSelectionDialog() {
    showShadDialog(
      context: context,
      builder: (context) {
        final selectedTurtles = Set<String>.from(_selectedTurtleIds);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return ShadDialog(
              title: const Text('选择乌龟'),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _turtles.map((turtle) {
                  return ShadCheckbox(
                    value: selectedTurtles.contains(turtle.id),
                    onChanged: (value) {
                      setDialogState(() {
                        if (value == true) {
                          selectedTurtles.add(turtle.id);
                        } else {
                          selectedTurtles.remove(turtle.id);
                        }
                      });
                    },
                    label: Text(turtle.name),
                  );
                }).toList(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                ShadCheckbox(
                  value: selectedTurtles.length == _turtles.length,
                  onChanged: (value) {
                    setDialogState(() {
                      if (value == true) {
                        selectedTurtles.addAll(_turtles.map((turtle) => turtle.id));
                      } else {
                        selectedTurtles.clear();
                      }
                    });
                  },
                  label: const Text('全选'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedTurtleIds = selectedTurtles.toList();
                    });
                    Navigator.of(context).pop();
                    _loadData();
                  },
                  child: const Text('确定'),
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
    final theme = ShadTheme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(theme),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TurtleTree(
                      records: _records,
                      turtles: _turtles,
                      selectedTurtleIds: _selectedTurtleIds,
                      sortConfig: _sortConfig,
                      onRefresh: _loadData,
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_turtles.isEmpty) {
            ShadToaster.of(context).show(
              ShadToast(
                description: const Text('请先添加至少一只乌龟'),
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
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildHeader(ShadThemeData theme) {
    final selectedTurtleNames = _selectedTurtleIds
        .map((id) {
          try {
            return _turtles.firstWhere((t) => t.id == id).name;
          } catch (e) {
            return id;
          }
        })
        .join(", ");
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.pets, size: 24, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: _turtles.isEmpty
                ? Text('乌龟生长记录', style: theme.textTheme.h4)
                : ShadButton(
                    onPressed: _showTurtleSelectionDialog,
                    child: Text('乌龟: $selectedTurtleNames'),
                  ),
          ),
          const SizedBox(width: 12),
          ShadButton.ghost(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SortSettingsPage(
                    currentConfig: _sortConfig,
                    onConfigChanged: (newConfig) async {
                      await SortConfigService.saveSortConfig(newConfig);
                      setState(() => _sortConfig = newConfig);
                    },
                  ),
                ),
              );
            },
            child: const Icon(Icons.sort),
          ),
          ShadButton.ghost(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TurtleManagementPage(),
                ),
              ).then((_) => _loadData());
            },
            child: const Icon(Icons.manage_accounts),
          ),
          ShadButton.ghost(
            onPressed: _loadData,
            child: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}
