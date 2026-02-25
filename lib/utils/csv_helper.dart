import 'dart:convert';

class CsvHelper {
  // Manual CSV parser
  static List<List<String>> parseCsv(String csvString) {
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
  static String listToCsv(List<List<dynamic>> data) {
    StringBuffer buffer = StringBuffer();
    for (var row in data) {
      buffer.writeln(row.join(','));
    }
    return buffer.toString();
  }

  // Parse CSV to List<Map<String, dynamic>> with headers
  static List<Map<String, dynamic>> parseCsvToMap(String csvString, {bool hasHeader = true}) {
    final rows = parseCsv(csvString);
    if (rows.isEmpty) return [];
    
    if (hasHeader) {
      final headers = rows.first;
      final dataRows = rows.skip(1).where((row) => row.isNotEmpty).toList();
      
      return dataRows.map((row) {
        Map<String, dynamic> map = {};
        for (int i = 0; i < headers.length && i < row.length; i++) {
          map[headers[i].toLowerCase()] = row[i];
        }
        return map;
      }).toList();
    } else {
      return rows.map((row) {
        Map<String, dynamic> map = {};
        for (int i = 0; i < row.length; i++) {
          map['col$i'] = row[i];
        }
        return map;
      }).toList();
    }
  }
}