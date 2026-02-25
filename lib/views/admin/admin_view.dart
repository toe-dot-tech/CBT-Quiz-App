import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cbtapp/server/quiz_server.dart';
import 'package:cbtapp/services/result_storage_service.dart';
import 'package:cbtapp/utils/csv_helper.dart';
import 'package:cbtapp/utils/docs_helper.dart';
import 'package:cbtapp/utils/file_picker_helper.dart';
import 'package:cbtapp/utils/path_helper.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class AdminView extends StatefulWidget {
  const AdminView({super.key});
  @override
  State<AdminView> createState() => _AdminViewState();
}

class _AdminViewState extends State<AdminView> {
  bool isLive = false;
  String ip = "Offline";

  int passedCount = 0;
  int failedCount = 0;
  String avgScore = "0%";
  Timer? _refreshTimer;
  String _submissionStatus = "0 / 0";

  List<List<dynamic>> _registeredData = [];
  List<List<dynamic>> _uploadedQuestions = [];
  int _totalQuestionsAvailable = 0;

  final _courseController = TextEditingController(text: "General Studies 101");
  final _timerController = TextEditingController(text: "60");
  final _qCountController = TextEditingController(text: "50");

  final _qTextController = TextEditingController();
  final _optA = TextEditingController();
  final _optB = TextEditingController();
  final _optC = TextEditingController();
  final _optD = TextEditingController();
  final _ansController = TextEditingController();

  final ResultStorageService resultService = ResultStorageService();

