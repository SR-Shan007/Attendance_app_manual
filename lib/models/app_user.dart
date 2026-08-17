enum UserRole { student, teacher }

class AppUser {
  final String uid;
  final String name;
  final String email;
  final UserRole role;
  final String? studentId; // Optional university/student ID code

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.studentId,
  });

  // Create an AppUser from a Firestore document snapshot
  factory AppUser.fromMap(Map<String, dynamic> map, String documentId) {
    return AppUser(
      uid: documentId,
      name: map['name'] ?? 'Unknown',
      email: map['email'] ?? '',
      role: map['role'] == 'teacher' ? UserRole.teacher : UserRole.student,
      studentId: map['studentId'],
    );
  }

  // Convert an AppUser to a Map for Firestore
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'email': email,
      'role': role.name, // Saves as 'student' or 'teacher'
    };

    if (studentId != null && studentId!.isNotEmpty) {
      map['studentId'] = studentId;
    }

    return map;
  }
}