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
  bool _showFilterBar = false; // 是否展开内联筛选栏
  bool _showSortBar = false; // 是否展开内联排序栏

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
          // Preserve current selection; default to all on first load.
          final availableIds = turtles.map((t) => t.id).toSet();
          if (_selectedTurtleIds.isEmpty) {
            _selectedTurtleIds = availableIds.toList();
          } else {
            _selectedTurtleIds = _selectedTurtleIds
                .where((id) => availableIds.contains(id))
                .toList();
            if (_selectedTurtleIds.isEmpty) {
              _selectedTurtleIds = availableIds.toList();
            }
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ShadToaster.of(
          context,
        ).show(ShadToast(
          backgroundColor: Theme.of(context).colorScheme.onPrimary,
          alignment: Alignment.topCenter,
          description: Text('加载数据失败: $e'),
        ));
      }
    }
  }

  Widget _buildInlineFilterBar() {
    final allSelected = _selectedTurtleIds.length == _turtles.length && _turtles.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: allSelected,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedTurtleIds = _turtles.map((t) => t.id).toList();
                    } else {
                      _selectedTurtleIds.clear();
                    }
                  });
                },
              ),
              const Text('全选'),
              const Spacer(),
              ShadButton.ghost(
                onPressed: () => setState(() => _showFilterBar = false),
                child: const Icon(Icons.keyboard_arrow_up),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _turtles.map((turtle) {
              final selected = _selectedTurtleIds.contains(turtle.id);
              return FilterChip(
                selected: selected,
                label: Text(turtle.name),
                avatar: CircleAvatar(
                  backgroundColor: turtle.color,
                  child: const Icon(Icons.pets, size: 12, color: Colors.white),
                ),
                onSelected: (value) {
                  setState(() {
                    if (value) {
                      _selectedTurtleIds.add(turtle.id);
                    } else {
                      _selectedTurtleIds.remove(turtle.id);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // 内联排序栏（用于时间线排序）
  Widget _buildInlineSortBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 排序字段
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: SortOption.values.map((opt) {
              final selected = _sortConfig.option == opt;
              return ChoiceChip(
                label: Text(opt.displayName), // 去除解释性文字，仅显示名称
                selected: selected,
                onSelected: (v) async {
                  if (!selected) {
                    final newConfig = SortConfig(option: opt, order: _sortConfig.order);
                    await SortConfigService.saveSortConfig(newConfig);
                    setState(() => _sortConfig = newConfig);
                  }
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          // 升降序
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: Text(SortOrder.ascending.displayName),
                selected: _sortConfig.order == SortOrder.ascending,
                onSelected: (v) async {
                  if (_sortConfig.order != SortOrder.ascending) {
                    final newConfig = SortConfig(option: _sortConfig.option, order: SortOrder.ascending);
                    await SortConfigService.saveSortConfig(newConfig);
                    setState(() => _sortConfig = newConfig);
                  }
                },
              ),
              ChoiceChip(
                label: Text(SortOrder.descending.displayName),
                selected: _sortConfig.order == SortOrder.descending,
                onSelected: (v) async {
                  if (_sortConfig.order != SortOrder.descending) {
                    final newConfig = SortConfig(option: _sortConfig.option, order: SortOrder.descending);
                    await SortConfigService.saveSortConfig(newConfig);
                    setState(() => _sortConfig = newConfig);
                  }
                },
              ),
              const Spacer(),
              ShadButton.ghost(
                onPressed: () => setState(() => _showSortBar = false),
                child: const Icon(Icons.keyboard_arrow_up),
              ),
            ],
          ),
        ],
      ),
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
            if (_showFilterBar) _buildInlineFilterBar(),
            if (_showSortBar) _buildInlineSortBar(),
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
            ShadToaster.of(
              context,
            ).show(ShadToast(
              backgroundColor: Theme.of(context).colorScheme.onPrimary,
              alignment: Alignment.topCenter,
              description: const Text('请先添加至少一只乌龟'),
            ));
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  AddRecordPage(turtles: _turtles, onSaved: _loadData),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildHeader(ShadThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _turtles.isEmpty
                ? Text('乌龟生长记录', style: theme.textTheme.h4)
                : ShadButton(
                    onPressed: () => setState(() => _showFilterBar = !_showFilterBar),
                    child: const Text('选择乌龟'),
                  ),
          ),
          const SizedBox(width: 12),
          ShadButton.ghost(
            onPressed: () => setState(() => _showSortBar = !_showSortBar),
            child: const Icon(Icons.sort, size: 25),
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
            child: const Icon(Icons.manage_accounts, size: 25),
          ),
          ShadButton.ghost(
            onPressed: _loadData,
            child: const Icon(Icons.refresh, size: 25),
          ),
        ],
      ),
    );
  }
}
