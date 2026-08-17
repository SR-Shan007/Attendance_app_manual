import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import '../models/course.dart';
import '../models/attendance_session.dart';
import '../models/attendance_record.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- USER OPERATIONS ---

  /// Save or update user details in the users collection
  Future<void> createUserProfile(AppUser user) async {
    await _db.collection('users').doc(user.uid).set(user.toMap());
  }

  /// Get user details by UID
  Future<AppUser?> getUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return AppUser.fromMap(doc.data()!, doc.id);
  }

  // --- COURSE OPERATIONS ---

  /// Create a new course (Teacher action)
  Future<void> createCourse(Course course) async {
    await _db.collection('courses').doc(course.id).set(course.toMap());
  }

  /// Get stream of courses created by a specific teacher
  Stream<List<Course>> getTeacherCoursesStream(String teacherId) {
    return _db
        .collection('courses')
        .where('teacherId', isEqualTo: teacherId)
        .snapshots()
        .map((snap) =>
        snap.docs.map((doc) => Course.fromMap(doc.data(), doc.id)).toList());
  }

  /// Get stream of courses a student has joined
  Stream<List<Course>> getStudentCoursesStream(String studentId) {
    return _db
        .collectionGroup('enrolled_students')
        .where(FieldPath.documentId, isEqualTo: studentId)
        .snapshots()
        .asyncMap((snap) async {
      List<Course> courses = [];
      for (var doc in snap.docs) {
        final courseDoc = await doc.reference.parent.parent?.get();
        if (courseDoc != null && courseDoc.exists) {
          courses.add(Course.fromMap(courseDoc.data()!, courseDoc.id));
        }
      }
      return courses;
    });
  }

  /// Join a course using a Join Code (Student action)
  Future<bool> joinCourseWithCode({
    required String joinCode,
    required AppUser student,
  }) async {
    final querySnap = await _db
        .collection('courses')
        .where('joinCode', isEqualTo: joinCode.trim().toUpperCase())
        .get();

    if (querySnap.docs.isEmpty) return false;

    final courseDoc = querySnap.docs.first;

    // Add student to the enrolled_students subcollection
    await courseDoc.reference
        .collection('enrolled_students')
        .doc(student.uid)
        .set({
      'name': student.name,
      'studentCode': student.studentId ?? '',
      'totalAttendance': 0,
      'joinedAt': FieldValue.serverTimestamp(),
    });

    return true;
  }

  /// Fetch all enrolled students for a specific course
  Future<List<StudentAttendanceItem>> getEnrolledStudents(
      String courseId) async {
    final snap = await _db
        .collection('courses')
        .doc(courseId)
        .collection('enrolled_students')
        .get();

    return snap.docs.map((doc) {
      final data = doc.data();
      return StudentAttendanceItem(
        id: doc.id,
        name: data['name'] ?? 'Unknown',
        studentCode: data['studentCode'],
        totalAttendance: data['totalAttendance'] ?? 0,
      );
    }).toList();
  }

  // --- ATTENDANCE OPERATIONS ---

  /// Submit manual attendance for all students using a Batch Write
  Future<void> submitManualAttendance({
    required String courseId,
    required String teacherId,
    required List<StudentAttendanceItem> attendanceList,
  }) async {
    final batch = _db.batch();
    final now = DateTime.now();

    // 1. Create a new session document
    final sessionRef = _db
        .collection('courses')
        .doc(courseId)
        .collection('sessions')
        .doc();

    final session = AttendanceSession(
      id: sessionRef.id,
      courseId: courseId,
      createdBy: teacherId,
      date: now,
    );
    batch.set(sessionRef, session.toMap());

    // 2. Increment total sessions count on the course
    final courseRef = _db.collection('courses').doc(courseId);
    batch.update(courseRef, {'totalSessions': FieldValue.increment(1)});

    // 3. Write individual attendance records & update student total counters
    for (var student in attendanceList) {
      final recordRef = sessionRef.collection('records').doc(student.id);
      final record = AttendanceRecord(
        studentId: student.id,
        studentName: student.name,
        isPresent: student.isPresent,
        timestamp: now,
      );
      batch.set(recordRef, record.toMap());

      if (student.isPresent) {
        final studentRef = courseRef
            .collection('enrolled_students')
            .doc(student.id);

        batch.update(studentRef, {
          'totalAttendance': FieldValue.increment(1),
        });
      }
    }

    // Commit all changes atomically
    await batch.commit();
  }

  /// Get past attendance sessions for a course
  Stream<List<AttendanceSession>> getSessionsStream(String courseId) {
    return _db
        .collection('courses')
        .doc(courseId)
        .collection('sessions')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs
        .map((doc) => AttendanceSession.fromMap(doc.data(), doc.id))
        .toList());
  }

  /// Fetch individual student records for a given session
  Future<List<AttendanceRecord>> getSessionRecords({
    required String courseId,
    required String sessionId,
  }) async {
    final snap = await _db
        .collection('courses')
        .doc(courseId)
        .collection('sessions')
        .doc(sessionId)
        .collection('records')
        .get();

    return snap.docs
        .map((doc) => AttendanceRecord.fromMap(doc.data(), doc.id))
        .toList();
  }
}