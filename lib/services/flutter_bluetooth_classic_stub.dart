// Stub implementation for flutter_bluetooth_classic_serial
// Used on platforms where the plugin is not available (e.g., Linux)

/// Stub class for FlutterBluetoothClassic
class FlutterBluetoothClassic {
  /// Get paired devices (stub)
  Future<List<BluetoothDevice>> getPairedDevices() async {
    throw UnsupportedError(
      'flutter_bluetooth_classic_serial is not supported on this platform. '
      'This plugin only works on Windows.',
    );
  }

  /// Connect to device (stub)
  Future<bool> connect(String address) async {
    throw UnsupportedError(
      'flutter_bluetooth_classic_serial is not supported on this platform. '
      'This plugin only works on Windows.',
    );
  }

  /// Disconnect (stub)
  Future<void> disconnect() async {
    throw UnsupportedError(
      'flutter_bluetooth_classic_serial is not supported on this platform. '
      'This plugin only works on Windows.',
    );
  }

  /// Send data (stub)
  Future<void> sendData(List<int> data) async {
    throw UnsupportedError(
      'flutter_bluetooth_classic_serial is not supported on this platform. '
      'This plugin only works on Windows.',
    );
  }

  /// Data received stream (stub)
  Stream<DataReceived> get onDataReceived => Stream.empty();
}

/// Stub class for BluetoothDevice
class BluetoothDevice {
  final String name;
  final String address;

  BluetoothDevice({required this.name, required this.address});
}

/// Stub class for DataReceived
class DataReceived {
  final List<int> data;

  DataReceived(this.data);
}
