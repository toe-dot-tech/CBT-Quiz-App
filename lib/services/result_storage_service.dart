import 'dart:io';
import 'package:csv/csv.dart';

class ResultStats {
  final int passed;
  final int failed;
  final double avgScore;

  ResultStats({this.passed = 0, this.failed = 0, this.avgScore = 0.0});
}

class ResultStorageService {
  static const String fileName = 'quiz_results.csv';

  // 1. Calculate stats for the Dashboard Graphs
  Future<ResultStats> calculateLiveStats() async {
    final file = File(fileName);
    if (!await file.exists()) return ResultStats();

    try {
      final csvString = await file.readAsString();
      final fields = const CsvToListConverter().convert(csvString);

      int passCount = 0;
      int failCount = 0;
      double totalScore = 0;

      for (var row in fields) {
        if (row.length < 4) continue;

        // Assuming score is at Index 3
        final score = double.tryParse(row[3].toString()) ?? 0.0;
        totalScore += score;

        // Pass mark logic (Setting this to 1 for your 2-question test)
        if (score >= 1) {
          passCount++;
        } else {
          failCount++;
        }
      }

      double average = fields.isNotEmpty ? totalScore / fields.length : 0.0;
      return ResultStats(
        passed: passCount,
        failed: failCount,
        avgScore: average,
      );
    } catch (e) {
      print("Error calculating stats: $e");
      return ResultStats();
    }
  }

  // 2. FIXED: Method to load raw data for the "Export Results" button
  Future<List<Map<String, dynamic>>> loadAllResults() async {
    final file = File(fileName);
    if (!await file.exists()) return [];

    try {
      final csvString = await file.readAsString();
      final rows = const CsvToListConverter().convert(csvString);

      // We convert the List of Lists into a List of Maps so the AdminView
      // can easily access data by keys like res['matric']
      return rows.map((row) {
        return {
          'date': row.isNotEmpty ? row[0].toString() : "N/A",
          'matric': row.length > 1 ? row[1].toString() : "N/A",
          'surname': row.length > 2 ? row[2].toString() : "N/A",
          'score': row.length > 3 ? row[3].toString() : "0",
          'firstname': row.length > 4 ? row[4].toString() : "N/A",
        };
      }).toList();
    } catch (e) {
      print("Error loading results for export: $e");
      return [];
    }
  }
}
