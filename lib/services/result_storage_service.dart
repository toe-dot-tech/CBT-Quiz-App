import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cbtapp/utils/path_helper.dart';

class ResultStats {
  final int passed;
  final int failed;
  final double avgScore;

  ResultStats({this.passed = 0, this.failed = 0, this.avgScore = 0.0});
}

class ResultStorageService {
  static const String fileName = 'quiz_results.csv';

  // Manual CSV parser
  List<List<String>> parseCsv(String csvString) {
    List<List<String>> result = [];
    LineSplitter ls = const LineSplitter();
    List<String> lines = ls.convert(csvString);
    
    for (String line in lines) {
      if (line.trim().isEmpty) continue;
      List<String> row = line.split(',').map((e) => e.trim()).toList();
      result.add(row);
    }
    
    return result;
  }

  // Convert data to CSV string
  String listToCsv(List<List<dynamic>> data) {
    StringBuffer buffer = StringBuffer();
    for (var row in data) {
      buffer.writeln(row.join(','));
    }
    return buffer.toString();
  }

  Future<ResultStats> calculateLiveStats() async {
    final file = File(fileName);
    if (!await file.exists()) return ResultStats();

    try {
      final csvString = await file.readAsString();
      final fields = parseCsv(csvString).map((row) => row as List<dynamic>).toList();

      final dataRows = fields
          .skip(1)
          .where((row) => row.isNotEmpty && row.length >= 5)
          .toList();

      if (dataRows.isEmpty) return ResultStats();

      int pass = 0;
      int fail = 0;
      double total = 0;

      for (var row in dataRows) {
        double score = double.tryParse(row[4].toString()) ?? 0.0;
        total += score;
        if (score >= 50.0) {
          pass++;
        } else {
          fail++;
        }
      }

      return ResultStats(
        passed: pass,
        failed: fail,
        avgScore: total / dataRows.length,
      );
    } catch (e) {
      print("Error calculating stats: $e");
      return ResultStats();
    }
  }

  Future<void> clearAllResults() async {
    final file = File(fileName);
    if (await file.exists()) {
      await file.writeAsString("Timestamp,Matric,Surname,Firstname,Score\n");
    }
  }

  Future<List<Map<String, dynamic>>> loadAllResults() async {
    final file = File(fileName);
    if (!await file.exists()) return [];
    try {
      final csvString = await file.readAsString();
      final rows = parseCsv(csvString).map((row) => row as List<dynamic>).toList();

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
      print("Error loading results: $e");
      return [];
    }
  }

  Future<String> downloadCsvReport(String courseTitle) async {
    try {
      final results = await loadAllResults();
      if (results.isEmpty) return "No results to export";

      List<List<dynamic>> csvData = [
        ["S/N", "Matric Number", "Surname", "Firstname", "Score (%)", "Status"],
      ];

      for (var i = 0; i < results.length; i++) {
        final r = results[i];
        final score = double.tryParse(r['score']) ?? 0;
        csvData.add([
          i + 1,
          r['matric'],
          r['surname'],
          r['firstname'],
          r['score'],
          score >= 50 ? "PASS" : "FAIL",
        ]);
      }

      String csvString = listToCsv(csvData);

      // Use PathHelper instead of path_provider
      final downloadsDir = await PathHelper.getDownloadsDirectory();
      if (downloadsDir == null) return "Downloads folder not found";

      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String finalPath = PathHelper.join(
        downloadsDir,
        "${courseTitle}_Results_$timestamp.csv",
      );

      final file = File(finalPath);
      await file.writeAsString(csvString);

      return "Successfully exported to Downloads: \n${PathHelper.basename(finalPath)}";
    } catch (e) {
      return "Export failed: $e";
    }
  }
}