  @override
  void initState() {
    super.initState();

    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _loadStats();
    });

    QuizServer().studentStream.listen((clients) {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _loadStats();
        });
      }
    });
    _attemptLoadExistingRegistry();
    _refreshQuestionBank();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _courseController.dispose();
    _timerController.dispose();
    _qCountController.dispose();
    _qTextController.dispose();
    _optA.dispose();
    _optB.dispose();
    _optC.dispose();
    _optD.dispose();
    _ansController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final stats = await ResultStorageService().calculateLiveStats();

    final resultsFile = File('quiz_results.csv');
    int finishedCount = 0;
    if (await resultsFile.exists()) {
      final lines = await resultsFile.readAsLines();
      finishedCount = lines.where((l) => l.trim().isNotEmpty).length - 1;
    }

    int regCount = _registeredData
        .where((r) => r.isNotEmpty && r[0].toString().toLowerCase() != 'matric')
        .length;

    if (mounted) {
      setState(() {
        passedCount = stats.passed;
        failedCount = stats.failed;
        _submissionStatus =
            "${finishedCount < 0 ? 0 : finishedCount} / $regCount";
        avgScore = "${stats.avgScore.toStringAsFixed(1)}%";
      });
    }
  }

  Future<void> _attemptLoadExistingRegistry() async {
    final file = File('registered_students.csv');
    if (await file.exists()) {
      final csvString = await file.readAsString();
      final parsed = CsvHelper.parseCsv(
        csvString,
      ).map((row) => row as List<dynamic>).toList();
      setState(() {
        _registeredData = parsed;
      });
    }
  }

  Future<void> _refreshQuestionBank() async {
    try {
      final file = File('questions.csv');
      if (!await file.exists()) {
        print("questions.csv not found");
        return;
      }

      // Try multiple encodings
      String csvString;
      try {
        // First try UTF-8
        csvString = await file.readAsString(encoding: utf8);
      } catch (e) {
        try {
          // Try with UTF-8 that might have BOM
          final bytes = await file.readAsBytes();
          if (bytes.length >= 3 &&
              bytes[0] == 0xEF &&
              bytes[1] == 0xBB &&
              bytes[2] == 0xBF) {
            // Skip BOM
            csvString = utf8.decode(bytes.skip(3).toList());
          } else {
            // Try as Latin-1 (Windows-1252)
            csvString = latin1.decode(bytes);
          }
        } catch (e2) {
          print("Error decoding file: $e2");
          return;
        }
      }

      final allRows = CsvHelper.parseCsv(
        csvString,
      ).map((row) => row as List<dynamic>).toList();

      setState(() {
        _uploadedQuestions = allRows;
        if (allRows.isNotEmpty) {
          if (allRows[0][0].toString().toLowerCase() == 'type') {
            _totalQuestionsAvailable = allRows.length - 1;
          } else {
            _totalQuestionsAvailable = allRows.length;
          }
        } else {
          _totalQuestionsAvailable = 0;
        }
      });

      print("✅ Loaded ${_totalQuestionsAvailable} questions");
    } catch (e) {
      debugPrint("Error refreshing bank: $e");
    }
  }

  Future<void> _processWordContent(String rawText) async {
    List<String> lines = rawText.split(RegExp(r'\r\n|\n|\r'));
    List<List<dynamic>> newQuestions = [];

    String currentQ = "";
    String a = "", b = "", c = "", d = "", ans = "";

    for (String line in lines) {
      String cleanLine = line.trim();
      if (cleanLine.isEmpty) continue;

      if (RegExp(r'^\d+[\.\)]').hasMatch(cleanLine)) {
        if (currentQ.isNotEmpty) {
          newQuestions.add(["OBJ", currentQ, a, b, c, d, ans]);
        }
        currentQ = cleanLine.replaceFirst(RegExp(r'^\d+[\.\)]'), '').trim();
        a = "";
        b = "";
        c = "";
        d = "";
        ans = "";
      } else if (cleanLine.toUpperCase().startsWith(RegExp(r'[A-D][\.\)]'))) {
        String content = cleanLine.substring(2).trim();
        String letter = cleanLine[0].toUpperCase();
        if (letter == 'A') {
          a = content;
        } else if (letter == 'B')
          b = content;
        else if (letter == 'C')
          c = content;
        else if (letter == 'D')
          d = content;
      } else if (cleanLine.toUpperCase().contains('ANS:')) {
        ans = cleanLine.split(':').last.trim().toUpperCase();
      }
    }

    if (currentQ.isNotEmpty) {
      newQuestions.add(["OBJ", currentQ, a, b, c, d, ans]);
    }

    final file = File('questions.csv');
    if (!await file.exists()) {
      await file.writeAsString("Type,Text,OptA,OptB,OptC,OptD,Answer\n");
    }

    String csvData = CsvHelper.listToCsv(newQuestions);
    await file.writeAsString("$csvData\n", mode: FileMode.append, flush: true);

    await _refreshQuestionBank();
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Error", style: TextStyle(color: Colors.red)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Future<void> _importDocxDocument() async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Selecting file..."),
            ],
          ),
        ),
      );

      // Pick DOCX file
      final file = await FilePickerHelper.pickDocxFile();

      // Close loading dialog
      if (context.mounted) Navigator.pop(context);

      if (file == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("No file selected"),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Get file size BEFORE showing dialog
      final fileSize = await FilePickerHelper.getFileSize(file);
      final fileName = FilePickerHelper.getFileName(file.path);

      // Show processing dialog
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text("Processing $fileName..."),
                const SizedBox(height: 8),
                Text("Size: $fileSize", style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        );
      }

      // Extract content from DOCX
      final content = await DocxHelper.extractTextFromDocx(file);

      // Close processing dialog
      if (context.mounted) Navigator.pop(context);

      if (content != null) {
        await _processWordContent(content);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "✅ DOCX file imported successfully!\n"
                "File: $fileName",
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        if (context.mounted) {
          _showErrorDialog(
            "Failed to extract content from DOCX file.\n"
            "Please ensure the file is a valid Word document.",
          );
        }
      }
    } catch (e) {
      // Make sure to close any open dialogs
      if (context.mounted) Navigator.pop(context);

      if (context.mounted) {
        _showErrorDialog("Error importing file: $e");
      }
    }
  }

  Future<void> _saveSingleQuestion() async {
    final newQ = [
      [
        "OBJ",
        _qTextController.text,
        _optA.text,
        _optB.text,
        _optC.text,
        _optD.text,
        _ansController.text.toUpperCase(),
      ],
    ];
    final file = File('questions.csv');
    if (!await file.exists()) {
      await file.writeAsString("Type,Text,OptA,OptB,OptC,OptD,Answer\n");
    }
    String csvRow = "${CsvHelper.listToCsv(newQ)}\n";
    await file.writeAsString(csvRow, mode: FileMode.append, flush: true);

    _qTextController.clear();
    _optA.clear();
    _optB.clear();
    _optC.clear();
    _optD.clear();
    _ansController.clear();
    await _refreshQuestionBank();
    Navigator.pop(context);
  }

  void _confirmDeleteAllQuestions() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          "Wipe Question Bank?",
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            onPressed: () async {
              final file = File('questions.csv');
              await file.writeAsString(
                "Type,Text,OptA,OptB,OptC,OptD,Answer\n",
              );
              await _refreshQuestionBank();
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("DELETE ALL"),
          ),
        ],
      ),
    );
  }

  Future<void> _importRegistry() async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Selecting CSV file..."),
            ],
          ),
        ),
      );

      // Pick CSV file
      final file = await FilePickerHelper.pickCsvFile();

      // Close loading dialog
      if (context.mounted) Navigator.pop(context);

      if (file == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("No file selected"),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final fileName = FilePickerHelper.getFileName(file.path);

      // Show processing dialog
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text("Processing $fileName..."),
              ],
            ),
          ),
        );
      }

      // Read file content
      final content = await file.readAsString();

      // Parse CSV
      final parsed = CsvHelper.parseCsv(
        content,
      ).map((row) => row as List<dynamic>).toList();

      // Validate CSV structure
      if (parsed.isNotEmpty && parsed[0].length >= 3) {
        // Optionally save a copy locally
        final localFile = File('registered_students.csv');
        await localFile.writeAsString(content);

        setState(() {
          _registeredData = parsed;
        });

        // Close processing dialog
        if (context.mounted) Navigator.pop(context);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "✅ Student Registry Updated!\n"
                "${parsed.length - 1} students loaded from $fileName",
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        if (context.mounted) Navigator.pop(context);
        if (context.mounted) {
          _showErrorDialog(
            "Invalid CSV format.\n"
            "Please ensure the file has headers: Matric,Surname,Firstname",
          );
        }
      }
    } catch (e) {
      // Make sure to close any open dialogs
      if (context.mounted) Navigator.pop(context);

      if (context.mounted) {
        _showErrorDialog("Error importing registry: $e");
      }
    }
  }

  Widget _statCard(String title, String val, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  val,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceChart() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Exam Performance",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 30),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (passedCount + failedCount == 0)
                    ? 10
                    : (passedCount + failedCount + 2).toDouble(),
                barGroups: [
                  BarChartGroupData(
                    x: 0,
                    barRods: [
                      BarChartRodData(
                        toY: passedCount.toDouble(),
                        color: Colors.greenAccent,
                        width: 30,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 1,
                    barRods: [
                      BarChartRodData(
                        toY: failedCount.toDouble(),
                        color: Colors.redAccent,
                        width: 30,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ],
                  ),
                ],
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 30),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value == 0 ? "PASS" : "FAIL",
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveLogSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Live Activity Log",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          SizedBox(
            height: 200,
            child: StreamBuilder<List<String>>(
              stream: QuizServer().studentStream,
              initialData: QuizServer.connectedClients,
              builder: (context, snapshot) {
                final clients = snapshot.data ?? [];
                if (clients.isEmpty) {
                  return const Center(
                    child: Text(
                      "No active students",
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: clients.length,
                  itemBuilder: (ctx, i) {
                    bool isFinished = clients[i].contains("FINISHED");
                    return ListTile(
                      leading: Icon(
                        isFinished ? Icons.check_circle : Icons.person_pin,
                        color: isFinished
                            ? Colors.greenAccent
                            : Colors.blueAccent,
                      ),
                      title: Text(
                        clients[i],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionBankSection() {
    List<List<dynamic>> displayList = [];

    if (_uploadedQuestions.isNotEmpty) {
      if (_uploadedQuestions[0][0].toString().toLowerCase() == "type") {
        displayList = _uploadedQuestions.sublist(1);
      } else {
        displayList = _uploadedQuestions;
      }
    }
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Live Question Bank",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "${displayList.length} Questions Loaded",
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              IconButton(
                icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
                onPressed: _confirmDeleteAllQuestions,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (displayList.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  "No questions found.",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            SizedBox(
              height: 350,
              child: ListView.builder(
                itemCount: displayList.length,
                itemBuilder: (ctx, i) {
                  final qRow = displayList[i];
                  if (qRow.length < 7) return const SizedBox.shrink();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: Colors.white.withOpacity(0.05),
                    child: ListTile(
                      leading: CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.blueAccent,
                        child: Text(
                          "${i + 1}",
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      title: Text(
                        qRow[1].toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        "A: ${qRow[2]} | B: ${qRow[3]} | C: ${qRow[4]} | D: ${qRow[5]}",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          "Ans: ${qRow[6]}",
                          style: const TextStyle(
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRegisteredStudentsSection() {
    final rows = _registeredData
        .where((r) => r.isNotEmpty && r[0].toString().toLowerCase() != 'matric')
        .toList();

    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.only(top: 32),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Registered Students Registry",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "${rows.length} Students Total",
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 15),
          if (rows.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  "No students registered. Use 'Bulk Student Upload' to add them.",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final r = rows[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person,
                        color: Colors.blueAccent,
                        size: 16,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Text(
                          r[0].toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          "${r[1]} ${r[2]}",
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _showConfigDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          "Exam Configuration",
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _entryField(_courseController, "Course Title", Icons.book),
            _entryField(_timerController, "Time (Mins)", Icons.timer),
            _entryField(_qCountController, "Question Limit", Icons.list),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              QuizServer().updateAdminConfig(
                _courseController.text,
                _timerController.text,
                int.tryParse(_qCountController.text) ?? 50,
              );
              setState(() {});
              Navigator.pop(ctx);
            },
            child: const Text("SAVE"),
          ),
        ],
      ),
    );
  }

  void _showAddQuestionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text("Manual Add", style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _entryField(_qTextController, "Question", Icons.help),
              _entryField(_optA, "Option A", Icons.circle_outlined),
              _entryField(_optB, "Option B", Icons.circle_outlined),
              _entryField(_optC, "Option C", Icons.circle_outlined),
              _entryField(_optD, "Option D", Icons.circle_outlined),
              _entryField(
                _ansController,
                "Answer (A, B, C, or D)",
                Icons.check,
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: _saveSingleQuestion,
            child: const Text("SAVE QUESTION"),
          ),
        ],
      ),
    );
  }

  Widget _entryField(TextEditingController ctrl, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey),
          prefixIcon: Icon(icon, color: Colors.blueAccent),
          enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white12),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _courseController.text.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: [
                Text(
                  isLive ? "SERVER LIVE: " : "SERVER OFFLINE",
                  style: TextStyle(
                    color: isLive ? Colors.greenAccent : Colors.redAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isLive)
                  SelectableText(
                    "http://$ip:8080",
                    style: const TextStyle(
                      color: Colors.blueAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ],
        ),
        const CircleAvatar(
          backgroundColor: Colors.indigo,
          child: Icon(Icons.admin_panel_settings, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 240,
      color: const Color(0xFF1E293B),
      child: Column(
        children: [
          const SizedBox(height: 50),
          _sidebarItem(Icons.dashboard, "Dashboard", true),
          _sidebarItem(
            Icons.settings,
            "Exam Config",
            false,
            onTap: _showConfigDialog,
          ),
          _sidebarItem(
            Icons.add_box,
            "Add Single Q",
            false,
            onTap: _showAddQuestionDialog,
          ),
          // _sidebarItem(
          //   Icons.description,
          //   "Word Transformer",
          //   false,
          //   onTap: _importWordDocument,
          // ),
          _sidebarItem(
            Icons.description,
            "Import DOCX File", // Changed from "Import Text File"
            false,
            onTap: _importDocxDocument,
          ),
          _sidebarItem(
            Icons.group_add,
            "Bulk Student Upload",
            false,
            onTap: _importRegistry,
          ),
          _sidebarItem(
            Icons.assessment,
            "Final Report (CSV)",
            false,
            onTap: () async {
              String message = await resultService.downloadCsvReport(
                "CBT_Exam_Results",
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(message),
                  backgroundColor: Colors.blueGrey[800],
                  duration: const Duration(seconds: 8),
                  action: SnackBarAction(
                    label: "OPEN FOLDER",
                    textColor: Colors.blueAccent,
                    onPressed: () async {
                      final dir = await PathHelper.getDownloadsDirectory();
                      if (dir != null) {
                        Process.run('explorer.exe', [dir]);
                      }
                    },
                  ),
                ),
              );
            },
          ),
          const Spacer(),
          _serverControlPanel(),
        ],
      ),
    );
  }

  Widget _sidebarItem(
    IconData icon,
    String label,
    bool active, {
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: active ? Colors.blueAccent : Colors.grey),
      title: Text(
        label,
        style: TextStyle(color: active ? Colors.white : Colors.grey),
      ),
      onTap: onTap,
    );
  }

  Widget _serverControlPanel() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isLive ? Colors.redAccent : Colors.greenAccent,
          minimumSize: const Size(double.infinity, 50),
        ),
        onPressed: () async {
          try {
            if (isLive) {
              print("Stopping server...");
              await QuizServer().stop();
              if (mounted) {
                setState(() {
                  isLive = false;
                  ip = "Offline";
                });
              }
              print("Server stopped");
            } else {
              print("Starting server...");
              final address = await QuizServer().start();
              print("Server started at: $address");
              if (mounted) {
                setState(() {
                  ip = address;
                  isLive = true;
                });
              }
            }
          } catch (e) {
            print("Server error: $e");
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Server error: $e"),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
        child: Text(
          isLive ? "STOP EXAM" : "START EXAM",
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 32),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                    childAspectRatio: 2.2,
                    children: [
                      _statCard(
                        "Registered",
                        "${_registeredData.where((r) => r.isNotEmpty && r[0].toString().toLowerCase() != 'matric').length}",
                        Icons.people,
                        Colors.blue,
                      ),
                      _statCard(
                        "Finished",
                        "${passedCount + failedCount}",
                        Icons.check_circle,
                        Colors.green,
                      ),
                      _statCard(
                        "Avg. Score",
                        avgScore,
                        Icons.analytics,
                        Colors.purple,
                      ),
                      _statCard(
                        "Question Bank",
                        "$_totalQuestionsAvailable",
                        Icons.library_books,
                        Colors.orange,
                      ),
                      _statCard(
                        "Submission Status",
                        _submissionStatus,
                        Icons.check_circle,
                        Colors.green,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: _buildPerformanceChart()),
                      const SizedBox(width: 20),
                      Expanded(flex: 3, child: _buildLiveLogSection()),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _buildQuestionBankSection(),
                  _buildRegisteredStudentsSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
