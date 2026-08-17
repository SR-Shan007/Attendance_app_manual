import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceSession {
  final String id;
  final String courseId;
  final String createdBy;
  final DateTime date;

  AttendanceSession({
    required this.id,
    required this.courseId,
    required this.createdBy,
    required this.date,
  });

  // Create an AttendanceSession object from Firestore data
  factory AttendanceSession.fromMap(Map<String, dynamic> map, String documentId) {
    return AttendanceSession(
      id: documentId,
      courseId: map['courseId'] ?? '',
      createdBy: map['createdBy'] ?? '',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Convert an AttendanceSession to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'courseId': courseId,
      'createdBy': createdBy,
      'date': Timestamp.fromDate(date),
    };
  }
}