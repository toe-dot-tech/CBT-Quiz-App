import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';

class QuizServer {
  static final QuizServer _instance = QuizServer._internal();
  factory QuizServer() => _instance;
  QuizServer._internal();

  HttpServer? _serverInstance;

  // --- DYNAMIC CONFIGURATION VARIABLES ---
  String adminCourseTitle = "General Studies 101";
  String adminDuration = "60";
  int adminQuestionLimit = 50;

  // This matches the AdminView's call: QuizServer.connectedClients
  static List<String> connectedClients = [];

  // Stream for real-time UI updates
  final _updateController = StreamController<List<String>>.broadcast();
  Stream<List<String>> get studentStream => _updateController.stream;

  bool get isRunning => _serverInstance != null;

  // --- CORE METHODS ---

  Future<String> start() async {
    if (_serverInstance != null) return "Already Running";

    final router = Router();

    // 1. API: Student Login
    router.post('/api/login', (Request req) async {
      try {
        final data = jsonDecode(await req.readAsString());
        final String matric = data['matric'].toString().trim().toUpperCase();
        final String surname = data['surname'].toString().trim().toUpperCase();

        final student = await _findStudentInCsv(matric, surname);

        if (student != null) {
          int availablePool = await _getAvailableQuestionCount();

          // Add to Live Log
          String studentDisplay = "${student['firstName']} $surname ($matric)";
          if (!connectedClients.contains(studentDisplay)) {
            connectedClients.add(studentDisplay);
            _updateController.add(connectedClients);
          }

          return Response.ok(
            jsonEncode({
              'status': 'success',
              'firstName': student['firstName'],
              'config': {
                'course': adminCourseTitle,
                'duration': adminDuration,
                'totalToAnswer': adminQuestionLimit > availablePool
                    ? availablePool
                    : adminQuestionLimit,
              },
            }),
          );
        } else {
          return Response.forbidden(
            jsonEncode({'status': 'error', 'message': 'Invalid Credentials'}),
          );
        }
      } catch (e) {
        return Response.internalServerError(body: e.toString());
      }
    });

    // 2. API: Real-Time Progress Update
    router.post('/api/progress', (Request req) async {
      final data = jsonDecode(await req.readAsString());
      final String matric = data['matric'];
      final String progress = data['progress']; // e.g., "12/50"

      for (int i = 0; i < connectedClients.length; i++) {
        if (connectedClients[i].contains(matric)) {
          connectedClients[i] = "$matric - Progress: $progress";
          break;
        }
      }
      _updateController.add(connectedClients);
      return Response.ok(jsonEncode({'status': 'updated'}));
    });
    router.get('/questions.csv', (Request req) async {
      final file = File('questions.csv');
      if (await file.exists()) {
        final contents = await file.readAsString();
        // Return the CSV content with the correct header
        return Response.ok(contents, headers: {'content-type': 'text/csv'});
      } else {
        return Response.notFound('Question bank file not found on server.');
      }
    });

    // 3. API: Submit Final Result
    router.post('/api/submit', (Request req) async {
      final data = jsonDecode(await req.readAsString());
      await _saveLocally(data);

      // Update Live Log to Finished
      connectedClients.removeWhere((s) => s.contains(data['matric']));
      connectedClients.add("${data['matric']} - FINISHED ✅");
      _updateController.add(connectedClients);

      return Response.ok(jsonEncode({'status': 'saved'}));
    });

    // Static Web File Handlers
    final webHandler = createStaticHandler(
      'assets/web',
      defaultDocument: 'index.html',
    );
    router.mount('/', webHandler);

    _serverInstance = await io.serve(
      router.call,
      InternetAddress.anyIPv4,
      8080,
    );

    return await _getNetworkIp();
  }

  // --- HELPERS ---

  Future<Map<String, String>?> _findStudentInCsv(
    String matric,
    String surname,
  ) async {
    final file = File('registered_students.csv');
    if (!await file.exists()) {
      print("Server Error: registered_students.csv not found!");
      return null;
    }

    try {
      final csvString = await file.readAsString();
      final List<List<dynamic>> rows = const CsvToListConverter().convert(
        csvString,
      );

      for (var row in rows) {
        if (row.isEmpty) continue;

        // Skip the header row if it exists
        if (row[0].toString().toLowerCase().contains('matric')) continue;

        // Clean the data from the CSV
        String csvMatric = row[0].toString().trim().toUpperCase();
        String csvSurname = row.length > 1
            ? row[1].toString().trim().toUpperCase()
            : "";
        String firstName = row.length > 2
            ? row[2].toString().trim()
            : "Student";

        // Debugging: This will show in your terminal exactly what is being compared
        print("Checking CSV: '$csvMatric' vs Input: '$matric'");

        if (csvMatric == matric && csvSurname == surname) {
          return {'firstName': firstName};
        }
      }
    } catch (e) {
      print("Error reading student CSV: $e");
    }
    return null;
  }

  Future<int> _getAvailableQuestionCount() async {
    try {
      final file = File('questions.csv');
      if (!await file.exists()) return 0;
      final csvString = await file.readAsString();
      final list = const CsvToListConverter().convert(csvString);
      return list.length > 1 ? list.length - 1 : 0;
    } catch (e) {
      return 0;
    }
  }

  Future<void> _saveLocally(Map<String, dynamic> data) async {
    final file = File('quiz_results.csv');
    if (!await file.exists()) {
      await file.writeAsString("Timestamp,Matric,Surname,Firstname,Score\n");
    }

    // Ensure the keys match exactly what the student app sends
    final row = [
      DateTime.now().toIso8601String(),
      data['matric'],
      data['surname'],
      data['firstname'] ?? 'N/A',
      data['score'],
    ];

    String csvRow = "${const ListToCsvConverter().convert([row])}\n";
    await file.writeAsString(csvRow, mode: FileMode.append, flush: true);

    // LOG THIS TO TERMINAL so you can see it working
    print("✅ DATA SAVED TO CSV: ${data['matric']} scored ${data['score']}");
  }

  Future<String> _getNetworkIp() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    );
    for (var interface in interfaces) {
      for (var addr in interface.addresses) {
        if (!addr.isLoopback) return addr.address;
      }
    }
    return "localhost";
  }

  Future<List<Map<String, dynamic>>> getQuestionsForStudent() async {
    final file = File('questions.csv');

    if (!await file.exists()) {
      print("CRITICAL: questions.csv does not exist on disk!");
      return [];
    }

    try {
      final csvString = await file.readAsString();
      final rows = const CsvToListConverter().convert(csvString);

      // Filter out header and empty rows
      final dataRows = rows
          .where(
            (row) =>
                row.isNotEmpty && row[0].toString().toLowerCase() != 'type',
          )
          .toList();

      return dataRows
          .map(
            (q) => {
              'text': q[1],
              'options': [q[2], q[3], q[4], q[5]],
              'answer': q[6],
            },
          )
          .toList();
    } catch (e) {
      print("Error reading questions: $e");
      return [];
    }
  }
  // --- ADMIN CONTROLS ---

  void updateAdminConfig(String title, String time, int qLimit) {
    adminCourseTitle = title;
    adminDuration = time;
    adminQuestionLimit = qLimit;
  }

  Future<void> stop() async {
    await _serverInstance?.close(force: true);
    _serverInstance = null;
    connectedClients.clear();
    _updateController.add(connectedClients);
  }

  void clearStudentList() {
    connectedClients.clear();
    _updateController.add(connectedClients);
  }
}
