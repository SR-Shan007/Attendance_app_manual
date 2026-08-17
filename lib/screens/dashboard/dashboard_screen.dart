import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/app_user.dart';
import '../../services/firestore_service.dart';
import 'teacher_dashboard_screen.dart';
import 'student_dashboard_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  AppUser? _userProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final profile = await _firestoreService.getUserProfile(user.uid);
      setState(() {
        _userProfile = profile;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_userProfile == null) {
      return const Scaffold(
        body: Center(child: Text('Failed to load user profile.')),
      );
    }

    // Render corresponding screen based on UserRole
    if (_userProfile!.role == UserRole.teacher) {
      return TeacherDashboardScreen(userProfile: _userProfile!);
    } else {
      return StudentDashboardScreen(userProfile: _userProfile!);
    }
  }
}