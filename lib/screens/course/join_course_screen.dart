import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_service.dart';

class JoinCourseScreen extends StatefulWidget {
  const JoinCourseScreen({super.key});

  @override
  State<JoinCourseScreen> createState() => _JoinCourseScreenState();
}

class _JoinCourseScreenState extends State<JoinCourseScreen> {
  final _codeController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = false;

  Future<void> _join() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    final profile = await _firestoreService.getUserProfile(user.uid);

    if (profile != null) {
      final success = await _firestoreService.joinCourseWithCode(
        joinCode: _codeController.text.trim().toUpperCase(),
        student: profile,
      );

      if (mounted) {
        if (success) {
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid course code!')),
          );
        }
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join Course')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(labelText: 'Enter 6-Digit Join Code'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _join,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Join'),
            ),
          ],
        ),
      ),
    );
  }
}