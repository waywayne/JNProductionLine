import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/ota_state.dart';
import '../models/test_state.dart';

class OTAUpgradeWidget extends StatelessWidget {
  const OTAUpgradeWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<OTAState, TestState>(
      builder: (context, otaState, testState, _) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.grey[50]!, Colors.white],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 标题
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.deepPurple[600]!, Colors.deepPurple[400]!],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.system_update, color: Colors.white, size: 24),
                      const SizedBox(width: 10),
                      const Text(
                        '产测 OTA 升级',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      // 连接状态指示
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: otaState.isConnected
                              ? Colors.green.withOpacity(0.3)
                              : Colors.red.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              otaState.isConnected ? Icons.link : Icons.link_off,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              otaState.isConnected ? '已连接' : '未连接',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // 文件选择区域
                _buildFileSelector(context, otaState),
                
                const SizedBox(height: 16),
                
                // 操作按钮
                _buildActionButtons(context, otaState),
                
                const SizedBox(height: 16),
                
                // 升级进度/状态
                if (otaState.isUpgrading || otaState.currentStep == OTAStep.success || otaState.currentStep == OTAStep.failed)
                  Expanded(child: _buildProgressPanel(context, otaState)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFileSelector(BuildContext context, OTAState otaState) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.folder_open, color: Colors.deepPurple[400], size: 20),
              const SizedBox(width: 8),
              const Text(
                'OTA 固件文件',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Text(
                    otaState.selectedFileName ?? '未选择文件',
                    style: TextStyle(
                      fontSize: 13,
                      color: otaState.selectedFileName != null ? Colors.black87 : Colors.grey[500],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: otaState.isUpgrading ? null : () => _pickFile(context, otaState),
                icon: const Icon(Icons.file_upload, size: 18),
                label: const Text('选择文件'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple[500],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          if (otaState.selectedFilePath != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                otaState.selectedFilePath!,
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, OTAState otaState) {
    if (otaState.isUpgrading) {
      return SizedBox(
        height: 50,
        child: ElevatedButton.icon(
          onPressed: () => otaState.stopOTA(),
          icon: const Icon(Icons.stop_circle, size: 24),
          label: const Text(
            '停止升级',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red[600],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      );
    }
    
    final canStart = otaState.selectedFilePath != null && otaState.isConnected;
    
    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: canStart ? () => otaState.startOTAUpgrade() : null,
        icon: const Icon(Icons.rocket_launch, size: 24),
        label: Text(
          !otaState.isConnected
              ? '请先连接设备'
              : otaState.selectedFilePath == null
                  ? '请先选择OTA文件'
                  : '开始OTA升级',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple[600],
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[300],
          disabledForegroundColor: Colors.grey[500],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressPanel(BuildContext context, OTAState otaState) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 头部
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getStepHeaderColor(otaState.currentStep).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                _getStepIcon(otaState.currentStep),
                const SizedBox(width: 10),
                Text(
                  _getStepTitle(otaState.currentStep),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _getStepHeaderColor(otaState.currentStep),
                  ),
                ),
              ],
            ),
          ),
          
          // 进度内容
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (otaState.currentStep == OTAStep.success) ...[
                    Icon(Icons.check_circle, color: Colors.green[600], size: 80),
                    const SizedBox(height: 16),
                    Text(
                      'OTA升级成功！',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => otaState.reset(),
                      child: const Text('完成'),
                    ),
                  ] else if (otaState.currentStep == OTAStep.failed) ...[
                    Icon(Icons.error, color: Colors.red[600], size: 80),
                    const SizedBox(height: 16),
                    Text(
                      'OTA升级失败',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (otaState.errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Text(
                          otaState.errorMessage!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.red[700],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => otaState.reset(),
                      child: const Text('重试'),
                    ),
                  ] else ...[
                    // 升级中
                    const SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(
                        strokeWidth: 4,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      otaState.statusMessage,
                      style: const TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    // 步骤指示器
                    _buildStepIndicator(otaState),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(OTAState otaState) {
    final steps = [
      {'step': OTAStep.connectWiFi, 'label': '连接WiFi'},
      {'step': OTAStep.uploadFile, 'label': '上传文件'},
      {'step': OTAStep.startTest, 'label': '产测开始'},
      {'step': OTAStep.sendOTARequest, 'label': 'OTA请求'},
      {'step': OTAStep.upgrading, 'label': '升级中'},
    ];
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: steps.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;
        final stepEnum = step['step'] as OTAStep;
        final label = step['label'] as String;
        final currentIndex = steps.indexWhere((s) => s['step'] == otaState.currentStep);
        
        final isCompleted = index < currentIndex;
        final isCurrent = stepEnum == otaState.currentStep;
        
        return Row(
          children: [
            Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted
                        ? Colors.green
                        : isCurrent
                            ? Colors.deepPurple
                            : Colors.grey[300],
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, color: Colors.white, size: 14)
                        : isCurrent
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: isCurrent ? Colors.deepPurple : Colors.grey[600],
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
            if (index < steps.length - 1)
              Container(
                width: 20,
                height: 2,
                margin: const EdgeInsets.only(bottom: 16),
                color: isCompleted ? Colors.green : Colors.grey[300],
              ),
          ],
        );
      }).toList(),
    );
  }

  Color _getStepHeaderColor(OTAStep step) {
    switch (step) {
      case OTAStep.success:
        return Colors.green;
      case OTAStep.failed:
        return Colors.red;
      default:
        return Colors.deepPurple;
    }
  }

  Widget _getStepIcon(OTAStep step) {
    switch (step) {
      case OTAStep.success:
        return Icon(Icons.check_circle, color: Colors.green[600], size: 22);
      case OTAStep.failed:
        return Icon(Icons.error, color: Colors.red[600], size: 22);
      default:
        return const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
    }
  }

  String _getStepTitle(OTAStep step) {
    switch (step) {
      case OTAStep.idle:
        return '等待开始';
      case OTAStep.selectFile:
        return '选择文件';
      case OTAStep.connectWiFi:
        return '连接WiFi';
      case OTAStep.uploadFile:
        return '上传文件';
      case OTAStep.startTest:
        return '产测开始';
      case OTAStep.sendOTARequest:
        return '发送OTA请求';
      case OTAStep.upgrading:
        return 'OTA升级中';
      case OTAStep.success:
        return '升级成功';
      case OTAStep.failed:
        return '升级失败';
    }
  }

  Future<void> _pickFile(BuildContext context, OTAState otaState) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        dialogTitle: '选择OTA固件文件',
      );
      
      if (result != null && result.files.single.path != null) {
        otaState.setSelectedFile(result.files.single.path!);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('选择文件失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
