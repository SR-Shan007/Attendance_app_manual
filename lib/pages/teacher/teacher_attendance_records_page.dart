import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TeacherAttendanceRecordPage extends StatefulWidget {
  final String courseName;
  final String courseId;

  const TeacherAttendanceRecordPage({
    super.key,
    required this.courseName,
    required this.courseId,
  });

  @override
  State<TeacherAttendanceRecordPage> createState() =>
      _TeacherAttendanceRecordPageState();
}

class _TeacherAttendanceRecordPageState
    extends State<TeacherAttendanceRecordPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late DateTime _selectedDate;
  late List<DateTime> _last7Days;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _generateDateStrip();
  }

  void _generateDateStrip() {
    _last7Days = List.generate(
      7,
          (index) => _selectedDate.subtract(Duration(days: 6 - index)),
    );
  }

  String _formatDateDocId(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  CollectionReference<Map<String, dynamic>> _recordsRef(DateTime date) {
    return _firestore
        .collection('courses')
        .doc(widget.courseId)
        .collection('sessions')
        .doc(_formatDateDocId(date))
        .collection('records');
  }

  Future<void> _toggleAttendance(
      String studentUid,
      bool currentStatus,
      ) async {
    final newStatus = !currentStatus;

    try {
      await _recordsRef(_selectedDate).doc(studentUid).set({
        'isPresent': newStatus,
        'checkInTime': newStatus ? Timestamp.now() : null,
      }, SetOptions(merge: true));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to update status: ${e.toString()}"),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  Future<void> _pickCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null && !DateUtils.isSameDay(picked, _selectedDate)) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
        _generateDateStrip();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "Attendance Records",
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Color(0xFF1E293B),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: Color(0xFF1E293B),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month, color: Color(0xFF1E293B)),
            onPressed: _pickCustomDate,
            tooltip: "Select Date",
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Styled Course Name Card matching the Student View
            Padding(
              padding: const EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: 8,
              ),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.blue.shade100,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.menu_book_rounded,
                        color: Colors.blue.shade700,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        widget.courseName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Horizontal Date Strip
            Container(
              height: 72,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _last7Days.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final date = _last7Days[index];
                  final isSelected = DateUtils.isSameDay(date, _selectedDate);
                  final isToday = DateUtils.isSameDay(date, DateTime.now());

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDate = date;
                      });
                    },
                    child: Container(
                      width: 58,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.blue.shade600
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? Colors.blue.shade600
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isToday ? "Today" : DateFormat('EEE').format(date),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('dd').format(date),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            // Real-time Records View
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                key: ValueKey(_selectedDate.toIso8601String()),
                stream: _recordsRef(_selectedDate).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          "Error loading records: ${snapshot.error}",
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFFDC2626)),
                        ),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Text(
                        "No records found for ${DateFormat('MMM dd, yyyy').format(_selectedDate)}",
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                        ),
                      ),
                    );
                  }

                  final docs = snapshot.data!.docs;

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data();

                      final name = data['name'] as String? ?? 'Unknown';
                      final studentId = data['studentIdNumber']?.toString() ??
                          data['id']?.toString();
                      final isPresent = data['isPresent'] as bool? ?? false;
                      final checkInTimestamp = data['checkInTime'] as Timestamp?;

                      final timeStr = checkInTimestamp != null
                          ? DateFormat('hh:mm a').format(checkInTimestamp.toDate())
                          : "Not Checked In";

                      final subtitleText = (studentId != null && studentId.isNotEmpty)
                          ? "ID: $studentId • $timeStr"
                          : timeStr;

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: const Color(0xFFF1F5F9),
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : "?",
                                style: const TextStyle(
                                  color: Color(0xFF1E293B),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitleText,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                isPresent
                                    ? Icons.check_circle_rounded
                                    : Icons.cancel_rounded,
                                color: isPresent
                                    ? const Color(0xFF059669)
                                    : const Color(0xFFDC2626),
                                size: 28,
                              ),
                              onPressed: () => _toggleAttendance(
                                doc.id,
                                isPresent,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}