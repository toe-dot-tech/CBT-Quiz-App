class Student {
  final String matric;
  final String surname;
  int score;
  bool isFinished;

  Student({
    required this.matric, 
    required this.surname, 
    this.score = 0, 
    this.isFinished = false
  });
}