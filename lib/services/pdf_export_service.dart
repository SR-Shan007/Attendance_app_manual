import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/attendance_record.dart';

class PdfExportService {
  /// Generates and previews/downloads a PDF report for a session or overall course
  static Future<void> exportAttendanceReport({
    required String courseTitle,
    required String courseCode,
    required List<StudentAttendanceItem> students,
    int? totalSessions,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // --- HEADER ---
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      courseTitle,
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey800,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Course Code: $courseCode',
                      style: const pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'ATTENDANCE REPORT',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey600,
                      ),
                    ),
                    pw.Text(
                      DateTime.now().toString().split(' ')[0],
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 12),

            // --- SUMMARY STATS ---
            pw.Row(
              children: [
                pw.Text(
                  'Total Enrolled: ${students.length}',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
                if (totalSessions != null) ...[
                  pw.SizedBox(width: 16),
                  pw.Text(
                    'Total Conducted Sessions: $totalSessions',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
            pw.SizedBox(height: 16),

            // --- TABLE OF RECORDS ---
            pw.TableHelper.fromTextArray(
              headers: [
                '#',
                'Student ID',
                'Name',
                'Attended',
                if (totalSessions != null) 'Percentage',
                'Status'
              ],
              data: List.generate(students.length, (index) {
                final s = students[index];
                final pct = (totalSessions != null && totalSessions > 0)
                    ? '${((s.totalAttendance / totalSessions) * 100).toStringAsFixed(1)}%'
                    : 'N/A';

                return [
                  (index + 1).toString(),
                  s.studentCode ?? s.id,
                  s.name,
                  s.totalAttendance.toString(),
                  if (totalSessions != null) pct,
                  s.isPresent ? 'Present' : 'Absent',
                ];
              }),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blueGrey700,
              ),
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                ),
              ),
            ),
          ];
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 16),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(
                color: PdfColors.grey600,
                fontSize: 9,
              ),
            ),
          );
        },
      ),
    );

    // Triggers save/download or printing dialog
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: '${courseCode}_Attendance_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }
}