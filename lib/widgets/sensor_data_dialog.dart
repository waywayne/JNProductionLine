import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import '../models/test_state.dart';

/// Sensor数据显示弹窗
/// 显示实时接收的sensor数据，支持清空数据和关闭弹窗
class SensorDataDialog extends StatelessWidget {
  const SensorDataDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TestState>(
      builder: (context, state, _) {
        return AlertDialog(
          backgroundColor: Colors.white,
          elevation: 8,
          title: Row(
            children: [
              Icon(
                state.isSensorTesting ? Icons.sensors_outlined : Icons.sensors,
                color: state.isSensorTesting ? Colors.orange : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(
                'Sensor数据监听',
                style: TextStyle(
                  color: state.isSensorTesting ? Colors.orange : Colors.grey[700],
                ),
              ),
              const Spacer(),
              if (state.isSensorTesting)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange[300]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.orange[600]!),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '监听中',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[800],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          content: SizedBox(
            width: 600,
            height: 500,
            child: _buildDataContent(state),
          ),
          actions: const [],
        );
      },
    );
  }

  Widget _buildDataContent(TestState state) {
    // 优先显示FTP下载的图片（用于自动测试）
    if (state.completeImageData != null && state.completeImageData!.isNotEmpty) {
      return _buildFTPImageDisplay(state);
    }
    
    // 没有图片时显示提示
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '未找到Sensor测试图片',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '请先完成WiFi测试以下载图片',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
  
  /// 显示FTP下载的图片（用于自动测试）
  Widget _buildFTPImageDisplay(TestState state) {
    final imageData = state.completeImageData!;

    return Column(
      children: [
        // 图片显示区域
        Expanded(
          flex: 3,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue[300]!),
              borderRadius: BorderRadius.circular(8),
              color: Colors.blue[50],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                imageData,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  print('图片显示错误: $error');
                  return Container(
                    color: Colors.white,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image,
                            size: 48,
                            color: Colors.red[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '图片格式不支持或数据损坏',
                            style: TextStyle(
                              color: Colors.red[600],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '数据大小: ${imageData.length} 字节',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // 测试结果按钮
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.image_outlined,
                color: Colors.blue,
                size: 32,
              ),
              const SizedBox(height: 8),
              const Text(
                'Sensor测试图片',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '图片大小: ${(imageData.length / 1024).toStringAsFixed(2)} KB',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '请确认图片是否正确',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 测试失败按钮
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          state.confirmSensorTestResult(false);
                        },
                        icon: const Icon(Icons.cancel, size: 18),
                        label: const Text('测试失败'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[400],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  // 测试成功按钮
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          state.confirmSensorTestResult(true);
                        },
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: const Text('测试成功'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

}
