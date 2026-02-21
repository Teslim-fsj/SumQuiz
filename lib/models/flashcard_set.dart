import 'package:cloud_firestore/cloud_firestore.dart';
import 'flashcard.dart';

class FlashcardSet {
  final String id;
  final String title;
  final List<Flashcard> flashcards;
  final Timestamp timestamp;

  FlashcardSet({
    this.id = '', // Make the ID optional with a default value
    required this.title,
    required this.flashcards,
    required this.timestamp,
  });

  FlashcardSet copyWith({
    String? id,
    String? title,
    List<Flashcard>? flashcards,
    Timestamp? timestamp,
  }) {
    return FlashcardSet(
      id: id ?? this.id,
      title: title ?? this.title,
      flashcards: flashcards ?? this.flashcards,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  factory FlashcardSet.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return FlashcardSet(
      id: doc.id,
      title: data['title'] ?? '',
      flashcards: (data['flashcards'] as List)
          .map((flashcard) => Flashcard.fromMap(flashcard))
          .toList(),
      timestamp: data['timestamp'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'flashcards':
          flashcards.map((flashcard) => flashcard.toFirestore()).toList(),
      'timestamp': timestamp,
    };
  }
}
