import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/turtle.dart';
import '../models/turtle_record.dart';
import '../services/turtle_service.dart';

class TurtleGrowthChartPage extends StatefulWidget {
  final Turtle turtle;

  const TurtleGrowthChartPage({
    Key? key,
    required this.turtle,
  }) : super(key: key);

  @override
  State<TurtleGrowthChartPage> createState() => _TurtleGrowthChartPageState();
}

class _TurtleGrowthChartPageState extends State<TurtleGrowthChartPage> {
  List<TurtleRecord> _records = [];
  bool _isLoading = true;
  String _selectedMetric = 'weight'; // weight, length, width
  bool _showDataPoints = true;
  bool _showTrendLine = true;
  int _timeRange = 365; // 显示天数范围

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final allRecords = await TurtleService.getRecords();
      final turtleRecords = allRecords
          .where((record) => record.turtleId == widget.turtle.id)
          .where((record) => _hasMetricData(record))
          .toList();

      // 按时间排序
      turtleRecords.sort((a, b) => a.date.compareTo(b.date));

      setState(() {
        _records = turtleRecords;
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

  bool _hasMetricData(TurtleRecord record) {
    switch (_selectedMetric) {
      case 'weight':
        return record.weight != null;
      case 'length':
        return record.length != null;
      case 'width':
        return record.width != null;
      default:
        return false;
    }
  }

  double _getMetricValue(TurtleRecord record) {
    switch (_selectedMetric) {
      case 'weight':
        return record.weight ?? 0;
      case 'length':
        return record.length ?? 0;
      case 'width':
        return record.width ?? 0;
      default:
        return 0;
    }
  }

  String _getMetricUnit() {
    switch (_selectedMetric) {
      case 'weight':
        return '克';
      case 'length':
        return '厘米';
      case 'width':
        return '厘米';
      default:
        return '';
    }
  }

  String _getMetricLabel() {
    switch (_selectedMetric) {
      case 'weight':
        return '体重';
      case 'length':
        return '体长';
      case 'width':
        return '体宽';
      default:
        return '';
    }
  }

  List<FlSpot> _getChartData() {
    if (_records.isEmpty) return [];

    final now = DateTime.now();
    final cutoffDate = now.subtract(Duration(days: _timeRange));
    
    final filteredRecords = _records
        .where((record) => record.date.isAfter(cutoffDate))
        .toList();

    if (filteredRecords.isEmpty) return [];

    final firstDate = filteredRecords.first.date;
    
    return filteredRecords.map((record) {
      final daysSinceFirst = record.date.difference(firstDate).inDays.toDouble();
      final value = _getMetricValue(record);
      return FlSpot(daysSinceFirst, value);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade50,
      appBar: AppBar(
        title: Text(
          '${widget.turtle.name} - 成长图表',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: widget.turtle.color,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsDialog,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: widget.turtle.color,
                  ),
                  const SizedBox(height: 16),
                  const Text('正在加载数据...'),
                ],
              ),
            )
          : _records.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.show_chart,
                        size: 80,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '暂无${_getMetricLabel()}数据\n请先添加包含${_getMetricLabel()}信息的记录',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 指标选择卡片
                      _buildMetricSelector(),
                      const SizedBox(height: 16),
                      
                      // 图表卡片
                      _buildChartCard(),
                      const SizedBox(height: 16),
                      
                      // 统计信息卡片
                      _buildStatsCard(),
                      const SizedBox(height: 16),
                      
                      // 数据列表
                      _buildDataList(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildMetricSelector() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '选择指标',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricChip('weight', '体重', Icons.monitor_weight),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricChip('length', '体长', Icons.straighten),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricChip('width', '体宽', Icons.width_normal),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricChip(String metric, String label, IconData icon) {
    final isSelected = _selectedMetric == metric;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMetric = metric;
        });
        _loadRecords();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? widget.turtle.color.withOpacity(0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? widget.turtle.color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? widget.turtle.color : Colors.grey.shade600,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? widget.turtle.color : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard() {
    final chartData = _getChartData();
    
    if (chartData.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          height: 300,
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              '暂无${_getMetricLabel()}数据',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_getMetricLabel()}变化趋势',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    horizontalInterval: _getHorizontalInterval(),
                    verticalInterval: _getVerticalInterval(chartData),
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey.shade300,
                        strokeWidth: 1,
                      );
                    },
                    getDrawingVerticalLine: (value) {
                      return FlLine(
                        color: Colors.grey.shade300,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: _getVerticalInterval(chartData),
                        getTitlesWidget: (value, meta) {
                          if (_records.isEmpty) return const Text('');
                          final firstDate = _records.first.date;
                          final targetDate = firstDate.add(Duration(days: value.toInt()));
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(
                              '${targetDate.month}/${targetDate.day}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: _getHorizontalInterval(),
                        reservedSize: 42,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toStringAsFixed(0)}${_getMetricUnit()}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  minX: chartData.first.x,
                  maxX: chartData.last.x,
                  minY: chartData.map((spot) => spot.y).reduce((a, b) => a < b ? a : b) * 0.9,
                  maxY: chartData.map((spot) => spot.y).reduce((a, b) => a > b ? a : b) * 1.1,
                  lineBarsData: [
                    LineChartBarData(
                      spots: chartData,
                      isCurved: _showTrendLine,
                      color: widget.turtle.color,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: _showDataPoints,
                        getDotPainter: (spot, percent, barData, index) =>
                            FlDotCirclePainter(
                          radius: 4,
                          color: widget.turtle.color,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: widget.turtle.color.withOpacity(0.1),
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

  double _getHorizontalInterval() {
    final chartData = _getChartData();
    if (chartData.isEmpty) return 1;
    
    final minY = chartData.map((spot) => spot.y).reduce((a, b) => a < b ? a : b);
    final maxY = chartData.map((spot) => spot.y).reduce((a, b) => a > b ? a : b);
    final range = maxY - minY;
    
    if (range <= 10) return 2;
    if (range <= 50) return 10;
    if (range <= 100) return 20;
    return 50;
  }

  double _getVerticalInterval(List<FlSpot> chartData) {
    if (chartData.isEmpty) return 1;
    
    final range = chartData.last.x - chartData.first.x;
    if (range <= 30) return 7; // 一周间隔
    if (range <= 90) return 15; // 半月间隔
    if (range <= 365) return 30; // 一月间隔
    return 60; // 两月间隔
  }

  Widget _buildStatsCard() {
    if (_records.isEmpty) return const SizedBox.shrink();

    final values = _records.map(_getMetricValue).toList();
    final currentValue = values.last;
    final firstValue = values.first;
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final avgValue = values.reduce((a, b) => a + b) / values.length;
    final growth = currentValue - firstValue;
    final growthPercent = firstValue > 0 ? (growth / firstValue * 100) : 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '统计信息',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    '当前值',
                    '${currentValue.toStringAsFixed(1)}${_getMetricUnit()}',
                    Icons.trending_up,
                    widget.turtle.color,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '总增长',
                    '${growth >= 0 ? '+' : ''}${growth.toStringAsFixed(1)}${_getMetricUnit()}',
                    growth >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                    growth >= 0 ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    '增长率',
                    '${growthPercent >= 0 ? '+' : ''}${growthPercent.toStringAsFixed(1)}%',
                    Icons.percent,
                    growthPercent >= 0 ? Colors.green : Colors.red,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '平均值',
                    '${avgValue.toStringAsFixed(1)}${_getMetricUnit()}',
                    Icons.analytics,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    '最大值',
                    '${maxValue.toStringAsFixed(1)}${_getMetricUnit()}',
                    Icons.keyboard_arrow_up,
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '最小值',
                    '${minValue.toStringAsFixed(1)}${_getMetricUnit()}',
                    Icons.keyboard_arrow_down,
                    Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataList() {
    if (_records.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '历史数据',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _records.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final record = _records[_records.length - 1 - index]; // 倒序显示
                final value = _getMetricValue(record);
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: widget.turtle.color.withOpacity(0.1),
                    child: Icon(
                      _selectedMetric == 'weight'
                          ? Icons.monitor_weight
                          : _selectedMetric == 'length'
                              ? Icons.straighten
                              : Icons.width_normal,
                      color: widget.turtle.color,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    record.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${record.date.year}/${record.date.month}/${record.date.day}',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  trailing: Text(
                    '${value.toStringAsFixed(1)}${_getMetricUnit()}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: widget.turtle.color,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('图表设置'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: const Text('显示数据点'),
                    value: _showDataPoints,
                    onChanged: (value) {
                      setDialogState(() {
                        _showDataPoints = value;
                      });
                      setState(() {
                        _showDataPoints = value;
                      });
                    },
                  ),
                  SwitchListTile(
                    title: const Text('显示趋势线'),
                    value: _showTrendLine,
                    onChanged: (value) {
                      setDialogState(() {
                        _showTrendLine = value;
                      });
                      setState(() {
                        _showTrendLine = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('时间范围'),
                  DropdownButton<int>(
                    value: _timeRange,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 30, child: Text('最近30天')),
                      DropdownMenuItem(value: 90, child: Text('最近3个月')),
                      DropdownMenuItem(value: 180, child: Text('最近6个月')),
                      DropdownMenuItem(value: 365, child: Text('最近1年')),
                      DropdownMenuItem(value: 9999, child: Text('全部时间')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          _timeRange = value;
                        });
                        setState(() {
                          _timeRange = value;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('关闭'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
