import 'package:sumquiz/models/local_quiz_question.dart';

class QuizQuestion {
  String question;
  List<String> options;
  String correctAnswer;

  QuizQuestion({
    required this.question,
    required this.options,
    required this.correctAnswer,
  });

  factory QuizQuestion.fromMap(Map<String, dynamic> map) {
    return QuizQuestion(
      question: map['question'] ?? '',
      options: List<String>.from(map['options'] ?? []),
      correctAnswer: map['correctAnswer'] ?? '',
    );
  }

  factory QuizQuestion.from(QuizQuestion question) {
    return QuizQuestion(
      question: question.question,
      options: List<String>.from(question.options),
      correctAnswer: question.correctAnswer,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'question': question,
      'options': options,
      'correctAnswer': correctAnswer,
    };
  }

  LocalQuizQuestion toLocalQuizQuestion() {
    return LocalQuizQuestion(
      question: question,
      options: options,
      correctAnswer: correctAnswer,
    );
  }
}
