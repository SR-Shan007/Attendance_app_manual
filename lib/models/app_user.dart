import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String id;
  final String name;
  final String email;
  final String role;
  final String department;
  final String semester;
  final String year;

  const AppUser({
    required this.uid,
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.department = "",
    this.semester = "",
    this.year = "",
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final map = (doc.data() as Map<String, dynamic>?) ?? {};
    return AppUser(
      uid: doc.id, // Primary key is Document ID (Auth UID)
      id: map["id"] ?? "",
      name: map["name"] ?? "",
      email: map["email"] ?? "",
      role: map["role"] ?? "student",
      department: map["department"] ?? "",
      semester: map["semester"] ?? "",
      year: map["year"] ?? "",
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "uid": uid,
      "id": id,
      "name": name,
      "email": email,
      "role": role,
      "department": department,
      "semester": semester,
      "year": year,
    };
  }

  AppUser copyWith({
    String? uid,
    String? id,
    String? name,
    String? email,
    String? role,
    String? department,
    String? semester,
    String? year,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      department: department ?? this.department,
      semester: semester ?? this.semester,
      year: year ?? this.year,
    );
  }
}