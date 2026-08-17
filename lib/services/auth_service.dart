import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Stream to listen for real-time authentication state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Get current Firebase Auth user
  User? get currentUser => _auth.currentUser;

  /// Register a new user with Email, Password, Name, and Role
  Future<AppUser?> signUp({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? studentId,
  }) async {
    try {
      // 1. Create account in Firebase Auth
      final UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final User? firebaseUser = credential.user;
      if (firebaseUser == null) return null;

      // 2. Build AppUser object
      final AppUser userProfile = AppUser(
        uid: firebaseUser.uid,
        name: name.trim(),
        email: email.trim(),
        role: role,
        studentId: studentId?.trim(),
      );

      // 3. Save user record to Firestore 'users' collection
      await _db.collection('users').doc(firebaseUser.uid).set(userProfile.toMap());

      return userProfile;
    } catch (e) {
      rethrow;
    }
  }

  /// Sign in existing user with Email and Password
  Future<AppUser?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final User? firebaseUser = credential.user;
      if (firebaseUser == null) return null;

      // Fetch user profile data from Firestore
      return await getUserProfile(firebaseUser.uid);
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch AppUser profile from Firestore by UID
  Future<AppUser?> getUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return AppUser.fromMap(doc.data()!, doc.id);
  }

  /// Sign out current user
  Future<void> signOut() async {
    await _auth.signOut();
  }
}