
import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;


class QuizState {
  final List<Map<String, dynamic>> questions;
  final String courseTitle;
  final int seconds;
  final bool isUrgent;
  final int currentQuestionIndex;
  final Map<int, dynamic> selectedAnswers;
  final bool isQuizStarted;
  final bool isSubmitted;
  final String? studentMatric;
  final String? studentName;

  QuizState({
    this.questions = const [],
    this.courseTitle = "Loading Exam...",
    this.seconds = 3600,
    this.isUrgent = false,
    this.currentQuestionIndex = 0,
    this.selectedAnswers = const {},
    this.isQuizStarted = false,
    this.isSubmitted = false,
    this.studentMatric,
    this.studentName,
  });

  QuizState copyWith({
    List<Map<String, dynamic>>? questions,
    String? courseTitle,
    int? seconds,
    bool? isUrgent,
    int? currentQuestionIndex,
    Map<int, dynamic>? selectedAnswers,
    bool? isQuizStarted,
    bool? isSubmitted,
    String? studentMatric,
    String? studentName,
  }) {
    return QuizState(
      questions: questions ?? this.questions,
      courseTitle: courseTitle ?? this.courseTitle,
      seconds: seconds ?? this.seconds,
      isUrgent: isUrgent ?? this.isUrgent,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      selectedAnswers: selectedAnswers ?? this.selectedAnswers,
      isQuizStarted: isQuizStarted ?? this.isQuizStarted,
      isSubmitted: isSubmitted ?? this.isSubmitted,
      studentMatric: studentMatric ?? this.studentMatric,
      studentName: studentName ?? this.studentName,
    );
  }
}

class QuizNotifier extends StateNotifier<QuizState> {
  QuizNotifier() : super(QuizState());
  Timer? _timer;

  void setStudentInfo({required String matric, required String fullName}) {
    state = state.copyWith(studentMatric: matric, studentName: fullName);
  }

  void startQuiz({
    required List<Map<String, dynamic>> questions,
    required String course,
    required int durationMinutes,
  }) {
    state = state.copyWith(
      questions: questions,
      courseTitle: course,
      seconds: durationMinutes * 60,
      isQuizStarted: true,
      currentQuestionIndex: 0,
      selectedAnswers: {},
    );
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (state.seconds > 0) {
        state = state.copyWith(
          seconds: state.seconds - 1,
          isUrgent: state.seconds <= 60,
        );
      } else {
        submitQuiz();
      }
    });
  }

  void selectAnswer(int qIndex, dynamic answer) {
    final newAnswers = Map<int, dynamic>.from(state.selectedAnswers);
    newAnswers[qIndex] = answer;
    state = state.copyWith(selectedAnswers: newAnswers);
  }

  void nextQuestion() {
    if (state.currentQuestionIndex < state.questions.length - 1) {
      state = state.copyWith(
        currentQuestionIndex: state.currentQuestionIndex + 1,
      );
    }
  }

  void prevQuestion() {
    if (state.currentQuestionIndex > 0) {
      state = state.copyWith(
        currentQuestionIndex: state.currentQuestionIndex - 1,
      );
    }
  }

  String get timerText {
    final m = (state.seconds ~/ 60).toString().padLeft(2, '0');
    final s = (state.seconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  Future<void> submitQuiz() async {
    _timer?.cancel();

    int correctCount = 0;
    for (int i = 0; i < state.questions.length; i++) {
      final correctAnswer = state.questions[i]['answer']
          ?.toString()
          .trim()
          .toUpperCase();
      final studentAnswer = state.selectedAnswers[i]
          ?.toString()
          .trim()
          .toUpperCase();

      if (correctAnswer != null && studentAnswer == correctAnswer) {
        correctCount++;
      }
    }

    double finalScore = state.questions.isEmpty 
        ? 0 
        : (correctCount / state.questions.length) * 100;

    String surname = state.studentName?.split(' ').first ?? "Unknown";
    String firstname = state.studentName?.contains(' ') == true
        ? state.studentName!.split(' ').sublist(1).join(' ')
        : "Student";

    try {
      final response = await http.post(
        Uri.parse('http://${Uri.base.host}:8080/api/submit'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'matric': state.studentMatric,
          'surname': surname,
          'firstname': firstname,
          'score': finalScore.toStringAsFixed(1),
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        state = state.copyWith(isSubmitted: true, isQuizStarted: false);
        print("✅ Exam successfully uploaded to server.");
      }
    } catch (e) {
      print("❌ Submission failed: $e");
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final quizProvider = StateNotifierProvider<QuizNotifier, QuizState>(
  (ref) => QuizNotifier(),
);