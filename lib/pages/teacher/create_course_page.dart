import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/course_service.dart';

class CreateCoursePage extends StatefulWidget {
  const CreateCoursePage({super.key});

  @override
  State<CreateCoursePage> createState() => _CreateCoursePageState();
}

class _CreateCoursePageState extends State<CreateCoursePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();

  final _nameFocusNode = FocusNode();
  final _codeFocusNode = FocusNode();

  bool isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _nameFocusNode.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  Future<void> createCourse() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
    });

    try {
      await CourseService().createCourse(
        courseName: _nameController.text.trim(),
        courseCode: _codeController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF16A34A),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white, size: 22),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Course created successfully!",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFDC2626),
          duration: const Duration(seconds: 4),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Failed to Create Course",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      e.toString().replaceFirst("Exception: ", ""),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
                child: const Icon(
                  Icons.close,
                  color: Colors.white70,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
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
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        extendBodyBehindAppBar: true,
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.add_chart_rounded,
                                  size: 44,
                                  color: Colors.blue.shade600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "Create a Course",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Fill in the details to publish a new course for your students.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 28),

                            // --- Course Name ---
                            TextFormField(
                              controller: _nameController,
                              focusNode: _nameFocusNode,
                              enabled: !isLoading,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              cursorColor: Colors.blue.shade600,
                              decoration: InputDecoration(
                                labelText: "Course Name",
                                hintText: "e.g. Operating Systems",
                                labelStyle: TextStyle(color: Colors.grey.shade600),
                                floatingLabelStyle:
                                TextStyle(color: Colors.blue.shade600),
                                prefixIcon: Icon(
                                  Icons.menu_book_outlined,
                                  color: Colors.grey.shade500,
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: _buildBorder(),
                                enabledBorder:
                                _buildBorder(color: Colors.grey.shade200),
                                focusedBorder: _buildBorder(
                                  color: Colors.blue.shade600,
                                  width: 1.5,
                                ),
                                errorBorder:
                                _buildBorder(color: Colors.red.shade400),
                                focusedErrorBorder: _buildBorder(
                                  color: Colors.red.shade600,
                                  width: 1.5,
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return "Course name is required";
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            // --- Course Code ---
                            TextFormField(
                              controller: _codeController,
                              focusNode: _codeFocusNode,
                              enabled: !isLoading,
                              textCapitalization: TextCapitalization.characters,
                              textInputAction: TextInputAction.done,
                              cursorColor: Colors.blue.shade600,
                              onFieldSubmitted: (_) => createCourse(),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[a-zA-Z0-9\-]'),
                                ),
                              ],
                              decoration: InputDecoration(
                                labelText: "Course Code",
                                hintText: "e.g. CSE311",
                                labelStyle: TextStyle(color: Colors.grey.shade600),
                                floatingLabelStyle:
                                TextStyle(color: Colors.blue.shade600),
                                prefixIcon: Icon(
                                  Icons.tag_rounded,
                                  color: Colors.grey.shade500,
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: _buildBorder(),
                                enabledBorder:
                                _buildBorder(color: Colors.grey.shade200),
                                focusedBorder: _buildBorder(
                                  color: Colors.blue.shade600,
                                  width: 1.5,
                                ),
                                errorBorder:
                                _buildBorder(color: Colors.red.shade400),
                                focusedErrorBorder: _buildBorder(
                                  color: Colors.red.shade600,
                                  width: 1.5,
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return "Course code is required";
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
                                onPressed: isLoading ? null : createCourse,
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
                                  "Create Course",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
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
      ),
    );
  }
}