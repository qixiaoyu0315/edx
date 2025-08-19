import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import '../models/countdown_item.dart';
import '../services/mqtt_service.dart';

class CountdownPage extends StatefulWidget {
  @override
  _CountdownPageState createState() => _CountdownPageState();
}

class _CountdownPageState extends State<CountdownPage> {
  final List<CountdownItem> _items = [];
  final List<TimeOfDay> _timeList = [];
  bool _isTimingEnabled = false;
  final MqttService _mqttService = MqttService();

  void _addItem() {
    _showEditDialog();
  }

  void _editItem(CountdownItem item) {
    _showEditDialog(item: item);
  }

  void _deleteItem(CountdownItem item) {
    setState(() {
      _items.remove(item);
    });
  }

  void _showEditDialog({CountdownItem? item}) {
    final isEditing = item != null;
    final _nameController = TextEditingController(
      text: isEditing ? item.name : '',
    );
    final _durationController = TextEditingController(
      text: isEditing ? item.milliseconds.toString() : '',
    );
    final _formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditing ? '修改项目' : '新增项目'),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: '名称 (例如: q1)'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '名称不能为空';
                    }
                    final regex = RegExp(r'^q\d+$');
                    if (!regex.hasMatch(value)) {
                      return '格式必须是 "q" 后跟数字';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _durationController,
                  decoration: const InputDecoration(labelText: '倒计时 (毫秒)'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '毫秒数不能为空';
                    }
                    if (int.tryParse(value) == null) {
                      return '请输入有效的数字';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  setState(() {
                    if (isEditing) {
                      item.name = _nameController.text;
                      item.milliseconds = int.parse(_durationController.text);
                    } else {
                      _items.add(
                        CountdownItem(
                          id: DateTime.now().toString(),
                          name: _nameController.text,
                          milliseconds: int.parse(_durationController.text),
                        ),
                      );
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('MQTT 未连接!')));
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

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('数据已发送!')));
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
        setState(() {
          _timeList[index] = picked;
          _timeList.sort((a, b) {
            if (a.hour != b.hour) return a.hour.compareTo(b.hour);
            return a.minute.compareTo(b.minute);
          });
        });
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('该时间已存在!')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('吃饱喝足'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addItem,
            tooltip: '新增项目',
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _items.isEmpty
                ? const Center(child: Text('点击右上角 + 添加项目'))
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 2.5,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return Card(
                        child: ListTile(
                          title: Text(
                            item.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          subtitle: Text('${item.milliseconds} ms'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () => _editItem(item),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 20),
                                onPressed: () => _deleteItem(item),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 20, thickness: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('定时投喂', style: Theme.of(context).textTheme.titleLarge),
                Row(
                  children: [
                    Switch(
                      value: _isTimingEnabled,
                      onChanged: (v) => setState(() => _isTimingEnabled = v),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_alarm),
                      onPressed: _addTime,
                      tooltip: '新增时间',
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _timeList.isEmpty
                ? const Center(child: Text('点击闹钟图标 + 添加时间'))
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 2.5,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                    itemCount: _timeList.length,
                    itemBuilder: (context, index) {
                      final time = _timeList[index];
                      return Card(
                        child: ListTile(
                          title: Text(
                            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () => _editTime(index),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 20),
                                onPressed: () =>
                                    setState(() => _timeList.removeAt(index)),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _sendData,
        heroTag: 'sendData',
        tooltip: '发送数据',
        backgroundColor: _mqttService.isConnected
            ? Theme.of(context).colorScheme.primary
            : Colors.grey,
        child: const Icon(Icons.send),
      ),
    );
  }
}
