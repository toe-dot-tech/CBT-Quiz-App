class Question {
  final String id;
  final String text;
  final List<String> options;
  final int correctIndex;

  Question({
    required this.id, 
    required this.text, 
    required this.options, 
    required this.correctIndex
  });

  Map<String, dynamic> toPublicJson() => {
    'id': id,
    'text': text,
    'options': options,
  };
}