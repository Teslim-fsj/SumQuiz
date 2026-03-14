import 'package:sumquiz/models/local_quiz_question.dart';

class QuizQuestion {
  String question;
  List<String> options;
  String correctAnswer;

  final String? explanation;
  final String? questionType;

  QuizQuestion({
    required this.question,
    required this.options,
    required this.correctAnswer,
    this.explanation,
    this.questionType,
  });

  factory QuizQuestion.fromMap(Map<String, dynamic> map) {
    return QuizQuestion(
      question: map['question'] ?? '',
      options: List<String>.from(map['options'] ?? []),
      correctAnswer: map['correctAnswer'] ?? '',
      explanation: map['explanation'],
      questionType: map['questionType'],
    );
  }

  factory QuizQuestion.from(QuizQuestion question) {
    return QuizQuestion(
      question: question.question,
      options: List<String>.from(question.options),
      correctAnswer: question.correctAnswer,
      explanation: question.explanation,
      questionType: question.questionType,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'question': question,
      'options': options,
      'correctAnswer': correctAnswer,
      'explanation': explanation,
      'questionType': questionType,
    };
  }

  LocalQuizQuestion toLocalQuizQuestion() {
    return LocalQuizQuestion(
      question: question,
      options: options,
      correctAnswer: correctAnswer,
      explanation: explanation,
      questionType: questionType,
    );
  }
}
