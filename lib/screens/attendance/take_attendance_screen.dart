import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/attendance_record.dart';
import '../../services/firestore_service.dart';
import '../../services/pdf_export_service.dart';

class TakeAttendanceScreen extends StatefulWidget {
  final String courseId;
  final String courseTitle;
  final String courseCode;

  const TakeAttendanceScreen({
    super.key,
    required this.courseId,
    required this.courseTitle,
    required this.courseCode,
  });

  @override
  State<TakeAttendanceScreen> createState() => _TakeAttendanceScreenState();
}

class _TakeAttendanceScreenState extends State<TakeAttendanceScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  List<StudentAttendanceItem> _students = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    try {
      final list = await _firestoreService.getEnrolledStudents(widget.courseId);
      setState(() {
        _students = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load students: $e')),
        );
      }
    }
  }

  Future<void> _submitAttendance() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() => _isSubmitting = true);

    try {
      await _firestoreService.submitManualAttendance(
        courseId: widget.courseId,
        teacherId: currentUser.uid,
        attendanceList: _students,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance submitted successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting attendance: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _downloadPdfReport() {
    if (_students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No student records available to export.')),
      );
      return;
    }

    PdfExportService.exportAttendanceReport(
      courseTitle: widget.courseTitle,
      courseCode: widget.courseCode,
      students: _students,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Take Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export PDF',
            onPressed: _downloadPdfReport,
          ),
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Mark All Present',
            onPressed: () {
              setState(() {
                for (var s in _students) {
                  s.isPresent = true;
                }
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _students.isEmpty
          ? const Center(child: Text('No enrolled students found.'))
          : ListView.separated(
        itemCount: _students.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final student = _students[index];
          return SwitchListTile(
            title: Text(student.name),
            subtitle: Text(
              'ID: ${student.studentCode ?? student.id} | Total: ${student.totalAttendance}',
            ),
            value: student.isPresent,
            activeColor: Colors.green,
            onChanged: (bool value) {
              setState(() {
                student.isPresent = value;
              });
            },
          );
        },
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
          ),
          onPressed: (_isSubmitting || _students.isEmpty) ? null : _submitAttendance,
          child: _isSubmitting
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text(
            'Submit Attendance',
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}