import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../models/attendance_record.dart';
import '../models/attendance_session.dart';
import '../models/course.dart';
import 'session.dart';

class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _formatDateDocId(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  // ============================================================
  // DEVICE VERIFICATION HELPER
  // ============================================================

  Future<String> _getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? 'unknown_ios';
    }
    return 'unknown_device';
  }

  // ============================================================
  // START ATTENDANCE
  // ============================================================

  Future<AttendanceSession> startAttendance({Course? courseParam}) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw Exception("User is not authenticated. Please log in again.");
    }

    final teacher = Session.instance.currentUser;
    if (teacher == null) {
      throw Exception("Teacher profile not loaded. Please re-login.");
    }

    final course = courseParam ?? Session.instance.currentCourse;
    if (course == null) {
      throw Exception("No course selected. Please select a course first.");
    }

    final existing = await getActiveSession(course.id);
    if (existing != null && existing.sessionToken.isNotEmpty) {
      return existing;
    }

    final dateDocId = _formatDateDocId(DateTime.now());
    final sessionRef = _firestore
        .collection("courses")
        .doc(course.id)
        .collection("sessions")
        .doc(dateDocId);

    final sessionToken = _generateToken();

    final session = AttendanceSession(
      id: sessionRef.id,
      courseId: course.id,
      courseName: course.name,
      teacherId: authUser.uid,
      teacherName: teacher.name,
      startTime: DateTime.now(),
      isActive: true,
      sessionToken: sessionToken,
    );

    await sessionRef.set(session.toMap(), SetOptions(merge: true));

    await _firestore.collection("courses").doc(course.id).update({
      "attendanceActive": true,
    });

    Session.instance.currentAttendanceSession = session;
    Session.instance.currentCourse = course;

    return session;
  }

  String _generateToken() {
    final rand = Random.secure();
    return List.generate(6, (_) => rand.nextInt(10)).join();
  }

  // ============================================================
  // END ATTENDANCE
  // ============================================================

  Future<void> endAttendance() async {
    final session = Session.instance.currentAttendanceSession;
    if (session == null) return;

    final dateDocId = _formatDateDocId(DateTime.now());

    await _firestore
        .collection("courses")
        .doc(session.courseId)
        .collection("sessions")
        .doc(dateDocId)
        .set({
      "isActive": false,
      "endTime": Timestamp.fromDate(DateTime.now()),
    }, SetOptions(merge: true));

    await _firestore.collection("courses").doc(session.courseId).update({
      "attendanceActive": false,
    });

    Session.instance.currentAttendanceSession = null;
  }

  // ============================================================
  // GET ACTIVE ATTENDANCE SESSION
  // ============================================================

  Future<AttendanceSession?> getActiveSession(String courseId) async {
    final dateDocId = _formatDateDocId(DateTime.now());
    final docSnapshot = await _firestore
        .collection("courses")
        .doc(courseId)
        .collection("sessions")
        .doc(dateDocId)
        .get();

    if (!docSnapshot.exists) return null;

    final data = docSnapshot.data();
    if (data == null || data['isActive'] != true) return null;

    final session = AttendanceSession.fromFirestore(docSnapshot);
    Session.instance.currentAttendanceSession = session;
    return session;
  }

  // ============================================================
  // GIVE ATTENDANCE
  // ============================================================

  Future<void> giveAttendance({required String scannedToken}) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw Exception("User is not authenticated. Please log in again.");
    }

    // --- SINGLE ACTIVE DEVICE CHECK ---
    final currentDeviceId = await _getDeviceId();
    final userDoc = await _firestore.collection('users').doc(authUser.uid).get();
    final storedDeviceId = userDoc.data()?['activeDeviceId'];

    if (storedDeviceId != null && storedDeviceId != currentDeviceId) {
      throw Exception(
        "This account was logged in on another device. Please log in again on this phone.",
      );
    }
    // ----------------------------------

    final student = Session.instance.currentUser;
    if (student == null) {
      throw Exception("Student profile not loaded. Please re-login.");
    }

    final session = Session.instance.currentAttendanceSession;
    if (session == null) {
      throw Exception("No active attendance session.");
    }
    if (!session.isActive) {
      throw Exception("This attendance session has ended.");
    }
    if (scannedToken != session.sessionToken) {
      throw Exception("Could not verify proximity to teacher's device.");
    }

    final dateDocId = _formatDateDocId(DateTime.now());
    final recordRef = _firestore
        .collection("courses")
        .doc(session.courseId)
        .collection("sessions")
        .doc(dateDocId)
        .collection("records")
        .doc(authUser.uid);

    await _firestore.runTransaction((txn) async {
      final existing = await txn.get(recordRef);
      if (existing.exists && (existing.data()?['isPresent'] == true)) {
        throw Exception("Attendance already submitted for this session.");
      }

      txn.set(
        recordRef,
        {
          'name': student.name,
          'studentIdNumber': student.id,
          'department': student.department,
          'semester': student.semester,
          'year': student.year,
          'isPresent': true,
          'checkInTime': FieldValue.serverTimestamp(),
          'studentUid': authUser.uid,
          'courseId': session.courseId,
          'sessionId': dateDocId,
        },
        SetOptions(merge: true),
      );
    });
  }

  // ============================================================
  // STUDENT ATTENDANCE HISTORY
  // ============================================================

  Stream<List<AttendanceRecord>> studentAttendance() {
    final authUser = _auth.currentUser;
    if (authUser == null) return Stream.value([]);

    return _firestore
        .collectionGroup("records")
        .where("studentUid", isEqualTo: authUser.uid)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => AttendanceRecord.fromFirestore(doc))
        .toList());
  }

  // ============================================================
  // COURSE ATTENDANCE
  // ============================================================

  Stream<List<AttendanceRecord>> courseAttendance(String courseId) {
    return _firestore
        .collectionGroup("records")
        .where("courseId", isEqualTo: courseId)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => AttendanceRecord.fromFirestore(doc))
        .toList());
  }
}