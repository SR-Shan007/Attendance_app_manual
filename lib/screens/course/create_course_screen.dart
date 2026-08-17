import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import '../../models/course.dart';
import '../../services/firestore_service.dart';

class CreateCourseScreen extends StatefulWidget {
  const CreateCourseScreen({super.key});

  @override
  State<CreateCourseScreen> createState() => _CreateCourseScreenState();
}

class _CreateCourseScreenState extends State<CreateCourseScreen> {
  final _titleController = TextEditingController();
  final _codeController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = false;

  String _generateJoinCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random();
    return List.generate(6, (index) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<void> _createCourse() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    final courseId = DateTime.now().millisecondsSinceEpoch.toString();

    final course = Course(
      id: courseId,
      title: _titleController.text.trim(),
      code: _codeController.text.trim(),
      joinCode: _generateJoinCode(),
      teacherId: user.uid,
    );

    await _firestoreService.createCourse(course);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Course')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Course Title'),
            ),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(labelText: 'Course Code (e.g. CS101)'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _createCourse,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}