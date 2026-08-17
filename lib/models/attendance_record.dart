import 'package:cloud_firestore/cloud_firestore.dart';

/// Mutable model used specifically inside the manual attendance checklist UI
class StudentAttendanceItem {
  final String id; // Student's UID or custom student ID
  final String name;
  final String? studentCode; // E.g., University ID
  int totalAttendance;
  bool isPresent;

  StudentAttendanceItem({
    required this.id,
    required this.name,
    this.studentCode,
    required this.totalAttendance,
    this.isPresent = false,
  });
}

/// Persistent record model stored in Firestore under sessions/{sessionId}/records/{studentId}
class AttendanceRecord {
  final String studentId;
  final String studentName;
  final bool isPresent;
  final DateTime timestamp;

  AttendanceRecord({
    required this.studentId,
    required this.studentName,
    required this.isPresent,
    required this.timestamp,
  });

  factory AttendanceRecord.fromMap(Map<String, dynamic> map, String documentId) {
    return AttendanceRecord(
      studentId: documentId,
      studentName: map['studentName'] ?? 'Unknown',
      isPresent: map['isPresent'] ?? false,
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentName': studentName,
      'isPresent': isPresent,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}