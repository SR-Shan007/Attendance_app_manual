import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../models/attendance_session.dart';
import '../../models/course.dart';
import '../../services/attendance_service.dart';
import '../../services/session.dart';
import '../../services/teacher_bluetooth_service.dart';

class TeacherTrackAttendancePage extends StatefulWidget {
  final String courseName;
  final String courseId;

  const TeacherTrackAttendancePage({
    super.key,
    required this.courseName,
    required this.courseId,
  });

  @override
  State<TeacherTrackAttendancePage> createState() =>
      _TeacherTrackAttendancePageState();
}

class _TeacherTrackAttendancePageState
    extends State<TeacherTrackAttendancePage> {
  final AttendanceService _attendanceService = AttendanceService();
  final TeacherBluetoothService _bluetoothService =
      TeacherBluetoothService.instance;

  AttendanceSession? _attendanceSession;

  bool isStarting = false;
  bool isEnding = false;

  bool get attendanceActive => _attendanceSession != null;

  @override
  void initState() {
    super.initState();
    _ensureCourseInitialized();
  }

  void _ensureCourseInitialized() {
    if (Session.instance.currentCourse == null ||
        Session.instance.currentCourse!.id != widget.courseId) {
      Session.instance.currentCourse = Course(
        id: widget.courseId,
        name: widget.courseName,
        joinCode: '',
        teacherId: Session.instance.currentUser?.id ?? '',
        teacherName: Session.instance.currentUser?.name ?? '',
        department: '',
        enrolledStudents: const [],
      );
    }
  }

  // ============================================================
  // START ATTENDANCE
  // ============================================================

  Future<void> startAttendance() async {
    if (isStarting || attendanceActive) return;

    setState(() {
      isStarting = true;
    });

    AttendanceSession? session;

    try {
      final permissionsGranted = await _requestBluetoothPermissions();

      if (!permissionsGranted) {
        throw Exception(
          "Bluetooth advertising and location permissions are required to start the session.",
        );
      }

      // Construct course matching exact model signature
      final courseParam = Course(
        id: widget.courseId,
        name: widget.courseName,
        joinCode: '',
        teacherId: Session.instance.currentUser?.id ?? '',
        teacherName: Session.instance.currentUser?.name ?? '',
        department: '',
        enrolledStudents: const [],
      );

      // Set session course state
      Session.instance.currentCourse = courseParam;

      // 1. Create backend attendance session passing explicit course
      session = await _attendanceService.startAttendance(
        courseParam: courseParam,
      );

      // 2. Start teacher Bluetooth broadcasting
      await _bluetoothService.startAdvertising(
        sessionId: session.id,
        sessionToken: session.sessionToken,
      );

      if (!mounted) return;

      setState(() {
        _attendanceSession = session;
        isStarting = false;
      });

      _showMessage("Attendance session started successfully.", isError: false);
    } catch (e) {
      if (session != null) {
        try {
          await _attendanceService.endAttendance();
        } catch (_) {}
      }

      if (!mounted) return;

      setState(() {
        isStarting = false;
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
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.locationWhenInUse,
    ].request();

    return statuses[Permission.bluetoothAdvertise]?.isGranted ?? false;
  }

  // ============================================================
  // END ATTENDANCE
  // ============================================================

  Future<void> endAttendance() async {
    if (isEnding || !attendanceActive) return;

    setState(() {
      isEnding = true;
    });

    Object? firstError;

    try {
      await _bluetoothService.stopAdvertising();
    } catch (e) {
      firstError = e;
    }

    try {
      await _attendanceService.endAttendance();
    } catch (e) {
      firstError ??= e;
    }

    if (!mounted) return;

    setState(() {
      _attendanceSession = null;
      isEnding = false;
    });

    if (firstError != null) {
      _showMessage(
        firstError.toString().replaceFirst("Exception: ", ""),
        isError: true,
      );
    } else {
      _showMessage("Attendance session has ended.", isError: false);
    }
  }

  // ============================================================
  // CONFIRM END ATTENDANCE DIALOG
  // ============================================================

  Future<bool> confirmEndAttendance() async {
    final shouldEnd = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            "End Attendance?",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Color(0xFF1E293B),
            ),
          ),
          content: const Text(
            "Students will no longer be able to submit attendance once this session is closed.",
            style: TextStyle(color: Color(0xFF64748B), height: 1.4),
          ),
          actionsPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                "Cancel",
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                "End Session",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (shouldEnd == true) {
      await endAttendance();
      return true;
    }
    return false;
  }

  // ============================================================
  // MESSAGE HELPER
  // ============================================================

  void _showMessage(String message, {required bool isError}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor:
        isError ? Colors.red.shade600 : const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Text(
          message,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // UI BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !attendanceActive,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldLeave = await confirmEndAttendance();
        if (shouldLeave && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text(
            "Track Attendance",
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
              if (attendanceActive) {
                final shouldLeave = await confirmEndAttendance();
                if (shouldLeave && context.mounted) {
                  Navigator.pop(context);
                }
              } else {
                Navigator.pop(context);
              }
            },
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Course Banner Card
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
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.school_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          widget.courseName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Status Summary Card
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: attendanceActive
                          ? const Color(0xFFA7F3D0)
                          : const Color(0xFFE2E8F0),
                      width: attendanceActive ? 1.5 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: attendanceActive
                              ? const Color(0xFFECFDF5)
                              : const Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          attendanceActive
                              ? Icons.bluetooth_connected_rounded
                              : Icons.bluetooth_disabled_rounded,
                          size: 38,
                          color: attendanceActive
                              ? const Color(0xFF059669)
                              : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        attendanceActive
                            ? "Broadcast is Active"
                            : "Broadcast Inactive",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        attendanceActive
                            ? "Students nearby can discover and mark their attendance."
                            : "Start the session to allow nearby students to submit attendance.",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),

                // Active Session Info Card
                if (attendanceActive && _attendanceSession != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Session Details",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          icon: Icons.tag_rounded,
                          label: "Session ID",
                          value: _attendanceSession!.id,
                        ),
                        const Divider(height: 20, color: Color(0xFFF1F5F9)),
                        _buildDetailRow(
                          icon: Icons.schedule_rounded,
                          label: "Started At",
                          value: _formatTime(_attendanceSession!.startTime),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 28),

                // Primary Action Button
                if (!attendanceActive)
                  SizedBox(
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
                      onPressed: isStarting ? null : startAttendance,
                      icon: isStarting
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Icon(Icons.play_arrow_rounded, size: 24),
                      label: Text(
                        isStarting
                            ? "Starting Broadcast..."
                            : "Start Attendance",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                if (attendanceActive) ...[
                  SizedBox(
                    height: 54,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: isEnding ? null : confirmEndAttendance,
                      icon: isEnding
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Icon(Icons.stop_rounded, size: 24),
                      label: Text(
                        isEnding
                            ? "Stopping Broadcast..."
                            : "End Attendance Session",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 20,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Keep Bluetooth and Location turned on. Ending the session will automatically stop discovery for all nearby students.",
                            style: TextStyle(
                              color: Colors.blue.shade900,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12
        ? time.hour - 12
        : time.hour == 0
        ? 12
        : time.hour;

    final minute = time.minute.toString().padLeft(2, "0");
    final period = time.hour >= 12 ? "PM" : "AM";

    return "$hour:$minute $period";
  }
}