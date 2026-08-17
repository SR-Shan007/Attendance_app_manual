import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceSession {
  final String id;
  final String courseId;
  final String courseName;
  final String teacherId;
  final String teacherName;
  final DateTime startTime;
  final DateTime? endTime;
  final bool isActive;
  final String sessionToken;

  const AttendanceSession({
    required this.id,
    required this.courseId,
    required this.courseName,
    required this.teacherId,
    required this.teacherName,
    required this.startTime,
    this.endTime,
    required this.isActive,
    required this.sessionToken,
  });

  factory AttendanceSession.fromFirestore(DocumentSnapshot doc) {
    final map = (doc.data() as Map<String, dynamic>?) ?? {};
    return AttendanceSession(
      id: doc.id,
      courseId: map["courseId"] ?? "",
      courseName: map["courseName"] ?? "",
      teacherId: map["teacherId"] ?? "",
      teacherName: map["teacherName"] ?? "",
      startTime: _parseDateTime(map["startTime"]),
      endTime: map["endTime"] != null ? _parseDateTime(map["endTime"]) : null,
      isActive: map["isActive"] ?? false,
      sessionToken: map["sessionToken"] ?? "",
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "courseId": courseId,
      "courseName": courseName,
      "teacherId": teacherId,
      "teacherName": teacherName,
      "startTime": Timestamp.fromDate(startTime),
      "endTime": endTime != null ? Timestamp.fromDate(endTime!) : null,
      "isActive": isActive,
      "sessionToken": sessionToken,
    };
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}