import 'package:cbt_software/providers/quiz_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';
import 'dart:convert';
import 'student_quiz_view.dart';

class StudentView extends ConsumerStatefulWidget {
  const StudentView({super.key});

  @override
  ConsumerState<StudentView> createState() => _StudentViewState();
}

class _StudentViewState extends ConsumerState<StudentView> {
  final _matricController = TextEditingController();
  final _surnameController = TextEditingController();

  bool _isLoading = false;
  // studentData now stores dynamic config from the server
  Map<String, dynamic>? _studentData;

  @override
  void dispose() {
    _matricController.dispose();
    _surnameController.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  // 1. Verify credentials and get Dynamic Config from Admin
  Future<void> _attemptLogin() async {
    final matric = _matricController.text.trim().toUpperCase();
    final surname = _surnameController.text.trim().toUpperCase();

    if (matric.isEmpty || surname.isEmpty) {
      _showError("Please enter your Matric Number and Surname.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final serverIp = Uri.base.host;
      final response = await http
          .post(
            Uri.parse('http://$serverIp:8080/api/login'),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({'matric': matric, 'surname': surname}),
          )
          .timeout(const Duration(seconds: 5));

      final result = jsonDecode(response.body);

      if (response.statusCode == 200 && result['status'] == 'success') {
        final config = result['config'];

        // Notify provider of student identity
        ref
            .read(quizProvider.notifier)
            .setStudentInfo(
              matric: matric,
              fullName:
                  "${surname.toUpperCase()} ${result['firstName'].toUpperCase()}",
            );

        setState(() {
          _studentData = {
            'matric': matric,
            'name': "$surname ${result['firstName']}",
            'exam': config['course'],
            'durationRaw': int.parse(config['duration']), // for logic
            'durationDisplay': "${config['duration']} Minutes", // for UI
            'limit': config['totalToAnswer'],
          };
        });
      } else {
        _showError(result['message'] ?? "Invalid Credentials.");
      }
    } catch (e) {
      _showError(
        "Connection error. Ensure you are connected to the Exam Wi-Fi.",
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 2. Fetch the actual question pool and launch the quiz
  Future<void> _fetchQuestionsAndStart() async {
    setState(() => _isLoading = true);
    try {
      // CHANGE THIS: Instead of Uri.base.host, use the IP from the Admin Screen
      // For testing on the same machine, you can use 'localhost'
      // But for students, you should pass the server IP from the login response
      final serverIp = "192.168.1.5"; // Replace with your actual Server IP

      final response = await http.get(
        Uri.parse('http://$serverIp:8080/questions.csv'),
      );

      if (response.statusCode == 200) {
        final csvString = response.body;
        final rows = const CsvToListConverter().convert(csvString);

        // Same mapping logic as before...
        List<Map<String, dynamic>> allQuestions = rows
            .skip(1) // Skips the 'Type,Text...' header
            .where((r) => r.length >= 7) // Safety check for full rows
            .map(
              (r) => {
                'type': r[0].toString(),
                'text': r[1].toString(),
                'optionA': r[2].toString(),
                'optionB': r[3].toString(),
                'optionC': r[4].toString(),
                'optionD': r[5].toString(),
                'answer': r[6].toString(),
              },
            )
            .toList();
        // Shuffle and limit based on Admin config
        allQuestions.shuffle();
        final selectedQuestions = allQuestions
            .take(_studentData!['limit'])
            .toList();

        // Trigger the provider to start the timer and switch views
        ref
            .read(quizProvider.notifier)
            .startQuiz(
              questions: selectedQuestions,
              course: _studentData!['exam'],
              durationMinutes: _studentData!['durationRaw'],
            );
      } else {
        _showError("Question bank not found on server.");
      }
    } catch (e) {
      _showError("Error downloading questions: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quizState = ref.watch(quizProvider);

    if (_studentData == null) {
      return _buildLoginScreen();
    }

    if (!quizState.isQuizStarted) {
      return _buildWaitingRoom();
    }

    return const StudentQuizView();
  }

  // --- UI COMPONENTS ---

  Widget _buildLoginScreen() {
    return Scaffold(
      backgroundColor: Colors.indigo[900],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 10),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.school_rounded,
                  size: 60,
                  color: Colors.indigo,
                ),
                const SizedBox(height: 16),
                const Text(
                  "STUDENT PORTAL",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Text(
                  "Enter your details to proceed",
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _matricController,
                  decoration: const InputDecoration(
                    labelText: "Matric Number",
                    prefixIcon: Icon(Icons.badge),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _surnameController,
                  decoration: const InputDecoration(
                    labelText: "Surname",
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 32),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 55),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _attemptLogin,
                        child: const Text(
                          "VERIFY IDENTITY",
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWaitingRoom() {
    return Scaffold(
      backgroundColor: Colors.indigo[900],
      body: Center(
        child: Container(
          width: 500,
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "CANDIDATE CONFIRMATION",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
              const Divider(height: 40),
              _detailRow("FULL NAME", _studentData!['name']),
              _detailRow("MATRIC NO", _studentData!['matric']),
              _detailRow("EXAM COURSE", _studentData!['exam']),
              _detailRow("QUESTIONS", "${_studentData!['limit']} Questions"),
              _detailRow("ALLOTTED TIME", _studentData!['durationDisplay']),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "⚠️ Ensure your details are correct. Clicking start will begin your timer immediately.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              _isLoading
                  ? const CircularProgressIndicator()
                  : Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                setState(() => _studentData = null),
                            child: const Text("LOGOUT"),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[700],
                            ),
                            onPressed: _fetchQuestionsAndStart,
                            child: const Text(
                              "START EXAM",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
