import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/test_state.dart';

class IMUDataDialog extends StatelessWidget {
  const IMUDataDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TestState>(
      builder: (context, state, _) {
        return Dialog(
          child: Container(
            width: 600,
            height: 600,
            color: Colors.white,
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text('IMU Data', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                SizedBox(height: 20),
                Text('Testing: ${state.isIMUTesting}'),
                Text('Data count: ${state.imuDataList.length}'),
                SizedBox(height: 20),
                Expanded(
                  child: state.imuDataList.isEmpty
                      ? Center(child: Text('No data'))
                      : ListView.builder(
                          itemCount: state.imuDataList.length,
                          itemBuilder: (context, index) {
                            final data = state.imuDataList[index];
                            return Card(
                              child: ListTile(
                                title: Text('Data #${data['index']}'),
                                subtitle: Text('Gyro: ${data['gyro_x']}, ${data['gyro_y']}, ${data['gyro_z']}'),
                              ),
                            );
                          },
                        ),
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        // 关闭弹窗时停止IMU测试
                        if (state.isIMUTesting) {
                          await state.stopIMUDataStream();
                        }
                      },
                      icon: Icon(Icons.close),
                      label: Text('关闭'),
                    ),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () => state.confirmIMUTestResult(false),
                          child: Text('Fail'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        ),
                        SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () => state.confirmIMUTestResult(true),
                          child: Text('Pass'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
