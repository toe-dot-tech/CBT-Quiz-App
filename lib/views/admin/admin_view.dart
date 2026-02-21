// LOCATION: lib/views/admin_view.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cbt_software/server/quiz_server.dart';
import 'package:cbt_software/services/result_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';

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

  // Student Registration Data
  List<List<dynamic>> _registeredData = [];
  final String _searchQuery = "";

  // Config Controllers
  final _courseController = TextEditingController(text: "General Studies 101");
  final _timerController = TextEditingController(text: "60");
  final _qCountController = TextEditingController(text: "50");

  // Manual Student Entry Controllers
  final _mMatric = TextEditingController();
  final _mSurname = TextEditingController();
  final _mFirstname = TextEditingController();

  // Inside _AdminViewState SINGLE QUESTINO INUT
  final _qTextController = TextEditingController();
  final _optA = TextEditingController();
  final _optB = TextEditingController();
  final _optC = TextEditingController();
  final _optD = TextEditingController();
  final _ansController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _loadStats();
    });
    _attemptLoadExistingRegistry();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _courseController.dispose();
    _timerController.dispose();
    _mMatric.dispose();
    _mSurname.dispose();
    _mFirstname.dispose();

    _qTextController.dispose();
    _optA.dispose();
    _optB.dispose();
    _optC.dispose();
    _optD.dispose();
    _ansController.dispose();
    super.dispose();
  }

  // --- REGISTRY LOGIC ---

  Future<void> _attemptLoadExistingRegistry() async {
    final file = File('registered_students.csv');
    if (await file.exists()) {
      final csvString = await file.readAsString();
      setState(() {
        _registeredData = const CsvToListConverter().convert(csvString);
      });
    }
  }

  void _showManualRegistration() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          "Manual Student Entry",
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _entryField(_mMatric, "Matric Number", Icons.badge),
            const SizedBox(height: 12),
            _entryField(_mSurname, "Surname", Icons.person),
            const SizedBox(height: 12),
            _entryField(_mFirstname, "First Name", Icons.person_outline),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_mMatric.text.isNotEmpty && _mSurname.text.isNotEmpty) {
                final newRow = [
                  _mMatric.text.trim().toUpperCase(),
                  _mSurname.text.trim().toUpperCase(),
                  _mFirstname.text.trim().toUpperCase(),
                ];

                setState(() => _registeredData.add(newRow));
                String csvData = const ListToCsvConverter().convert(
                  _registeredData,
                );
                await QuizServer().updateRegisteredStudents(csvData);

                _mMatric.clear();
                _mSurname.clear();
                _mFirstname.clear();
                Navigator.pop(ctx);
              }
            },
            child: const Text("ADD STUDENT"),
          ),
        ],
      ),
    );
  }

  // 1. FIXES: Undefined name '_handleRemove'
  Future<void> _handleRemove(String matric) async {
    // 1. Remove from local list in UI memory
    setState(() {
      _registeredData.removeWhere((row) => row[0].toString() == matric);
    });

    // 2. Convert updated list back to CSV format and save to file
    try {
      String updatedCsv = const ListToCsvConverter().convert(_registeredData);
      await QuizServer().updateRegisteredStudents(updatedCsv);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Student $matric removed from registry.")),
        );
      }
    } catch (e) {
      print("Error updating CSV after removal: $e");
    }
  }

  Future<void> _saveQuestion(String type) async {
    if (_qTextController.text.isEmpty) return;

    // Prepare the row for the CSV
    // Format: Type, Question, OptA, OptB, OptC, OptD, CorrectAnswer
    final List<dynamic> newQuestion = [
      type,
      _qTextController.text.trim(),
      type == 'OBJ' ? _optA.text.trim() : "",
      type == 'OBJ' ? _optB.text.trim() : "",
      type == 'OBJ' ? _optC.text.trim() : "",
      type == 'OBJ' ? _optD.text.trim() : "",
      // If theory, we don't need an answer key for auto-grading
      type == 'THEORY' ? "[PAPER-BASED]" : _ansController.text.trim(),
    ];

    try {
      final file = File('questions.csv');
      // Convert to CSV row and append
      String csvRow = "${const ListToCsvConverter().convert([newQuestion])}\n";
      await file.writeAsString(csvRow, mode: FileMode.append, flush: true);

      // Clear fields for the next question
      _qTextController.clear();
      _optA.clear();
      _optB.clear();
      _optC.clear();
      _optD.clear();
      _ansController.clear();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Question added successfully!")),
        );
      }
    } catch (e) {
      debugPrint("Save Error: $e");
    }
  }

  // 2. FIXES: Undefined name '_buildPerformanceChart'
  Widget _buildPerformanceChart() {
    double total = (passedCount + failedCount).toDouble();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            "Pass/Fail Ratio",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 0,
                centerSpaceRadius: 40,
                sections: [
                  PieChartSectionData(
                    value: passedCount.toDouble() + (total == 0 ? 0.01 : 0),
                    color: Colors.greenAccent,
                    title: passedCount > 0 ? '$passedCount' : '',
                    radius: 50,
                    titleStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  PieChartSectionData(
                    value: failedCount.toDouble() + (total == 0 ? 0.01 : 0),
                    color: Colors.redAccent,
                    title: failedCount > 0 ? '$failedCount' : '',
                    radius: 50,
                    titleStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
          _chartLegend(Colors.greenAccent, "Passed"),
          _chartLegend(Colors.redAccent, "Failed"),
        ],
      ),
    );
  }

  // --- QUESTION & CONFIG LOGIC ---

  Future<void> _importQuestions() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result != null) {
      // Logic to save questions.csv to server assets
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Exam questions updated successfully!")),
      );
    }
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
            const SizedBox(height: 12),
            _entryField(_timerController, "Duration (Minutes)", Icons.timer),
            const SizedBox(height: 12),
            // NEW: Field for Number of Questions
            _entryField(
              _qCountController,
              "Number of Questions to Answer",
              Icons.format_list_numbered,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              // Update the server config variables
              QuizServer().updateAdminConfig(
                _courseController.text,
                _timerController.text,
                int.tryParse(_qCountController.text) ?? 50,
              );
              setState(() {}); // Refresh UI
              Navigator.pop(ctx);
            },
            child: const Text("SAVE CONFIG"),
          ),
        ],
      ),
    );
  }

  // Add this to your _AdminViewState class
  void _showAddQuestionDialog() {
    String selectedType = 'OBJ';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        // Allows dropdown to update inside dialog
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text(
            "Add Single Question",
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<String>(
                  value: selectedType,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white),
                  items: ['OBJ', 'GERMAN', 'THEORY'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (val) => setDialogState(() => selectedType = val!),
                ),
                _entryField(
                  _qTextController,
                  "Question Text",
                  Icons.help_outline,
                ),
                if (selectedType == 'OBJ') ...[
                  _entryField(_optA, "Option A", Icons.radio_button_unchecked),
                  _entryField(_optB, "Option B", Icons.radio_button_unchecked),
                  _entryField(_optC, "Option C", Icons.radio_button_unchecked),
                  _entryField(_optD, "Option D", Icons.radio_button_unchecked),
                ],
                if (selectedType != 'THEORY')
                  _entryField(
                    _ansController,
                    "Correct Answer",
                    Icons.check_circle_outline,
                  ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => _saveQuestion(selectedType),
              child: const Text("SAVE"),
            ),
          ],
        ),
      ),
    );
  }
  // --- RESULT EXPORT LOGIC ---

  Future<void> _exportResults() async {
    final results = await ResultStorageService().loadAllResults();

    List<List<dynamic>> exportData = [
      ["DATE", "MATRIC", "SURNAME", "FIRSTNAME", "SCORE", "COURSE"],
    ];

    for (var res in results) {
      exportData.add([
        res['date'] ?? DateTime.now().toString(),
        res['matric'] ?? "N/A",
        res['surname'] ?? "N/A",
        res['firstname'] ?? "N/A",
        res['score'] ?? 0,
        _courseController.text,
      ]);
    }

    String csvString = const ListToCsvConverter().convert(exportData);
    String? path = await FilePicker.platform.saveFile(
      fileName: '${_courseController.text.replaceAll(' ', '_')}_results.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (path != null) {
      await File(path).writeAsString(csvString);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Results exported!")));
    }
  }

  // --- EXISTING CORE LOGIC ---

  Future<void> _loadStats() async {
    final stats = await ResultStorageService().calculateLiveStats();
    if (mounted) {
      setState(() {
        passedCount = stats.passed;
        failedCount = stats.failed;
        avgScore = "${(stats.avgScore * 50).toStringAsFixed(1)}%";
      });
    }
  }

  void _toggleServer() async {
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
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 32),
                  _buildStatsGrid(),
                  const SizedBox(height: 32),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _buildLiveActivitySection()),
                      const SizedBox(width: 24),
                      Expanded(flex: 2, child: _buildPerformanceChart()),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildRegisteredStudentsSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- UI BUILDING BLOCKS ---
  // 1. FIXES: Undefined name '_buildHeader'
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
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isLive
                    ? Colors.blueAccent.withOpacity(0.1)
                    : Colors.redAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isLive
                    ? "LIVE ON: http://$ip:8080 | Duration: ${_timerController.text} mins"
                    : "SERVER OFFLINE",
                style: TextStyle(
                  color: isLive ? Colors.blueAccent : Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        const CircleAvatar(
          radius: 28,
          backgroundColor: Colors.indigo,
          child: Icon(Icons.admin_panel_settings, color: Colors.white),
        ),
      ],
    );
  }

  // 2. FIXES: Undefined name '_buildLiveActivitySection'
  Widget _buildLiveActivitySection() {
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
            "Live Connection Stream",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 300,
            child: StreamBuilder<List<String>>(
              stream: QuizServer().studentStream,
              builder: (context, snapshot) {
                final students =
                    snapshot.data ?? QuizServer().connectedStudents;
                if (students.isEmpty) {
                  return const Center(
                    child: Text(
                      "No students logged in yet",
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: students.length,
                  itemBuilder: (context, i) => ListTile(
                    leading: const Icon(Icons.person, color: Colors.blueAccent),
                    title: Text(
                      students[i],
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: const Icon(
                      Icons.circle,
                      color: Colors.greenAccent,
                      size: 10,
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

  // 3. FIXES: Undefined name '_buildRegisteredStudentsSection'
  Widget _buildRegisteredStudentsSection() {
    final validRows = _registeredData.where((row) => row.isNotEmpty).toList();
    final displayRows = validRows.length > 1 ? validRows.skip(1).toList() : [];

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
            "Student Registry",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          if (displayRows.isEmpty)
            const Center(
              child: Text(
                "Registry empty. Import CSV or add manually.",
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            Table(
              border: TableBorder.symmetric(
                inside: const BorderSide(color: Colors.white10),
              ),
              children: [
                const TableRow(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        "MATRIC",
                        style: TextStyle(color: Colors.blueAccent),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        "NAME",
                        style: TextStyle(color: Colors.blueAccent),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        "ACTION",
                        style: TextStyle(color: Colors.blueAccent),
                      ),
                    ),
                  ],
                ),
                ...displayRows.map(
                  (row) => TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          row[0].toString(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          "${row[1]} ${row.length > 2 ? row[2] : ''}",
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete,
                          color: Colors.redAccent,
                          size: 18,
                        ),
                        onPressed: () => _handleRemove(row[0].toString()),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 200,
      color: const Color(0xFF1E293B),
      child: Column(
        children: [
          // const DrawerHeader(
          //   child: Center(
          //     child: Text(
          //       "CBT PRO",
          //       style: TextStyle(
          //         color: Colors.blueAccent,
          //         fontSize: 26,
          //         fontWeight: FontWeight.bold,
          //       ),
          //     ),
          //   ),
          // ),
          _sidebarItem(Icons.dashboard, "Dashboard", true),
          _sidebarItem(
            Icons.settings,
            "Exam Config",
            false,
            onTap: _showConfigDialog,
          ),
          _sidebarItem(
            Icons.add_circle_outline,
            "Add Single Question",
            false,
            onTap: _showAddQuestionDialog, // This triggers your new dialog
          ),
          _sidebarItem(
            Icons.add_task,
            "Bulk Questions",
            false,
            onTap: _importQuestions,
          ),
          _sidebarItem(
            Icons.person_add,
            "Add Student",
            false,
            onTap: _showManualRegistration,
          ),
          _sidebarItem(
            Icons.upload_file,
            "Import CSV",
            false,
            onTap: _importStudentList,
          ),
          _sidebarItem(
            Icons.analytics,
            "Export Results",
            false,
            onTap: _exportResults,
          ),
          const Spacer(),
          _serverControlPanel(),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    int totalRegistered = _registeredData.length > 1
        ? _registeredData.length - 1
        : 0;
    int submissions = passedCount + failedCount;

    return Row(
      children: [
        _statCard(
          "Submissions",
          "$submissions / $totalRegistered",
          Icons.assignment_ind,
          Colors.green,
        ),
        const SizedBox(width: 20),
        _statCard("Avg. Score", avgScore, Icons.analytics, Colors.purple),
        const SizedBox(width: 20),
        _statCard(
          "Remaining",
          "${totalRegistered - submissions}",
          Icons.pending_actions,
          Colors.orange,
        ),
      ],
    );
  }

  Widget _entryField(TextEditingController ctrl, String label, IconData icon) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: Colors.blueAccent),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white12),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.blueAccent),
        ),
      ),
    );
  }

  // [Include all other UI components from previous implementation here: _buildHeader, _buildLiveActivitySection, _buildPerformanceChart, etc.]
  // ... (Rest of UI widgets from original code)
  // --- UI HELPER METHODS ---

  Widget _sidebarItem(
    IconData icon,
    String label,
    bool isActive, {
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: isActive ? Colors.blueAccent : Colors.grey),
      title: Text(
        label,
        style: TextStyle(
          color: isActive ? Colors.white : Colors.grey[400],
          fontSize: 14,
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _statCard(String title, String val, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 16),
            Text(
              val,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chartLegend(Color col, String txt) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(shape: BoxShape.circle, color: col),
          ),
          const SizedBox(width: 8),
          Text(txt, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }

  // Fixes: Undefined name '_importStudentList'
  Future<void> _importStudentList() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final bytes = await file.readAsBytes();
      String content = utf8.decode(bytes).replaceFirst('\uFEFF', '').trim();

      // Fixes formatting issues common in CSV exports
      final RegExp fixMissingComma = RegExp(r'([a-z])([A-Z])');
      content = content.replaceFirst('FIRSTNAMELIS', 'FIRSTNAME\nLIS');
      String fixedContent = content.replaceAllMapped(fixMissingComma, (match) {
        return '${match.group(1)},\n${match.group(2)}';
      });

      List<String> lines = fixedContent.split('\n');
      List<List<dynamic>> finalData = [];

      for (var line in lines) {
        String trimmedLine = line.trim();
        if (trimmedLine.isEmpty) continue;
        List<String> row = trimmedLine.split(',').map((e) => e.trim()).toList();
        if (row.length >= 2) finalData.add(row);
      }

      if (finalData.isNotEmpty) {
        await QuizServer().updateRegisteredStudents(fixedContent);
        setState(() {
          _registeredData = finalData;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Success: ${finalData.length - 1} students registered.",
            ),
          ),
        );
      }
    }
  }

  // Fixes: The method '_serverControlPanel' isn't defined
  Widget _serverControlPanel() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextButton.icon(
            onPressed: () => setState(() => QuizServer().clearStudentList()),
            icon: const Icon(Icons.delete_sweep, color: Colors.grey, size: 18),
            label: const Text(
              "Clear Connection List",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _toggleServer,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              decoration: BoxDecoration(
                color: isLive
                    ? Colors.redAccent.withOpacity(0.1)
                    : Colors.greenAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isLive ? Colors.redAccent : Colors.greenAccent,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.power_settings_new,
                    color: isLive ? Colors.redAccent : Colors.greenAccent,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isLive ? "STOP SERVER" : "GO LIVE",
                    style: TextStyle(
                      color: isLive ? Colors.redAccent : Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
