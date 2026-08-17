class Course {
  final String id;
  final String title;
  final String code;
  final String joinCode;
  final String teacherId;
  final int totalSessions; // Total number of attendance sessions held so far

  Course({
    required this.id,
    required this.title,
    required this.code,
    required this.joinCode,
    required this.teacherId,
    this.totalSessions = 0,
  });

  // Create a Course object from a Firestore document snapshot
  factory Course.fromMap(Map<String, dynamic> map, String documentId) {
    return Course(
      id: documentId,
      title: map['title'] ?? '',
      code: map['code'] ?? '',
      joinCode: map['joinCode'] ?? '',
      teacherId: map['teacherId'] ?? '',
      totalSessions: map['totalSessions'] ?? 0,
    );
  }

  // Convert a Course object to a Map for saving to Firestore
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'code': code,
      'joinCode': joinCode,
      'teacherId': teacherId,
      'totalSessions': totalSessions,
    };
  }
}