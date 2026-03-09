import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import '../services/sn_manager_service.dart';

/// SN 记录管理页面
class SNRecordsScreen extends StatefulWidget {
  const SNRecordsScreen({super.key});

  @override
  State<SNRecordsScreen> createState() => _SNRecordsScreenState();
}

class _SNRecordsScreenState extends State<SNRecordsScreen> {
  final SNManagerService _snManager = SNManagerService();
  List<SNRecord> _records = [];
  bool _isLoading = true;
  Map<String, dynamic>? _statistics;

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
      await _snManager.init();
      _records = _snManager.getAllRecords();
      _statistics = _snManager.getStatistics();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载记录失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  /// 导出 CSV 文件
  Future<void> _exportToCSV() async {
    try {
      // 生成 CSV 内容
      final csvContent = await _snManager.exportToCSV();

      // 选择保存路径
      final result = await FilePicker.platform.saveFile(
        dialogTitle: '导出 SN 记录',
        fileName: 'sn_records_${DateTime.now().millisecondsSinceEpoch}.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        // 写入文件
        final file = File(result);
        await file.writeAsString(csvContent, encoding: utf8);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('CSV 文件已导出到: $result'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导出失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 查看 JSON 文件位置
  Future<void> _showDataFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/sn_records.json';

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('数据文件位置'),
          content: SelectableText(
            filePath,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: filePath));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('路径已复制到剪贴板'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: const Text('复制路径'),
            ),
          ],
        ),
      );
    }
  }

  /// 清空所有记录
  Future<void> _clearAllRecords() async {
    // 显示确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('确认清空'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '此操作将删除所有 SN 记录并重置 MAC 地址索引！',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text('当前记录数: ${_records.length}'),
            const SizedBox(height: 8),
            const Text('删除后：'),
            const Text('• 所有 SN 记录将被永久删除'),
            const Text('• WiFi MAC 索引重置为: 48:08:EB:50:00:50'),
            const Text('• 蓝牙 MAC 索引重置为: 48:08:EB:60:00:50'),
            const SizedBox(height: 12),
            const Text(
              '此操作不可恢复，确定要继续吗？',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('确定清空'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final count = await _snManager.clearAllRecords();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ 已清空所有记录，共删除 $count 条'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        
        // 重新加载记录
        await _loadRecords();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('清空失败: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SN 记录管理'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: '查看数据文件位置',
            onPressed: _showDataFilePath,
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: '导出 CSV',
            onPressed: _records.isEmpty ? null : _exportToCSV,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: '清空所有记录',
            onPressed: _records.isEmpty ? null : _clearAllRecords,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: _loadRecords,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 统计信息卡片
                if (_statistics != null) _buildStatisticsCard(),
                
                // 记录列表
                Expanded(
                  child: _records.isEmpty
                      ? const Center(
                          child: Text(
                            '暂无 SN 记录',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                      : _buildRecordsList(),
                ),
              ],
            ),
    );
  }

  /// 构建统计信息卡片
  Widget _buildStatisticsCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '统计信息',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('总记录数', '${_statistics!['total_records']}'),
                _buildStatItem('WiFi MAC 索引', '${_statistics!['current_wifi_mac_index']}'),
                _buildStatItem('蓝牙 MAC 索引', '${_statistics!['current_bt_mac_index']}'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('下一个 WiFi MAC', _statistics!['next_wifi_mac']),
                _buildStatItem('下一个蓝牙 MAC', _statistics!['next_bt_mac']),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  /// 构建记录列表
  Widget _buildRecordsList() {
    return ListView.builder(
      itemCount: _records.length,
      itemBuilder: (context, index) {
        final record = _records[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ExpansionTile(
            title: Text(
              record.sn,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text('硬件版本: ${record.hardwareVersion}'),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRecordRow('WiFi MAC', record.wifiMac ?? 'N/A'),
                    _buildRecordRow('蓝牙 MAC', record.btMac ?? 'N/A'),
                    _buildRecordRow('创建时间', _formatDateTime(record.createdAt)),
                    _buildRecordRow('更新时间', _formatDateTime(record.updatedAt)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecordRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }
}
