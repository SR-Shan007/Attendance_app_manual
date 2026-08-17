import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';
import 'session.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================
  // DEVICE VERIFICATION HELPER
  // ============================================================

  Future<void> _registerActiveDevice(String uid) async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      String deviceId = 'unknown_device';

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? 'unknown_ios';
      }

      await _firestore.collection('users').doc(uid).set({
        'activeDeviceId': deviceId,
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Ignore device registration failure to prevent blocking auth flow
    }
  }

  // ============================================================
  // SIGN UP
  // ============================================================

  Future<void> signUp({
    required String id,
    required String name,
    required String email,
    required String password,
    required String role,
    String department = "",
    String semester = "",
    String year = "",
  }) async {
    final cleanId = id.trim();
    final cleanEmail = email.trim();
    final cleanName = name.trim();

    try {
      final existingUserQuery = await _firestore
          .collection("users")
          .where("id", isEqualTo: cleanId)
          .where("role", isEqualTo: role)
          .limit(1)
          .get();

      if (existingUserQuery.docs.isNotEmpty) {
        throw Exception(
          "An account with this $role ID ($cleanId) already exists.",
        );
      }

      final credential = await _auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );

      final firebaseUser = credential.user;

      if (firebaseUser == null) {
        throw Exception("Account creation failed.");
      }

      await firebaseUser.updateDisplayName(cleanName);

      final appUser = AppUser(
        uid: firebaseUser.uid,
        id: cleanId,
        name: cleanName,
        email: cleanEmail,
        role: role,
        department: department.trim(),
        semester: semester.trim(),
        year: year.trim(),
      );

      await _firestore
          .collection("users")
          .doc(firebaseUser.uid)
          .set(appUser.toMap());

      await _registerActiveDevice(firebaseUser.uid);

      Session.instance.currentUser = appUser;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case "email-already-in-use":
          throw Exception("This email is already in use by another account.");
        case "invalid-email":
          throw Exception("Invalid email address.");
        case "weak-password":
          throw Exception("Password is too weak. Use at least 6 characters.");
        case "operation-not-allowed":
          throw Exception("Email/password authentication is disabled.");
        default:
          throw Exception(e.message ?? "Unable to create account.");
      }
    } on FirebaseException catch (e) {
      throw Exception(e.message ?? "Could not save user profile.");
    } catch (e) {
      throw Exception(e.toString().replaceFirst("Exception: ", ""));
    }
  }

  // ============================================================
  // LOGIN WITH ID + PASSWORD
  // ============================================================

  Future<void> login({
    required String id,
    required String password,
    required String role,
  }) async {
    try {
      final query = await _firestore
          .collection("users")
          .where("id", isEqualTo: id.trim())
          .where("role", isEqualTo: role)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        throw Exception("No $role account found with this ID.");
      }

      final doc = query.docs.first;
      final userData = doc.data();

      final email = userData["email"];

      if (email == null || email.toString().isEmpty) {
        throw Exception("No email is associated with this account.");
      }

      final credential = await _auth.signInWithEmailAndPassword(
        email: email.toString(),
        password: password,
      );

      final firebaseUser = credential.user;

      if (firebaseUser == null) {
        throw Exception("Login failed.");
      }

      await _registerActiveDevice(firebaseUser.uid);

      final appUser = AppUser.fromFirestore(doc);
      Session.instance.currentUser = appUser;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case "invalid-credential":
        case "wrong-password":
        case "user-not-found":
          throw Exception("Invalid ID or password.");
        case "user-disabled":
          throw Exception("This account has been disabled.");
        case "too-many-requests":
          throw Exception("Too many login attempts. Try again later.");
        default:
          throw Exception(e.message ?? "Login failed.");
      }
    } on FirebaseException catch (e) {
      throw Exception(e.message ?? "Could not access user information.");
    } catch (e) {
      throw Exception(e.toString().replaceFirst("Exception: ", ""));
    }
  }

  // ============================================================
  // GET CURRENT USER
  // ============================================================

  Future<AppUser?> getCurrentUser() async {
    try {
      final firebaseUser = _auth.currentUser;

      if (firebaseUser == null) {
        return null;
      }

      final snapshot = await _firestore
          .collection("users")
          .doc(firebaseUser.uid)
          .get();

      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }

      await _registerActiveDevice(firebaseUser.uid);

      final user = AppUser.fromFirestore(snapshot);
      Session.instance.currentUser = user;
      return user;
    } catch (e) {
      return null;
    }
  }

  // ============================================================
  // UPDATE PROFILE & LOGOUT
  // ============================================================

  Future<void> updateProfile({
    required String name,
    required String department,
  }) async {
    final user = Session.instance.currentUser;

    if (user == null) {
      throw Exception("No logged in user.");
    }

    final updatedName = name.trim();
    final updatedDept = department.trim();

    await _firestore.collection("users").doc(user.uid).update({
      "name": updatedName,
      "department": updatedDept,
    });

    await _auth.currentUser?.updateDisplayName(updatedName);

    Session.instance.currentUser = user.copyWith(
      name: updatedName,
      department: updatedDept,
    );
  }

  Future<void> logout() async {
    await _auth.signOut();
    Session.instance.clear();
  }
}