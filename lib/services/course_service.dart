import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/course.dart';
import 'session.dart';

class CourseService {
  static final CourseService _instance = CourseService._internal();
  factory CourseService() => _instance;
  CourseService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Course? _selectedCourse;
  Course? get selectedCourse => _selectedCourse;

  void selectCourse(Course course) {
    _selectedCourse = course;
  }

  void clearSelectedCourse() {
    _selectedCourse = null;
  }

  // ==========================================
  // STREAMS FOR DASHBOARDS
  // ==========================================

  Stream<List<Course>> teacherCourses() {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('courses')
        .where('teacherId', isEqualTo: authUser.uid)
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => Course.fromFirestore(doc)).toList());
  }

  Stream<List<Course>> studentCourses() {
    final user = Session.instance.currentUser;
    final authUser = _auth.currentUser;

    // We check both custom user ID and Auth UID to support whichever format you store
    final studentId = user?.id ?? authUser?.uid;
    if (studentId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('courses')
        .where('enrolledStudents', arrayContains: studentId)
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => Course.fromFirestore(doc)).toList());
  }

  // ==========================================
  // ACTIONS
  // ==========================================

  Future<String> createCourse({
    required String courseName,
    required String courseCode,
    String? department,
  }) async {
    final authUser = _auth.currentUser;
    final sessionUser = Session.instance.currentUser;

    if (authUser == null) {
      throw Exception("User session not found. Please log in again.");
    }

    final cleanCode = courseCode.trim().toUpperCase();
    final cleanName = courseName.trim();

    // 1. Check duplicate course using authUser.uid
    final existing = await _firestore
        .collection('courses')
        .where('joinCode', isEqualTo: cleanCode)
        .where('teacherId', isEqualTo: authUser.uid)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception("You already created a course with code '$cleanCode'.");
    }

    final docRef = _firestore.collection('courses').doc();

    // 2. Prepare the map matching Security Rules expectations
    final courseMap = {
      'courseName': cleanName,
      'joinCode': cleanCode,
      'courseCode': cleanCode,
      'department': department?.trim() ?? sessionUser?.department ?? '',
      'teacherId': authUser.uid, // <-- CRITICAL: Uses Firebase Auth UID to satisfy request.auth.uid rule
      'teacherCustomId': sessionUser?.id ?? '', // Optional: Keep custom teacher ID if needed
      'teacherName': sessionUser?.name ?? '',
      'enrolledStudents': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
    };

    await docRef.set(courseMap);

    return docRef.id;
  }

  Future<void> joinCourse(String courseCode) async {
    final user = Session.instance.currentUser;
    final authUser = _auth.currentUser;

    if (authUser == null) {
      throw Exception("User session not found. Please log in again.");
    }

    final cleanCode = courseCode.trim().toUpperCase();

    var query = await _firestore
        .collection('courses')
        .where('joinCode', isEqualTo: cleanCode)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      query = await _firestore
          .collection('courses')
          .where('courseCode', isEqualTo: cleanCode)
          .limit(1)
          .get();
    }

    if (query.docs.isEmpty) {
      throw Exception("No course found with code '$cleanCode'.");
    }

    final docRef = query.docs.first.reference;

    // Use session ID or auth UID depending on how you index enrolled students
    final studentIdentifier = user?.id ?? authUser.uid;

    await docRef.update({
      'enrolledStudents': FieldValue.arrayUnion([studentIdentifier]),
    });
  }
}