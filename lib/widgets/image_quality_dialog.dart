import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/test_state.dart';

/// 图片质量检测弹窗
/// 显示图片 + 算法检测状态（检测中/通过/失败）
class ImageQualityDialog extends StatelessWidget {
  const ImageQualityDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TestState>(
      builder: (context, state, _) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 640,
              height: 520,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                children: [
                  // 标题栏
                  _buildTitleBar(context, state),
                  // 图片 + 检测状态叠加
                  Expanded(
                    child: _buildImageWithOverlay(state),
                  ),
                  // 底部状态信息
                  _buildStatusBar(state),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTitleBar(BuildContext context, TestState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _getStatusColor(state.imageQualityStatus).withOpacity(0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
        border: Border(
          bottom: BorderSide(
            color: _getStatusColor(state.imageQualityStatus).withOpacity(0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getStatusIcon(state.imageQualityStatus),
            color: _getStatusColor(state.imageQualityStatus),
            size: 22,
          ),
          const SizedBox(width: 8),
          Text(
            '图片质量检测',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _getStatusColor(state.imageQualityStatus),
            ),
          ),
          const Spacer(),
          if (state.imageQualityStatus != 'detecting')
            IconButton(
              onPressed: () => state.closeImageQualityDialog(),
              icon: const Icon(Icons.close, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: '关闭',
            ),
        ],
      ),
    );
  }

  Widget _buildImageWithOverlay(TestState state) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 图片
        if (state.completeImageData != null)
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                state.completeImageData!,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, size: 48, color: Colors.red[400]),
                        const SizedBox(height: 8),
                        Text('图片加载失败', style: TextStyle(color: Colors.red[600])),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

        // 检测状态叠加层
        if (state.imageQualityStatus == 'detecting')
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      strokeWidth: 4,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '算法检测中...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '正在进行棋盘格检测',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // 通过叠加层
        if (state.imageQualityStatus == 'pass')
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green, width: 3),
            ),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.green[700]!.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white, size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      '检测通过',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (state.imageQualityOutput != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '输出值: ${state.imageQualityOutput!.toStringAsFixed(4)}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

        // 失败叠加层
        if (state.imageQualityStatus == 'fail')
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red, width: 3),
            ),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.red[700]!.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cancel, color: Colors.white, size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      '检测失败',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.imageQualityMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatusBar(TestState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        border: Border(
          top: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              state.imageQualityMessage,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (state.completeImageData != null)
            Text(
              '${(state.completeImageData!.length / 1024).toStringAsFixed(1)} KB',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
              ),
            ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'detecting':
        return Colors.blue;
      case 'pass':
        return Colors.green;
      case 'fail':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'detecting':
        return Icons.search;
      case 'pass':
        return Icons.check_circle;
      case 'fail':
        return Icons.error;
      default:
        return Icons.image;
    }
  }
}
