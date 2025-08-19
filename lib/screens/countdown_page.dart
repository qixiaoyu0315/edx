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
  final MqttService _mqttService = MqttService();

  void _addItem() {
    _showEditDialog();
  }

  void _editItem(CountdownItem item) {
    _showEditDialog(item: item);
  }

  void _showEditDialog({CountdownItem? item}) {
    final isEditing = item != null;
    final _nameController = TextEditingController(text: isEditing ? item.name : '');
    final _durationController = TextEditingController(text: isEditing ? item.milliseconds.toString() : '');
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
                      _items.add(CountdownItem(
                        id: DateTime.now().toString(),
                        name: _nameController.text,
                        milliseconds: int.parse(_durationController.text),
                      ));
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('MQTT 未连接!')), 
      );
      return;
    }

    final Map<String, int> payloadMap = {};
    for (var item in _items) {
      payloadMap[item.name] = item.milliseconds;
    }

    final payload = jsonEncode(payloadMap);
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);

    _mqttService.client.publishMessage(
      _mqttService.topic,
      MqttQos.atLeastOnce,
      builder.payload!,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('数据已发送!')), 
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView.builder(
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          return ListTile(
            title: Text(item.name),
            subtitle: Text('${item.milliseconds} ms'),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _editItem(item),
            ),
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _addItem,
            heroTag: 'add',
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: _sendData,
            heroTag: 'send',
            child: const Icon(Icons.send),
            backgroundColor: _mqttService.isConnected ? Colors.green : Colors.grey,
          ),
        ],
      ),
    );
  }
}
