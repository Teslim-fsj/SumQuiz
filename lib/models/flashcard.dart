import 'package:uuid/uuid.dart';

class Flashcard {
  String id;
  String question;
  String answer;

  Flashcard({
    String? id,
    required this.question,
    required this.answer,
  }) : id = id ?? const Uuid().v4();

  factory Flashcard.fromMap(Map<String, dynamic> map) {
    return Flashcard(
      id: map['id'] as String?,
      question: map['question'] ?? '',
      answer: map['answer'] ?? '',
    );
  }

  factory Flashcard.from(Flashcard flashcard) {
    return Flashcard(
      id: flashcard.id,
      question: flashcard.question,
      answer: flashcard.answer,
    );
  }

  Flashcard copyWith({
    String? id,
    String? question,
    String? answer,
  }) {
    return Flashcard(
      id: id ?? this.id,
      question: question ?? this.question,
      answer: answer ?? this.answer,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'question': question,
      'answer': answer,
    };
  }
}
