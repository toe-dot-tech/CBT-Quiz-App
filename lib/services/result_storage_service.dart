import 'dart:io';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ResultStats {
  final int passed;
  final int failed;
  final double avgScore;

  ResultStats({this.passed = 0, this.failed = 0, this.avgScore = 0.0});
}

class ResultStorageService {
  static const String fileName = 'quiz_results.csv';

  Future<ResultStats> calculateLiveStats() async {
    final file = File(fileName);
    if (!await file.exists()) return ResultStats();
    try {
      final csvString = await file.readAsString();
      final fields = const CsvToListConverter().convert(csvString);

      // BETTER FILTERING: Skip the first row (header) and empty rows
      if (fields.length <= 1) return ResultStats();
      final dataRows = fields
          .skip(1)
          .where((row) => row.isNotEmpty && row.length >= 5)
          .toList();

      int passCount = 0;
      int failCount = 0;
      double totalScore = 0;

      for (var row in dataRows) {
        final scoreValue = double.tryParse(row[4].toString()) ?? 0.0;
        totalScore += scoreValue;
        if (scoreValue >= 50.0) {
          passCount++;
        } else {
          failCount++;
        }
      }
      return ResultStats(
        passed: passCount,
        failed: failCount,
        avgScore:
            totalScore / dataRows.length, // Keep as raw percentage (e.g. 75.0)
      );
    } catch (e) {
      return ResultStats();
    }
  }

  Future<List<Map<String, dynamic>>> loadAllResults() async {
    final file = File(fileName);
    if (!await file.exists()) return [];
    try {
      final csvString = await file.readAsString();
      final rows = const CsvToListConverter().convert(csvString);

      // SKIP index 0 (The Header)
      if (rows.length <= 1) return [];
      final dataRows = rows.skip(1).where((row) => row.isNotEmpty).toList();

      return dataRows.map((row) {
        return {
          'date': row[0].toString(),
          'matric': row[1].toString(),
          'surname': row[2].toString(),
          'firstname': row[3].toString(),
          'score': row[4].toString(),
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // --- NEW: PDF GENERATION FEATURE ---
  Future<void> generatePdfReport(String courseTitle) async {
    final results = await loadAllResults();
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(level: 0, child: pw.Text("Official Exam Result Sheet")),
          pw.Paragraph(text: "Course: $courseTitle"),
          pw.Paragraph(text: "Date Generated: ${DateTime.now().toString()}"),
          pw.SizedBox(height: 20),
          pw.Table.fromTextArray(
            headers: ['S/N', 'Matric Number', 'Name', 'Score (%)', 'Status'],
            data: List<List<dynamic>>.generate(results.length, (index) {
              final r = results[index];
              final score = double.tryParse(r['score']) ?? 0;
              return [
                index + 1,
                r['matric'],
                "${r['surname']} ${r['firstname']}",
                r['score'],
                score >= 50 ? "PASS" : "FAIL",
              ];
            }),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  Future<void> clearAllResults() async {
    final file = File(fileName);
    if (await file.exists()) {
      await file.writeAsString("Timestamp,Matric,Surname,Firstname,Score\n");
    }
  }
}
