import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../models/turtle_record.dart';
import '../models/turtle.dart';
import '../services/turtle_service.dart';

class AddRecordPage extends StatefulWidget {
  final TurtleRecord? recordToEdit;
  final List<Turtle> turtles;
  final VoidCallback onSaved;

  const AddRecordPage({
    Key? key,
    this.recordToEdit,
    required this.turtles,
    required this.onSaved,
  }) : super(key: key);

  @override
  State<AddRecordPage> createState() => _AddRecordPageState();
}

class _AddRecordPageState extends State<AddRecordPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _weightController = TextEditingController();
  final _lengthController = TextEditingController();
  final _widthController = TextEditingController();
  final _notesController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  String? _selectedTurtleId;
  bool _isLoading = false;
  String? _photoPath; // 记录图片路径
  final ImagePicker _picker = ImagePicker();
  bool _userEditedTitle = false; // 标题是否被用户手动编辑
  bool _autoTitleGenerated = false; // 当前标题是否系统生成

  @override
  void initState() {
    super.initState();
    if (widget.recordToEdit != null) {
      final record = widget.recordToEdit!;
      _titleController.text = record.title;
      _descriptionController.text = record.description;
      _weightController.text = record.weight?.toString() ?? '';
      _lengthController.text = record.length?.toString() ?? '';
      _widthController.text = record.width?.toString() ?? '';
      _notesController.text = record.notes ?? '';
      _selectedDate = record.date;
      _selectedTurtleId = record.turtleId;
      _photoPath = record.photoPath;
      _userEditedTitle = true; // 编辑模式视为用户已有标题
    } else {
      // 如果是新记录，默认选择第一只乌龟
      if (widget.turtles.isNotEmpty) {
        _selectedTurtleId = widget.turtles.first.id;
      }
      // 尝试生成默认标题
      // 延后到首帧后以确保控件已挂载
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeSetDefaultTitle();
      });
    }
  }

  Future<void> _maybeSetDefaultTitle() async {
    if (_userEditedTitle) return;
    final turtleId = _selectedTurtleId;
    if (turtleId == null) return;
    final turtle = widget.turtles.firstWhere(
      (t) => t.id == turtleId,
      orElse: () => widget.turtles.isNotEmpty
          ? widget.turtles.first
          : Turtle(
              id: turtleId,
              name: '这只龟',
              species: '',
              birthDate: DateTime.now(),
              color: Colors.green,
            ),
    );
    final records = await TurtleService.getRecordsByTurtle(turtleId);
    final nextIndex = records.length + 1;
    if (!mounted) return;
    setState(() {
      if (_titleController.text.trim().isEmpty || _autoTitleGenerated) {
        _titleController.text = '${turtle.name} 第$nextIndex次测量';
        _autoTitleGenerated = true;
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _weightController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.recordToEdit != null;
    
    return Scaffold(
      backgroundColor: Colors.green.shade50,
      appBar: AppBar(
        title: Text(isEditing ? '编辑记录' : '添加记录'),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 选择乌龟 + 日期 + 测量 数据 合并卡片
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
                            Icons.pets,
                            color: Colors.green.shade600,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '基本信息（必选）',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedTurtleId,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.pets),
                        ),
                        hint: const Text('请选择一只乌龟'),
                        items: widget.turtles.map((turtle) {
                          return DropdownMenuItem<String>(
                            value: turtle.id,
                            child: Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: turtle.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text('${turtle.name} (${turtle.species})'),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) async {
                          setState(() {
                            _selectedTurtleId = value;
                          });
                          await _maybeSetDefaultTitle();
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '请选择一只乌龟';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: Colors.green.shade600,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '记录日期',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: _selectDate,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.date_range,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${_selectedDate.year}年${_selectedDate.month}月${_selectedDate.day}日',
                                style: const TextStyle(fontSize: 16),
                              ),
                              const Spacer(),
                              Icon(
                                Icons.arrow_drop_down,
                                color: Colors.grey.shade600,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            Icons.straighten,
                            color: Colors.orange.shade600,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '测量数据（必填：体重 或 体长+体宽）',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _weightController,
                              decoration: InputDecoration(
                                labelText: '体重（克）',
                                hintText: '0.0',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                prefixIcon: const Icon(Icons.monitor_weight),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value != null && value.isNotEmpty) {
                                  final weight = double.tryParse(value);
                                  if (weight == null || weight < 0) {
                                    return '请输入有效的体重';
                                  }
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _lengthController,
                              decoration: InputDecoration(
                                labelText: '体长（厘米）',
                                hintText: '0.0',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                prefixIcon: const Icon(Icons.straighten),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value != null && value.isNotEmpty) {
                                  final length = double.tryParse(value);
                                  if (length == null || length < 0) {
                                    return '请输入有效的体长';
                                  }
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _widthController,
                        decoration: InputDecoration(
                          labelText: '体宽（厘米）',
                          hintText: '0.0',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.width_full),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            final width = double.tryParse(value);
                            if (width == null || width < 0) {
                              return '请输入有效的体宽';
                            }
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // 照片（可选）
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
                            Icons.photo,
                            color: Colors.orange.shade700,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '照片（可选）',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          if (_photoPath != null)
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _photoPath = null;
                                });
                              },
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('移除'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_photoPath != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(_photoPath!),
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        Container(
                          height: 120,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Center(
                            child: Text(
                              '未选择照片',
                              style: TextStyle(color: Colors.orange.shade700),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: () async {
                              final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                              if (image != null) {
                                setState(() {
                                  _photoPath = image.path;
                                });
                              }
                            },
                            icon: const Icon(Icons.photo_library),
                            label: const Text('从相册选择'),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final XFile? image = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
                              if (image != null) {
                                setState(() {
                                  _photoPath = image.path;
                                });
                              }
                            },
                            icon: const Icon(Icons.photo_camera),
                            label: const Text('拍照'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // 标题/描述/备注（选填）
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
                            Icons.edit,
                            color: Colors.blue.shade600,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '标题/描述/备注（选填）',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: '标题',
                          hintText: '留空将自动生成，例如：小绿 第3次测量',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.title),
                          helperText: _autoTitleGenerated ? '已自动生成标题，你也可以手动修改' : null,
                        ),
                        onChanged: (_) {
                          _userEditedTitle = true;
                          _autoTitleGenerated = false;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: '描述',
                          hintText: '详细描述这次记录的内容（可留空）',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.description),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _notesController,
                        decoration: InputDecoration(
                          labelText: '备注',
                          hintText: '记录其他信息（可留空）',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.note_add),
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // 保存按钮
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveRecord,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          isEditing ? '更新记录' : '保存记录',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveRecord() async {
    // 数值格式校验
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 必填规则：体重 或 体长+体宽
    final hasWeight = _weightController.text.trim().isNotEmpty;
    final hasLength = _lengthController.text.trim().isNotEmpty;
    final hasWidth = _widthController.text.trim().isNotEmpty;
    if (!hasWeight && !(hasLength && hasWidth)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写体重，或同时填写体长和体宽')),
      );
      return;
    }

    // 如果标题为空，尝试自动生成
    if (_titleController.text.trim().isEmpty) {
      await _maybeSetDefaultTitle();
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final record = TurtleRecord(
        id: widget.recordToEdit?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        turtleId: _selectedTurtleId!,
        date: _selectedDate,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        weight: _weightController.text.isEmpty ? null : double.parse(_weightController.text),
        length: _lengthController.text.isEmpty ? null : double.parse(_lengthController.text),
        width: _widthController.text.isEmpty ? null : double.parse(_widthController.text),
        photoPath: _photoPath,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      if (widget.recordToEdit != null) {
        await TurtleService.updateRecord(record);
      } else {
        await TurtleService.addRecord(record);
      }

      widget.onSaved();
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('保存失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
