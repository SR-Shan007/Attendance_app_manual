import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import '../course/create_course_screen.dart';
import '../attendance/take_attendance_screen.dart';

class TeacherDashboardScreen extends StatelessWidget {
  final AppUser userProfile;

  const TeacherDashboardScreen({super.key, required this.userProfile});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return Scaffold(
      appBar: AppBar(
        title: Text('${userProfile.name} (Teacher)'),
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
            .collection('courses')
            .where('teacherId', isEqualTo: userProfile.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No courses created yet. Tap + to create one.'),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final courseId = docs[index].id;
              final title = data['title'] ?? 'Untitled Course';
              final code = data['code'] ?? '';
              final joinCode = data['joinCode'] ?? '';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Code: $code | Join Code: $joinCode'),
                  trailing: const Icon(Icons.edit_note, color: Colors.blue),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TakeAttendanceScreen(
                          courseId: courseId,
                          courseTitle: title,
                          courseCode: code,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateCourseScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Create Course'),
      ),
    );
  }
}