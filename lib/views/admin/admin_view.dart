import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cbt_software/server/quiz_server.dart';
import 'package:cbt_software/services/result_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:docx_to_text/docx_to_text.dart';

class AdminView extends StatefulWidget {
  const AdminView({super.key});
  @override
  State<AdminView> createState() => _AdminViewState();
}

class _AdminViewState extends State<AdminView> {
  bool isLive = false;
  String ip = "Offline";

  // Stats variables

  int passedCount = 0;
  int failedCount = 0;
  String avgScore = "0%";
  Timer? _refreshTimer;
  String _submissionStatus = "0 / 0";

  // Data Lists
  List<List<dynamic>> _registeredData = [];
  List<List<dynamic>> _uploadedQuestions = [];
  int _totalQuestionsAvailable = 0;

  // Config Controllers
  final _courseController = TextEditingController(text: "General Studies 101");
  final _timerController = TextEditingController(text: "60");
  final _qCountController = TextEditingController(text: "50");

  // Single Question Controllers
  final _qTextController = TextEditingController();
  final _optA = TextEditingController();
  final _optB = TextEditingController();
  final _optC = TextEditingController();
  final _optD = TextEditingController();
  final _ansController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // Existing timer
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _loadStats();
    });

    // 2. THE FIX: Listen to the server stream.
    // Every time a student's status changes (like becoming "FINISHED ✅"),
    // trigger a stats reload immediately.
    QuizServer().studentStream.listen((clients) {
      if (mounted) {
        // Small delay to let the CSV file finish writing to the hard drive
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

  // --- LOGIC: STATS & DATA ---
  Future<void> _loadStats() async {
    final stats = await ResultStorageService().calculateLiveStats();

    final resultsFile = File('quiz_results.csv');
    int finishedCount = 0;
    if (await resultsFile.exists()) {
      final lines = await resultsFile.readAsLines();
      // Only count lines that actually have data
      finishedCount = lines.where((l) => l.trim().isNotEmpty).length - 1;
    }

    int regCount = _registeredData
        .where((r) => r.isNotEmpty && r[0].toString().toLowerCase() != 'matric')
        .length;

    if (mounted) {
      setState(() {
        passedCount = stats.passed;
        failedCount = stats.failed;
        // This is the variable the StatCard looks at
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
      setState(() {
        _registeredData = const CsvToListConverter().convert(csvString);
      });
    }
  }

  Future<void> _refreshQuestionBank() async {
    try {
      final file = File('questions.csv');
      if (await file.exists()) {
        final csvString = await file.readAsString();
        final allRows = const CsvToListConverter().convert(csvString);

        setState(() {
          _uploadedQuestions = allRows;
          if (allRows.isNotEmpty) {
            // If first row is the header, count total minus 1
            if (allRows[0][0].toString().toLowerCase() == 'type') {
              _totalQuestionsAvailable = allRows.length - 1;
            } else {
              _totalQuestionsAvailable = allRows.length;
            }
          } else {
            _totalQuestionsAvailable = 0;
          }
        });
      }
    } catch (e) {
      debugPrint("Error refreshing bank: $e");
    }
  }

  // --- LOGIC: WORD PARSER ---

  Future<void> _processWordContent(String rawText) async {
    // Use a more robust split to handle different line endings
    List<String> lines = rawText.split(RegExp(r'\r\n|\n|\r'));
    List<List<dynamic>> newQuestions = [];

    String currentQ = "";
    String a = "", b = "", c = "", d = "", ans = "";

    for (String line in lines) {
      String cleanLine = line.trim();
      if (cleanLine.isEmpty) continue;

      // Detect Question (1. or 1))
      if (RegExp(r'^\d+[\.\)]').hasMatch(cleanLine)) {
        // If we have a stored question, save it before starting the next
        if (currentQ.isNotEmpty) {
          newQuestions.add(["OBJ", currentQ, a, b, c, d, ans]);
        }
        // Start new question - remove the "1." prefix
        currentQ = cleanLine.replaceFirst(RegExp(r'^\d+[\.\)]'), '').trim();
        a = "";
        b = "";
        c = "";
        d = "";
        ans = "";
      }
      // Detect Options - handling "A. Text" or "A) Text"
      else if (cleanLine.toUpperCase().startsWith(RegExp(r'[A-D][\.\)]'))) {
        String content = cleanLine.substring(2).trim();
        String letter = cleanLine[0].toUpperCase();
        if (letter == 'A')
          a = content;
        else if (letter == 'B')
          b = content;
        else if (letter == 'C')
          c = content;
        else if (letter == 'D')
          d = content;
      }
      // Detect Answer
      else if (cleanLine.toUpperCase().contains('ANS:')) {
        ans = cleanLine.split(':').last.trim().toUpperCase();
      }
    }

    // CRITICAL: Catch the very last question (e.g. Question 40)
    if (currentQ.isNotEmpty) {
      newQuestions.add(["OBJ", currentQ, a, b, c, d, ans]);
    }

    final file = File('questions.csv');
    // If file doesn't exist, create it with the header
    if (!await file.exists()) {
      await file.writeAsString("Type,Text,OptA,OptB,OptC,OptD,Answer\n");
    }

    String csvData = const ListToCsvConverter().convert(newQuestions);
    await file.writeAsString("$csvData\n", mode: FileMode.append, flush: true);

    await _refreshQuestionBank();
  }

  Future<void> _importWordDocument() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx'],
    );
    if (result != null && result.files.single.path != null) {
      final bytes = await File(result.files.single.path!).readAsBytes();
      await _processWordContent(docxToText(bytes));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Word doc transformed!")));
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
    if (!await file.exists())
      await file.writeAsString("Type,Text,OptA,OptB,OptC,OptD,Answer\n");
    String csvRow = "${const ListToCsvConverter().convert(newQ)}\n";
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
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final csvString = await file.readAsString();

      // Save it locally so the QuizServer can find it
      final localFile = File('registered_students.csv');
      await localFile.writeAsString(csvString);

      setState(() {
        _registeredData = const CsvToListConverter().convert(csvString);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Student Registry Updated Successfully!"),
          ),
        );
      }
    }
  }

  //* --- UI: COMPONENTS ---

  Widget _statCard(String title, String val, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start, // Align to left
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            // Use Expanded to prevent text overflow
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min, // Fixes the "blank space" issue
              children: [
                Text(
                  val,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18, // Slightly smaller to fit in the card
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
              stream:
                  QuizServer().studentStream, // LISTEN TO THE SERVER DIRECTLY
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
    // 1. Properly filter the data inside the build method
    List<List<dynamic>> displayList = [];

    if (_uploadedQuestions.isNotEmpty) {
      // Correct Dart way: lowercase the string and compare
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
              // Updated to use displayList.length
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

          // Use displayList here
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
              height: 350, // Slightly more space for 40 questions
              child: ListView.builder(
                itemCount: displayList.length,
                itemBuilder: (ctx, i) {
                  final qRow = displayList[i]; // Use displayList here

                  // Safety check: ensure the row has enough columns
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
                        qRow[1].toString(), // The Question Text
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
    // Filter out empty rows and the header
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
  // --- DIALOGS ---

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

  // --- MAIN STRUCTURE ---

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
          _sidebarItem(
            Icons.description,
            "Word Transformer",
            false,
            onTap: _importWordDocument,
          ),
          _sidebarItem(
            Icons.group_add,
            "Bulk Student Upload",
            false,
            onTap: _importRegistry,
          ),
          _sidebarItem(
            Icons.picture_as_pdf,
            "Final Report",
            false,
            onTap: () => ResultStorageService().generatePdfReport(
              _courseController.text,
            ),
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
          if (isLive) {
            await QuizServer().stop();
            setState(() {
              isLive = false;
              ip = "Offline";
            });
          } else {
            final address = await QuizServer().start();
            setState(() {
              ip = address;
              isLive = true;
            });
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
                    childAspectRatio:
                        2.2, // Changed from 3 to 2.2 to give more height
                    children: [
                      _statCard(
                        "Registered",
                        // Counts only data rows, excluding the header
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
                        _submissionStatus, // Use the variable here
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
