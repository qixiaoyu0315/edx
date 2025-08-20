import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../models/countdown_item.dart';
import '../services/mqtt_service.dart';
import '../services/database_helper.dart';

class CountdownPage extends StatefulWidget {
  const CountdownPage({super.key});

  @override
  _CountdownPageState createState() => _CountdownPageState();
}

class _CountdownPageState extends State<CountdownPage> {
  final dbHelper = DatabaseHelper();
  List<CountdownItem> _items = [];
  List<TimeOfDay> _timeList = [];
  bool _isTimingEnabled = false;
  bool _isLoading = true;
  final MqttService _mqttService = MqttService();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final items = await dbHelper.getCountdownItems();
    final times = await dbHelper.getTimedSchedules();
    final isEnabled = await dbHelper.getIsTimingEnabled();
    if (mounted) {
      setState(() {
        _items = items;
        _timeList = times;
        _isTimingEnabled = isEnabled;
        _isLoading = false;
      });
    }
  }

  void _addItem() {
    _showEditDialog();
  }

  void _editItem(CountdownItem item) {
    _showEditDialog(item: item);
  }

  void _deleteItem(CountdownItem item) {
    dbHelper.deleteCountdownItem(item.id);
    setState(() {
      _items.remove(item);
    });
    ShadToaster.of(context).show(
      ShadToast(
        description: Text('已删除项目: ${item.name}'),
      ),
    );
  }

  void _showEditDialog({CountdownItem? item}) {
    final isEditing = item != null;
    final nameController = TextEditingController(
      text: isEditing ? item.name : '',
    );
    final durationController = TextEditingController(
      text: isEditing ? item.milliseconds.toString() : '',
    );
    final _formKey = GlobalKey<ShadFormState>();

    showShadDialog(
      context: context,
      builder: (context) {
        return ShadDialog(
          title: Text(isEditing ? '修改项目' : '新增项目'),
          child: ShadForm(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShadInputFormField(
                  controller: nameController,
                  label: const Text('名称 (例如: q1)'),
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return '名称不能为空';
                    }
                    final regex = RegExp(r'^q\d+$');
                    if (!regex.hasMatch(value!)) {
                      return '格式必须是 "q" 后跟数字';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                ShadInputFormField(
                  controller: durationController,
                  label: const Text('倒计时 (毫秒)'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return '毫秒数不能为空';
                    }
                    if (int.tryParse(value!) == null) {
                      return '请输入有效的数字';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            ShadButton.ghost(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ShadButton(
              onPressed: () {
                if (_formKey.currentState!.saveAndValidate()) {
                  setState(() {
                    if (isEditing) {
                      item!.name = nameController.text;
                      item.milliseconds = int.parse(durationController.text);
                      dbHelper.updateCountdownItem(item);
                    } else {
                      final newItem = CountdownItem(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: nameController.text,
                        milliseconds: int.parse(durationController.text),
                      );
                      _items.add(newItem);
                      dbHelper.insertCountdownItem(newItem);
                    }
                  });
                  Navigator.of(context).pop();
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  void _sendData() {
    if (!_mqttService.isConnected) {
      ShadToaster.of(context).show(
        ShadToast(
          description: const Text('MQTT 未连接!'),
        ),
      );
      return;
    }

    final Map<String, dynamic> payloadMap = {};
    for (var item in _items) {
      payloadMap[item.name] = item.milliseconds;
    }

    if (_isTimingEnabled) {
      payloadMap['d_t'] = _timeList
          .map(
            (time) =>
                '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
          )
          .toList();
    }

    final payload = jsonEncode(payloadMap);
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);

    _mqttService.client.publishMessage(
      _mqttService.topic,
      MqttQos.atLeastOnce,
      builder.payload!,
    );

    ShadToaster.of(context).show(
      ShadToast(
        description: const Text('数据发送成功'),
      ),
    );
  }

  void _addTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null &&
        !_timeList.any(
          (time) => time.hour == picked.hour && time.minute == picked.minute,
        )) {
      dbHelper.insertTimedSchedule(picked);
      setState(() {
        _timeList.add(picked);
        _timeList.sort((a, b) {
          if (a.hour != b.hour) return a.hour.compareTo(b.hour);
          return a.minute.compareTo(b.minute);
        });
      });
    }
  }

  void _editTime(int index) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _timeList[index],
    );
    if (picked != null) {
      final bool exists = _timeList.asMap().entries.any(
        (entry) =>
            entry.key != index &&
            entry.value.hour == picked.hour &&
            entry.value.minute == picked.minute,
      );
      if (!exists) {
        final oldTime = _timeList[index];
        dbHelper.updateTimedSchedule(oldTime, picked);
        setState(() {
          _timeList[index] = picked;
          _timeList.sort((a, b) {
            if (a.hour != b.hour) return a.hour.compareTo(b.hour);
            return a.minute.compareTo(b.minute);
          });
        });
      } else {
        ShadToaster.of(context).show(
          ShadToast(
            description: const Text('该时间已存在!'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildCountdownCard(theme),
            const SizedBox(height: 16),
            _buildTimedFeedingCard(theme),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _sendData,
        child: const Icon(Icons.send),
        backgroundColor: _mqttService.isConnected
            ? Colors.blue
            : Colors.grey,
      ),
    );
  }

  Widget _buildCountdownCard(ShadThemeData theme) {
    return ShadCard(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('倒计时项目', style: theme.textTheme.h4),
          ShadButton(
            onPressed: _addItem,
            child: const Text('新增项目'),
          ),
        ],
      ),
      child: _items.isEmpty
          ? const Center(child: Text('点击 + 添加项目'))
          : Column(
              children: _items.map((item) {
                return ListTile(
                  title: Text(item.name),
                  subtitle: Text('${item.milliseconds} ms'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ShadButton(
                        onPressed: () => _editItem(item),
                        child: const Text('编辑'),
                      ),
                      ShadButton(
                        onPressed: () => _deleteItem(item),
                        child: const Text('删除'),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildTimedFeedingCard(ShadThemeData theme) {
    return ShadCard(
      title: Text('定时投喂', style: theme.textTheme.h4),
      child: Column(
        children: [
          Row(
            children: [
              ShadSwitch(
                value: _isTimingEnabled,
                onChanged: (value) {
                  setState(() => _isTimingEnabled = value);
                },
              ),
              const SizedBox(width: 8),
              ShadButton.ghost(
                onPressed: _addTime,
                child: const Icon(Icons.add_alarm),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _timeList.isEmpty
              ? const Center(child: Text('点击闹钟图标 + 添加时间'))
              : Column(
                  children: _timeList.asMap().entries.map((entry) {
                    final index = entry.key;
                    final time = entry.value;
                    return ListTile(
                      title: Text(
                        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ShadButton.ghost(
                            onPressed: () => _editTime(index),
                            child: const Icon(Icons.edit, size: 20),
                          ),
                          ShadButton.ghost(
                            onPressed: () {
                              dbHelper.deleteTimedSchedule(time);
                              setState(() => _timeList.removeAt(index));
                            },
                            child: const Icon(Icons.delete, size: 20),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }
}
