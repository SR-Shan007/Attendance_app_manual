import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceRecord {
  final String id;
  final String sessionId;
  final String courseId;
  final String courseName;
  final String studentId;
  final String studentUid;
  final String studentName;
  final DateTime timestamp;

  const AttendanceRecord({
    required this.id,
    required this.sessionId,
    required this.courseId,
    required this.courseName,
    required this.studentId,
    required this.studentUid,
    required this.studentName,
    required this.timestamp,
  });

  factory AttendanceRecord.fromFirestore(DocumentSnapshot doc) {
    final map = (doc.data() as Map<String, dynamic>?) ?? {};
    return AttendanceRecord(
      id: doc.id,
      sessionId: map["sessionId"] ?? "",
      courseId: map["courseId"] ?? "",
      courseName: map["courseName"] ?? "",
      studentId: map["studentId"] ?? "",
      studentUid: map["studentUid"] ?? "",
      studentName: map["studentName"] ?? "",
      timestamp: _parseDateTime(map["timestamp"]),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "sessionId": sessionId,
      "courseId": courseId,
      "courseName": courseName,
      "studentId": studentId,
      "studentUid": studentUid,
      "studentName": studentName,
      "timestamp": Timestamp.fromDate(timestamp),
    };
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}