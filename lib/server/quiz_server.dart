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

  // --- DYNAMIC CONFIGURATION VARIABLES (Admin-Controlled) ---
  String adminCourseTitle = "General Studies 101";
  String adminDuration = "60";
  int adminQuestionLimit = 50;

  // For Real-time UI updates in Admin
  final _updateController = StreamController<List<String>>.broadcast();
  Stream<List<String>> get studentStream => _updateController.stream;
  List<String> connectedStudents = []; // List of "Name (Progress)" strings

  bool get isRunning => _serverInstance != null;

  // --- CORE METHODS ---

  Future<String> start() async {
    if (_serverInstance != null) return "Already Running";

    final router = Router();

    // 1. API: Student Login with Dynamic Config
    router.post('/api/login', (Request req) async {
      final data = jsonDecode(await req.readAsString());
      final String matric = data['matric'].toString().trim().toUpperCase();
      final String surname = data['surname'].toString().trim().toUpperCase();

      final student = await _findStudentInCsv(matric, surname);

      if (student != null) {
        int availablePool = await _getAvailableQuestionCount();

        // Track the student as "Connected"
        String studentDisplay = "${student['firstName']} $surname (Joined)";
        if (!connectedStudents.contains(studentDisplay)) {
          connectedStudents.add(studentDisplay);
          _updateController.add(connectedStudents);
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
    });

    // 2. API: Real-Time Progress Update
    router.post('/api/progress', (Request req) async {
      final data = jsonDecode(await req.readAsString());
      final String matric = data['matric'];
      final String progress = data['progress']; // e.g., "12/50"

      // Update the connected list to show progress next to name
      for (int i = 0; i < connectedStudents.length; i++) {
        if (connectedStudents[i].contains(matric)) {
          connectedStudents[i] = "$matric - Progress: $progress";
          break;
        }
      }
      _updateController.add(connectedStudents);
      return Response.ok(jsonEncode({'status': 'updated'}));
    });

    // 3. API: Submit Final Result
    router.post('/api/submit', (Request req) async {
      final data = jsonDecode(await req.readAsString());
      await _saveLocally(data);

      // Mark as Finished in Admin panel
      connectedStudents.removeWhere((s) => s.contains(data['matric']));
      connectedStudents.add("${data['matric']} - FINISHED ✅");
      _updateController.add(connectedStudents);

      return Response.ok(jsonEncode({'status': 'saved'}));
    });

    // Static Handlers
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
    if (!await file.exists()) return null;
    final lines = await file.readAsLines();
    for (var line in lines) {
      final cells = line.split(',');
      if (cells.length >= 3) {
        if (cells[0].trim().toUpperCase() == matric &&
            cells[1].trim().toUpperCase() == surname) {
          return {'firstName': cells[2].trim()};
        }
      }
    }
    return null;
  }

  Future<int> _getAvailableQuestionCount() async {
    try {
      final file = File('questions.csv');
      if (!await file.exists()) return 0;
      final csvString = await file.readAsString();
      return const CsvToListConverter().convert(csvString).length;
    } catch (e) {
      return 0;
    }
  }

  Future<void> _saveLocally(Map<String, dynamic> data) async {
    final file = File('quiz_results.csv');
    final row = [
      DateTime.now().toIso8601String(),
      data['matric'],
      data['surname'],
      data['firstname'] ?? 'N/A',
      data['score'],
    ];
    String csvRow = "${const ListToCsvConverter().convert([row])}\n";
    await file.writeAsString(csvRow, mode: FileMode.append, flush: true);
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

  void updateAdminConfig(String title, String time, int qLimit) {
    adminCourseTitle = title;
    adminDuration = time;
    adminQuestionLimit = qLimit;
  }

  Future<void> stop() async {
    await _serverInstance?.close(force: true);
    _serverInstance = null;
  }

  Future<void> updateRegisteredStudents(String csvContent) async {
    await File(
      'registered_students.csv',
    ).writeAsString(csvContent, flush: true);
  }

  void clearStudentList() {
    connectedStudents.clear();
    _updateController.add(connectedStudents);
  }
}
