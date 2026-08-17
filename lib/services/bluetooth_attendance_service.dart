import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BluetoothAttendanceService {
  BluetoothAttendanceService._();
  static final BluetoothAttendanceService instance = BluetoothAttendanceService._();

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  bool _isScanning = false;
  bool get isScanning => _isScanning;

  final Set<String> _seenDeviceIds = {};

  // ============================================================
  // START BLUETOOTH SCANNING
  // Returns as soon as the scan is started — does not block for
  // the scan duration. Call stopScanning() to stop early.
  // ============================================================

  Future<void> startScanning({
    required void Function(ScanResult result) onDeviceFound,
  }) async {
    if (_isScanning) return;

    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      throw Exception("Please turn on Bluetooth.");
    }

    _seenDeviceIds.clear();
    await _scanSubscription?.cancel();

    _scanSubscription = FlutterBluePlus.onScanResults.listen(
          (results) {
        for (final result in results) {
          final id = result.device.remoteId.str;
          if (_seenDeviceIds.contains(id)) continue;
          _seenDeviceIds.add(id);
          onDeviceFound(result);
        }
      },
      onError: (error) {
        _isScanning = false;
        _scanSubscription?.cancel();
        _scanSubscription = null;
      },
    );

    _isScanning = true;

    // startScan's own timeout handles stopping the scan; we don't
    // block on it here, and we don't add a redundant manual delay.
    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 30),
    );
  }

  // ============================================================
  // STOP BLUETOOTH SCANNING
  // ============================================================

  Future<void> stopScanning() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {
      // Ignore stop errors.
    }
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    _isScanning = false;
    _seenDeviceIds.clear();
  }

  // ============================================================
  // CHECK BLUETOOTH
  // ============================================================

  Future<bool> isBluetoothEnabled() async {
    final state = await FlutterBluePlus.adapterState.first;
    return state == BluetoothAdapterState.on;
  }

  // ============================================================
  // EXTRACT ATTENDANCE TOKEN FROM SCAN RESULT
  // Adjust the parsing below to match exactly how your native
  // startAdvertising code packs the token into the advertisement
  // (e.g. manufacturer data, or a specific service data UUID).
  // ============================================================

  String? extractSessionToken(ScanResult result) {
    final manufacturerData = result.advertisementData.manufacturerData;
    final bytes = manufacturerData[0x02E0];
    if (bytes == null || bytes.isEmpty) return null;
    return String.fromCharCodes(bytes);
  }
}