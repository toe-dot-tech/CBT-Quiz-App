// LOCATION: lib/models/quiz_models.dart

class QuizResult {
  final String matric;
  final String surname;
  final int score;
  final int total;
  final DateTime timestamp;

  QuizResult({required this.matric, required this.surname, required this.score, required this.total, required this.timestamp});

  Map<String, dynamic> toJson() => {
    'matric': matric,
    'surname': surname,
    'score': score,
    'total': total,
    'timestamp': timestamp.toIso8601String(),
  };
}