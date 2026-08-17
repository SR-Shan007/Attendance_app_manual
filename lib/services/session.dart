import '../models/app_user.dart';
import '../models/attendance_session.dart';
import '../models/course.dart';

class Session {
  Session._();

  static final Session instance = Session._();

  // ============================================================
  // CURRENT USER
  // ============================================================

  AppUser? currentUser;

  // ============================================================
  // CURRENT COURSE
  // ============================================================

  Course? currentCourse;

  // ============================================================
  // CURRENT ATTENDANCE SESSION
  // ============================================================

  AttendanceSession? currentAttendanceSession;

  // ============================================================
  // CHECK LOGIN STATUS
  // ============================================================

  bool get isLoggedIn {
    return currentUser != null;
  }

  // ============================================================
  // CHECK ROLE
  // ============================================================

  bool get isStudent {
    return currentUser?.role == "Student";
  }

  bool get isTeacher {
    return currentUser?.role == "Teacher";
  }

  // ============================================================
  // CLEAR SESSION
  // ============================================================

  void clear() {
    currentUser = null;
    currentCourse = null;
    currentAttendanceSession = null;
  }
}