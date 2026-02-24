import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cbt_software/providers/quiz_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StudentQuizView extends ConsumerStatefulWidget {
  const StudentQuizView({super.key});

  @override
  ConsumerState<StudentQuizView> createState() => _StudentQuizViewState();
}

class _StudentQuizViewState extends ConsumerState<StudentQuizView> {
  final _germanController = TextEditingController();

  // --- Real-time Progress Reporting ---
  Future<void> _pingProgress(int index, int total) async {
    final state = ref.read(quizProvider);
    try {
      // Pings the server so Admin sees "Matric - Progress: 5/20"
      await http.post(
        Uri.parse('http://${Uri.base.host}:8080/api/progress'),
        body: jsonEncode({
          'matric': state.studentMatric,
          'progress': "${index + 1}/$total",
        }),
      );
    } catch (e) {
      debugPrint("Progress ping failed: $e");
    }
  }

  void _handleFinish(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Submission"),
        content: const Text(
          "Are you sure you want to end your exam? This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              // Show a loading indicator so the student doesn't click twice
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) =>
                    const Center(child: CircularProgressIndicator()),
              );

              await ref.read(quizProvider.notifier).submitQuiz();

              if (!mounted) return;
              Navigator.pop(context); // Close loading indicator
              Navigator.pop(context); // Close confirmation dialog
              _showSuccessDialog();
            },
            child: const Text("SUBMIT"),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 60),
        title: const Text("Exam Submitted!"),
        content: const Text("Your responses have been recorded successfully."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.invalidate(quizProvider); // Resets to Login Screen
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(quizProvider);
    final notifier = ref.read(quizProvider.notifier);

    // Ensure we have questions loaded
    if (state.questions.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final currentQ = state.questions[state.currentQuestionIndex];
    final String type = currentQ['type'] ?? 'OBJ';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.indigo[900],
        foregroundColor: Colors.white,
        title: Text(state.courseTitle),
        actions: [
          Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: state.isUrgent ? Colors.red : Colors.black26,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                notifier.timerText,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (state.currentQuestionIndex + 1) / state.questions.length,
            backgroundColor: Colors.indigo.withOpacity(0.1),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Question ${state.currentQuestionIndex + 1} of ${state.questions.length}",
                    style: TextStyle(
                      color: Colors.indigo[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    currentQ['text'] ?? '',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildAnswerArea(type, currentQ, state, notifier),
                ],
              ),
            ),
          ),
          _buildNavigationFooter(state, notifier),
        ],
      ),
    );
  }

  Widget _buildAnswerArea(String type, Map q, dynamic state, dynamic notifier) {
    if (type == 'GERMAN') {
      // Sync controller with state for back/forward navigation
      _germanController.text =
          state.selectedAnswers[state.currentQuestionIndex] ?? '';
      return TextField(
        controller: _germanController,
        onChanged: (val) =>
            notifier.selectAnswer(state.currentQuestionIndex, val),
        decoration: InputDecoration(
          labelText: "Type your answer",
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
      );
    } else if (type == 'THEORY') {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue[200]!),
        ),
        child: const Text(
          "✍️ This is a Theory Question. Please write your detailed answer in the provided physical answer booklet.",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      );
    } else {
      // Default OBJ
      return Column(
        children: ['A', 'B', 'C', 'D'].map((letter) {
          final optText = q['option$letter'] ?? '';
          if (optText.isEmpty) return const SizedBox.shrink();
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation:
                state.selectedAnswers[state.currentQuestionIndex] == letter
                ? 2
                : 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color:
                    state.selectedAnswers[state.currentQuestionIndex] == letter
                    ? Colors.indigo
                    : Colors.grey[300]!,
              ),
            ),
            child: RadioListTile<String>(
              title: Text(optText),
              value: letter,
              groupValue: state.selectedAnswers[state.currentQuestionIndex],
              onChanged: (val) =>
                  notifier.selectAnswer(state.currentQuestionIndex, val!),
            ),
          );
        }).toList(),
      );
    }
  }

  Widget _buildNavigationFooter(dynamic state, dynamic notifier) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (state.currentQuestionIndex > 0)
            OutlinedButton(
              onPressed: notifier.prevQuestion,
              child: const Text("PREVIOUS"),
            )
          else
            const SizedBox(),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  (state.currentQuestionIndex == state.questions.length - 1)
                  ? Colors.green
                  : Colors.indigo,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              _pingProgress(state.currentQuestionIndex, state.questions.length);
              if (state.currentQuestionIndex < state.questions.length - 1) {
                notifier.nextQuestion();
              } else {
                _handleFinish(context, ref);
              }
            },
            child: Text(
              (state.currentQuestionIndex == state.questions.length - 1)
                  ? "FINISH"
                  : "NEXT",
            ),
          ),
        ],
      ),
    );
  }
}
