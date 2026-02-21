import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sumquiz/models/quiz_question.dart';
import 'package:uuid/uuid.dart';

class Quiz {
  final String id;
  final String userId;
  final String title;
  final List<QuizQuestion> questions;
  final Timestamp timestamp;

  Quiz({
    String? id,
    required this.userId,
    required this.title,
    required this.questions,
    Timestamp? timestamp,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? Timestamp.now();

  Quiz copyWith({
    String? id,
    String? userId,
    String? title,
    List<QuizQuestion>? questions,
    Timestamp? timestamp,
  }) {
    return Quiz(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      questions: questions ?? this.questions,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  factory Quiz.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Quiz(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      questions: (data['questions'] as List<dynamic>? ?? [])
          .map((q) => QuizQuestion.fromMap(q))
          .toList(),
      timestamp: data['timestamp'] ?? Timestamp.now(),
    );
  }

  factory Quiz.fromMap(Map<String, dynamic> map) {
    return Quiz(
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      questions: (map['questions'] as List<dynamic>? ?? [])
          .map((q) => QuizQuestion.fromMap(q))
          .toList(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'questions': questions.map((q) => q.toFirestore()).toList(),
      'timestamp': timestamp,
    };
  }
}
