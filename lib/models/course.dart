import 'package:cloud_firestore/cloud_firestore.dart';

class Course {
  final String id;
  final String name;
  final String joinCode;
  final String teacherId;
  final String teacherName;
  final String department;
  final List<String> enrolledStudents;
  final DateTime? createdAt;

  Course({
    required this.id,
    required this.name,
    required this.joinCode,
    required this.teacherId,
    required this.teacherName,
    this.department = '',
    this.enrolledStudents = const [],
    this.createdAt,
  });

  factory Course.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return Course(
      id: doc.id,
      name: data['courseName'] ?? data['name'] ?? '',
      joinCode: data['joinCode'] ?? data['courseCode'] ?? '',
      teacherId: data['teacherId'] ?? '',
      teacherName: data['teacherName'] ?? '',
      department: data['department'] ?? '',
      enrolledStudents: List<String>.from(data['enrolledStudents'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'courseName': name,
      'joinCode': joinCode,
      'courseCode': joinCode,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'department': department,
      'enrolledStudents': enrolledStudents,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}