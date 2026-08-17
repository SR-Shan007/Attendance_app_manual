import 'package:flutter/services.dart';

class TeacherBluetoothService {
  TeacherBluetoothService._();
  static final TeacherBluetoothService instance = TeacherBluetoothService._();

  static const MethodChannel _channel = MethodChannel(
    'com.example.attend_/bluetooth', // confirm this matches your native channel name
  );

  static const String attendanceServiceUuid =
      "7A7F0001-4A56-4D3A-9C01-250000000001";

  bool _isAdvertising = false;
  bool get isAdvertising => _isAdvertising;

  // ============================================================
  // START ADVERTISING
  // ============================================================

  Future<void> startAdvertising({
    required String sessionId,
    required String sessionToken,
  }) async {
    if (_isAdvertising) return;

    try {
      final result = await _channel.invokeMethod<bool>(
        'startAdvertising',
        {
          'sessionId': sessionId,
          'sessionToken': sessionToken,
          'serviceUuid': attendanceServiceUuid,
        },
      );
      if (result != true) {
        throw Exception("Could not start Bluetooth advertising.");
      }
      _isAdvertising = true;
    } on PlatformException catch (e) {
      throw Exception(e.message ?? "Failed to start Bluetooth advertising.");
    }
  }

  // ============================================================
  // STOP ADVERTISING
  // ============================================================

  Future<void> stopAdvertising() async {
    if (!_isAdvertising) return;
    try {
      await _channel.invokeMethod<bool>('stopAdvertising');
    } on PlatformException catch (e) {
      throw Exception(e.message ?? "Failed to stop Bluetooth advertising.");
    } finally {
      _isAdvertising = false;
    }
  }

  bool get attendanceBroadcasting => _isAdvertising;

  Future<void> dispose() async {
    await stopAdvertising();
  }
}