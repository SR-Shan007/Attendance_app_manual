import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import '../course/join_course_screen.dart';

class StudentDashboardScreen extends StatelessWidget {
  final AppUser userProfile;

  const StudentDashboardScreen({super.key, required this.userProfile});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return Scaffold(
      appBar: AppBar(
        title: Text('${userProfile.name} (Student)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authService.signOut();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collectionGroup('enrolled_students')
            .where(FieldPath.documentId, isEqualTo: userProfile.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('You are not enrolled in any courses yet.'),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final parentCourseRef = docs[index].reference.parent.parent;

              return FutureBuilder<DocumentSnapshot>(
                future: parentCourseRef?.get(),
                builder: (context, courseSnapshot) {
                  if (!courseSnapshot.hasData) {
                    return const SizedBox();
                  }

                  final courseData =
                      courseSnapshot.data?.data() as Map<String, dynamic>? ?? {};

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: ListTile(
                      title: Text(
                        courseData['title'] ?? 'Course',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('Code: ${courseData['code'] ?? 'N/A'}'),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Attended: ${data['totalAttendance'] ?? 0}',
                          style: TextStyle(
                            color: Colors.blue.shade900,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const JoinCourseScreen()),
          );
        },
        icon: const Icon(Icons.group_add),
        label: const Text('Join Course'),
      ),
    );
  }
}