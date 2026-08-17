import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _idController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _nameFocusNode = FocusNode();
  final _idFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();

  String selectedRole = "Student";
  String? selectedDepartment = "Software Engineering";
  String? selectedSemester;
  String? selectedYear;

  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  final List<String> _departments = ["Software Engineering"];
  final List<String> _semesters = ["1", "2"];
  final List<String> _years = ["1", "2", "3", "4"];

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    _nameFocusNode.dispose();
    _idFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  Future<void> signUp() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    if (selectedRole == "Student" &&
        (selectedSemester == null || selectedYear == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select both Semester and Year."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (selectedDepartment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a Department."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // 1. Create Auth user FIRST to satisfy Firestore security rules
      UserCredential userCredential =
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final String? uid = userCredential.user?.uid;

      if (uid != null) {
        // 2. Write document to Firestore using the generated UID
        Map<String, dynamic> userData = {
          'uid': uid,
          'name': _nameController.text.trim(),
          'id': _idController.text.trim(),
          'email': _emailController.text.trim(),
          'department': selectedDepartment,
          'role': selectedRole,
          'createdAt': FieldValue.serverTimestamp(),
        };

        if (selectedRole == "Student") {
          userData['semester'] = selectedSemester;
          userData['year'] = selectedYear;
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set(userData);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Account created successfully!"),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      _showErrorSnackBar(e.message ?? "Authentication failed.");
    } on FirebaseException catch (e) {
      _showErrorSnackBar(e.message ?? "Database operation failed.");
    } catch (e) {
      _showErrorSnackBar("An error occurred: $e");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFDC2626),
      ),
    );
  }

  OutlineInputBorder _buildBorder({Color? color, double width = 1.0}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: color != null
          ? BorderSide(color: color, width: width)
          : BorderSide.none,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade50,
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Card(
                  elevation: 2,
                  shadowColor: Colors.black12,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            "Create Account",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 28),

                          // --- Role Selection Toggle ---
                          LayoutBuilder(
                            builder: (context, constraints) {
                              const trackPadding = 4.0;
                              final segmentWidth =
                                  (constraints.maxWidth - trackPadding * 2) / 2;

                              return Container(
                                height: 46,
                                padding: const EdgeInsets.all(trackPadding),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Stack(
                                  children: [
                                    AnimatedAlign(
                                      duration:
                                      const Duration(milliseconds: 800),
                                      curve: Curves.easeInOutCubicEmphasized,
                                      alignment: selectedRole == "Student"
                                          ? Alignment.centerLeft
                                          : Alignment.centerRight,
                                      child: Container(
                                        width: segmentWidth,
                                        height: double.infinity,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                          BorderRadius.circular(10),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.08),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _RolePillOption(
                                            label: "Student",
                                            isSelected:
                                            selectedRole == "Student",
                                            onTap: () {
                                              setState(() {
                                                selectedRole = "Student";
                                              });
                                            },
                                          ),
                                        ),
                                        Expanded(
                                          child: _RolePillOption(
                                            label: "Teacher",
                                            isSelected:
                                            selectedRole == "Teacher",
                                            onTap: () {
                                              setState(() {
                                                selectedRole = "Teacher";
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 24),

                          // --- Full Name ---
                          TextFormField(
                            controller: _nameController,
                            focusNode: _nameFocusNode,
                            enabled: !isLoading,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) =>
                                FocusScope.of(context).requestFocus(_idFocusNode),
                            decoration: InputDecoration(
                              labelText: "Full Name",
                              labelStyle: TextStyle(color: Colors.grey.shade600),
                              floatingLabelStyle:
                              TextStyle(color: Colors.blue.shade600),
                              prefixIcon: Icon(Icons.person_outline,
                                  color: Colors.grey.shade500),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: _buildBorder(),
                              enabledBorder:
                              _buildBorder(color: Colors.grey.shade200),
                              focusedBorder: _buildBorder(
                                  color: Colors.blue.shade600, width: 1.5),
                            ),
                            validator: (val) => val == null || val.trim().isEmpty
                                ? "Full name is required"
                                : null,
                          ),
                          const SizedBox(height: 18),

                          // --- ID Field ---
                          TextFormField(
                            controller: _idController,
                            focusNode: _idFocusNode,
                            enabled: !isLoading,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) => FocusScope.of(context)
                                .requestFocus(_emailFocusNode),
                            decoration: InputDecoration(
                              labelText: selectedRole == "Student"
                                  ? "Student ID"
                                  : "Teacher ID",
                              labelStyle: TextStyle(color: Colors.grey.shade600),
                              floatingLabelStyle:
                              TextStyle(color: Colors.blue.shade600),
                              prefixIcon: Icon(Icons.badge_outlined,
                                  color: Colors.grey.shade500),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: _buildBorder(),
                              enabledBorder:
                              _buildBorder(color: Colors.grey.shade200),
                              focusedBorder: _buildBorder(
                                  color: Colors.blue.shade600, width: 1.5),
                            ),
                            validator: (val) => val == null || val.trim().isEmpty
                                ? "ID is required"
                                : null,
                          ),
                          const SizedBox(height: 18),

                          // --- Department Dropdown (Both Student & Teacher) ---
                          DropdownButtonFormField<String>(
                            value: selectedDepartment,
                            items: _departments.map((dept) {
                              return DropdownMenuItem<String>(
                                value: dept,
                                child: Text(dept),
                              );
                            }).toList(),
                            onChanged: isLoading
                                ? null
                                : (value) {
                              setState(() {
                                selectedDepartment = value;
                              });
                            },
                            decoration: InputDecoration(
                              labelText: "Department",
                              labelStyle: TextStyle(color: Colors.grey.shade600),
                              floatingLabelStyle:
                              TextStyle(color: Colors.blue.shade600),
                              prefixIcon: Icon(Icons.business_outlined,
                                  color: Colors.grey.shade500),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: _buildBorder(),
                              enabledBorder:
                              _buildBorder(color: Colors.grey.shade200),
                              focusedBorder: _buildBorder(
                                  color: Colors.blue.shade600, width: 1.5),
                            ),
                            validator: (val) => val == null || val.isEmpty
                                ? "Please select department"
                                : null,
                          ),
                          const SizedBox(height: 18),

                          // --- Student Only Dropdowns (Semester & Year in Separate Rows) ---
                          if (selectedRole == "Student") ...[
                            DropdownButtonFormField<String>(
                              value: selectedSemester,
                              items: _semesters.map((sem) {
                                return DropdownMenuItem<String>(
                                  value: sem,
                                  child: Text(sem),
                                );
                              }).toList(),
                              onChanged: isLoading
                                  ? null
                                  : (value) {
                                setState(() {
                                  selectedSemester = value;
                                });
                              },
                              decoration: InputDecoration(
                                labelText: "Semester",
                                labelStyle:
                                TextStyle(color: Colors.grey.shade600),
                                floatingLabelStyle:
                                TextStyle(color: Colors.blue.shade600),
                                prefixIcon: Icon(
                                    Icons.calendar_view_day_outlined,
                                    color: Colors.grey.shade500),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: _buildBorder(),
                                enabledBorder: _buildBorder(
                                    color: Colors.grey.shade200),
                                focusedBorder: _buildBorder(
                                    color: Colors.blue.shade600, width: 1.5),
                              ),
                              validator: (val) =>
                              val == null ? "Select semester" : null,
                            ),
                            const SizedBox(height: 18),
                            DropdownButtonFormField<String>(
                              value: selectedYear,
                              items: _years.map((yr) {
                                return DropdownMenuItem<String>(
                                  value: yr,
                                  child: Text(yr),
                                );
                              }).toList(),
                              onChanged: isLoading
                                  ? null
                                  : (value) {
                                setState(() {
                                  selectedYear = value;
                                });
                              },
                              decoration: InputDecoration(
                                labelText: "Year",
                                labelStyle:
                                TextStyle(color: Colors.grey.shade600),
                                floatingLabelStyle:
                                TextStyle(color: Colors.blue.shade600),
                                prefixIcon: Icon(
                                    Icons.date_range_outlined,
                                    color: Colors.grey.shade500),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: _buildBorder(),
                                enabledBorder: _buildBorder(
                                    color: Colors.grey.shade200),
                                focusedBorder: _buildBorder(
                                    color: Colors.blue.shade600, width: 1.5),
                              ),
                              validator: (val) =>
                              val == null ? "Select year" : null,
                            ),
                            const SizedBox(height: 18),
                          ],

                          // --- Email Address ---
                          TextFormField(
                            controller: _emailController,
                            focusNode: _emailFocusNode,
                            enabled: !isLoading,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) => FocusScope.of(context)
                                .requestFocus(_passwordFocusNode),
                            decoration: InputDecoration(
                              labelText: "Email Address",
                              labelStyle: TextStyle(color: Colors.grey.shade600),
                              floatingLabelStyle:
                              TextStyle(color: Colors.blue.shade600),
                              prefixIcon: Icon(Icons.email_outlined,
                                  color: Colors.grey.shade500),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: _buildBorder(),
                              enabledBorder:
                              _buildBorder(color: Colors.grey.shade200),
                              focusedBorder: _buildBorder(
                                  color: Colors.blue.shade600, width: 1.5),
                            ),
                            validator: (val) =>
                            val == null || !val.contains("@")
                                ? "Enter a valid email"
                                : null,
                          ),
                          const SizedBox(height: 18),

                          // --- Password ---
                          TextFormField(
                            controller: _passwordController,
                            focusNode: _passwordFocusNode,
                            enabled: !isLoading,
                            obscureText: obscurePassword,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) => FocusScope.of(context)
                                .requestFocus(_confirmPasswordFocusNode),
                            decoration: InputDecoration(
                              labelText: "Password",
                              labelStyle: TextStyle(color: Colors.grey.shade600),
                              floatingLabelStyle:
                              TextStyle(color: Colors.blue.shade600),
                              prefixIcon: Icon(Icons.lock_outline,
                                  color: Colors.grey.shade500),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: Colors.grey.shade500,
                                ),
                                onPressed: () {
                                  setState(() {
                                    obscurePassword = !obscurePassword;
                                  });
                                },
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: _buildBorder(),
                              enabledBorder:
                              _buildBorder(color: Colors.grey.shade200),
                              focusedBorder: _buildBorder(
                                  color: Colors.blue.shade600, width: 1.5),
                            ),
                            validator: (val) => val == null || val.length < 6
                                ? "Password must be at least 6 characters"
                                : null,
                          ),
                          const SizedBox(height: 18),

                          // --- Confirm Password ---
                          TextFormField(
                            controller: _confirmPasswordController,
                            focusNode: _confirmPasswordFocusNode,
                            enabled: !isLoading,
                            obscureText: obscureConfirmPassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => signUp(),
                            decoration: InputDecoration(
                              labelText: "Confirm Password",
                              labelStyle: TextStyle(color: Colors.grey.shade600),
                              floatingLabelStyle:
                              TextStyle(color: Colors.blue.shade600),
                              prefixIcon: Icon(Icons.lock_clock_outlined,
                                  color: Colors.grey.shade500),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  obscureConfirmPassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: Colors.grey.shade500,
                                ),
                                onPressed: () {
                                  setState(() {
                                    obscureConfirmPassword =
                                    !obscureConfirmPassword;
                                  });
                                },
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: _buildBorder(),
                              enabledBorder:
                              _buildBorder(color: Colors.grey.shade200),
                              focusedBorder: _buildBorder(
                                  color: Colors.blue.shade600, width: 1.5),
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) {
                                return "Please confirm password";
                              }
                              if (val != _passwordController.text) {
                                return "Passwords do not match";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 28),

                          // --- Submit Button ---
                          SizedBox(
                            height: 52,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.blue.shade600,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.blue.shade200,
                                disabledForegroundColor: Colors.white70,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: isLoading ? null : signUp,
                              child: isLoading
                                  ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                                  : const Text(
                                "Create Account",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // --- Switch to Sign In ---
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Already have an account?",
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 4),
                              TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.blue.shade600,
                                  disabledForegroundColor:
                                  Colors.grey.shade400,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: isLoading
                                    ? null
                                    : () => Navigator.pop(context),
                                child: const Text(
                                  "Sign In",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RolePillOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _RolePillOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubicEmphasized,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.blue.shade600 : Colors.grey.shade600,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}