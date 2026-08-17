import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:local_auth/local_auth.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../services/attendance_service.dart';
import '../../services/bluetooth_attendance_service.dart';

class StudentAttendancePage extends StatefulWidget {
  final String courseName;
  final String courseId;

  const StudentAttendancePage({
    super.key,
    required this.courseName,
    required this.courseId,
  });

  @override
  State<StudentAttendancePage> createState() => _StudentAttendancePageState();
}

class _StudentAttendancePageState extends State<StudentAttendancePage> {
  final BluetoothAttendanceService _bluetoothService =
      BluetoothAttendanceService.instance;

  final AttendanceService _attendanceService = AttendanceService();
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool isScanning = false;
  bool isAuthenticating = false;
  bool attendanceCompleted = false;

  bool _teacherDetectedAlready = false;
  String? _scannedToken;

  // ============================================================
  // START ATTENDANCE
  // ============================================================

  Future<void> giveAttendance() async {
    if (isScanning || isAuthenticating || attendanceCompleted) {
      return;
    }

    setState(() {
      isScanning = true;
      _teacherDetectedAlready = false;
      _scannedToken = null;
    });

    try {
      final permissionsGranted = await _requestBluetoothPermissions();

      if (!permissionsGranted) {
        throw Exception(
          "Bluetooth and location permissions are required to mark attendance.",
        );
      }

      final bluetoothEnabled = await _bluetoothService.isBluetoothEnabled();

      if (!bluetoothEnabled) {
        throw Exception("Please turn on Bluetooth.");
      }

      await _bluetoothService.startScanning(
        onDeviceFound: _onTeacherFound,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isScanning = false;
      });

      _showMessage(
        e.toString().replaceFirst("Exception: ", ""),
        isError: true,
      );
    }
  }

  // ============================================================
  // REQUEST BLUETOOTH PERMISSIONS
  // ============================================================

  Future<bool> _requestBluetoothPermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }

  // ============================================================
  // TEACHER FOUND
  // ============================================================

  void _onTeacherFound(ScanResult result) {
    if (!isScanning || _teacherDetectedAlready) {
      return;
    }

    final token = _bluetoothService.extractSessionToken(result);
    if (token == null) {
      return;
    }

    _teacherDetectedAlready = true;
    _scannedToken = token;

    debugPrint(
      "Teacher attendance device detected: ${result.device.remoteId}",
    );

    _teacherDetected();
  }

  // ============================================================
  // TEACHER DETECTED
  // ============================================================

  Future<void> _teacherDetected() async {
    if (!mounted) return;

    setState(() {
      isScanning = false;
      isAuthenticating = true;
    });

    await _bluetoothService.stopScanning();

    try {
      final session = await _attendanceService.getActiveSession(
        widget.courseId,
      );

      if (session == null) {
        throw Exception("No active attendance session found.");
      }

      await _authenticateStudent();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isAuthenticating = false;
      });

      _showMessage(
        e.toString().replaceFirst("Exception: ", ""),
        isError: true,
      );
    }
  }

  // ============================================================
  // BIOMETRIC AUTHENTICATION
  // ============================================================

  Future<void> _authenticateStudent() async {
    final supported = await _localAuth.isDeviceSupported();
    final canCheck = await _localAuth.canCheckBiometrics;

    if (!supported && !canCheck) {
      throw Exception(
        "Biometric authentication is not available on this phone.",
      );
    }

    final authenticated = await _localAuth.authenticate(
      localizedReason: "Authenticate to mark your attendance",
      options: const AuthenticationOptions(
        biometricOnly: false,
        stickyAuth: true,
        useErrorDialogs: true,
      ),
    );

    if (!authenticated) {
      throw Exception("Authentication cancelled.");
    }

    await _submitAttendance();
  }

  // ============================================================
  // SUBMIT ATTENDANCE
  // ============================================================

  Future<void> _submitAttendance() async {
    final token = _scannedToken;

    if (token == null) {
      if (!mounted) return;
      setState(() {
        isAuthenticating = false;
      });
      _showMessage("Lost proximity token, please try again.", isError: true);
      return;
    }

    try {
      await _attendanceService.giveAttendance(scannedToken: token);

      if (!mounted) return;

      setState(() {
        isAuthenticating = false;
        attendanceCompleted = true;
      });

      _showMessage("Attendance marked successfully!", isError: false);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isAuthenticating = false;
      });

      _showMessage(
        e.toString().replaceFirst("Exception: ", ""),
        isError: true,
      );
    }
  }

  // ============================================================
  // CANCEL SCANNING
  // ============================================================

  Future<void> cancelScanning() async {
    await _bluetoothService.stopScanning();

    if (!mounted) return;

    setState(() {
      isScanning = false;
      _teacherDetectedAlready = false;
      _scannedToken = null;
    });
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message, {required bool isError}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? Colors.red.shade600 : const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
    );
  }

  // ============================================================
  // UI BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "Give Attendance",
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Color(0xFF1E293B),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: Color(0xFF1E293B),
          ),
          onPressed: () async {
            if (isScanning) {
              await cancelScanning();
            }
            if (context.mounted) {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            children: [
              // Course Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade700, Colors.blue.shade500],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.shade300.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.menu_book_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.courseName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "Course ID: ${widget.courseId}",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Animated / Visual State Indicator
              _buildStateIllustration(),

              const SizedBox(height: 24),

              // Status Title
              Text(
                _getStatusTitle(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),

              const SizedBox(height: 8),

              // Status Subtitle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _getStatusSubtitle(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
              ),

              const Spacer(),

              // Action Buttons
              if (isScanning) ...[
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade600,
                      side: BorderSide(color: Colors.red.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: cancelScanning,
                    child: const Text(
                      "Cancel Scan",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ] else if (attendanceCompleted) ...[
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.check_rounded, size: 22),
                    label: const Text(
                      "Done",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ] else if (!isAuthenticating) ...[
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: giveAttendance,
                    icon: const Icon(Icons.fingerprint_rounded, size: 24),
                    label: const Text(
                      "Start Verification",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              Text(
                "You must be within Bluetooth range of the instructor's device.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // STATUS HELPERS
  // ============================================================

  Widget _buildStateIllustration() {
    if (attendanceCompleted) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFA7F3D0), width: 3),
        ),
        child: const Icon(
          Icons.verified_rounded,
          size: 64,
          color: Color(0xFF059669),
        ),
      );
    }

    if (isAuthenticating) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.indigo.shade50,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.indigo.shade200, width: 3),
        ),
        child: Icon(
          Icons.fingerprint_rounded,
          size: 64,
          color: Colors.indigo.shade600,
        ),
      );
    }

    if (isScanning) {
      return Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 110,
            height: 110,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Colors.blue.shade600,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.bluetooth_searching_rounded,
              size: 44,
              color: Colors.blue.shade600,
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.bluetooth_rounded,
        size: 64,
        color: Colors.blue.shade600,
      ),
    );
  }

  String _getStatusTitle() {
    if (attendanceCompleted) {
      return "Attendance Recorded!";
    }
    if (isAuthenticating) {
      return "Instructor Device Found";
    }
    if (isScanning) {
      return "Scanning for Instructor...";
    }
    return "Ready to Mark Attendance";
  }

  String _getStatusSubtitle() {
    if (attendanceCompleted) {
      return "Your presence has been verified and saved.";
    }
    if (isAuthenticating) {
      return "Please authenticate using your device's biometrics.";
    }
    if (isScanning) {
      return "Looking for the instructor's active Bluetooth broadcast nearby.";
    }
    return "Make sure your Bluetooth is turned on and tap the button below to start.";
  }
}