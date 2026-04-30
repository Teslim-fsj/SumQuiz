import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'local_database_service.dart';
import '../models/local_summary.dart';
import '../models/local_quiz.dart';
import '../models/local_flashcard_set.dart';
import '../models/summary_model.dart';
import '../models/quiz_model.dart';
import '../models/flashcard.dart';
import '../models/flashcard_set.dart';
import '../models/quiz_question.dart';
import '../models/local_quiz_question.dart';
import '../models/local_flashcard.dart';
import '../models/folder.dart';
import '../models/content_folder.dart';
import 'dart:developer' as developer;

class SyncService {
  final LocalDatabaseService _localDb;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  SyncService(this._localDb);

  Future<void> syncOnLogin() async {
    final user = _auth.currentUser;
    if (user == null) return;

    if (await isConnected()) {
      developer.log('User is online, starting sync...', name: 'SyncService');
      await syncAllData();
    } else {
      developer.log('User is offline, skipping sync.', name: 'SyncService');
    }
  }

  Future<void> syncAllData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _syncSummaries(user.uid);
      await _syncQuizzes(user.uid);
      await _syncFlashcardSets(user.uid);
      await _syncFolders(user.uid);
      await _syncContentRelations(user.uid);
    } catch (e, s) {
      developer.log('Error during sync',
          name: 'SyncService', error: e, stackTrace: s);
    }
  }

  Future<void> _syncSummaries(String userId) async {
    final localSummaries = await _localDb.getAllSummaries(userId);
    final unsyncedSummaries = localSummaries.where((s) => !s.isSynced).toList();

    for (final localSummary in unsyncedSummaries) {
      try {
        final summary = Summary(
          id: localSummary.id,
          userId: userId,
          title: localSummary.title,
          content: localSummary.content,
          tags: localSummary.tags,
          timestamp: Timestamp.fromDate(localSummary.timestamp),
        );

        await _firestore
            .collection('users')
            .doc(userId)
            .collection('summaries')
            .doc(localSummary.id)
            .set(summary.toFirestore());

        await _localDb.updateSummarySyncStatus(localSummary.id, true);
      } catch (e, s) {
        developer.log('Error syncing summary ${localSummary.id}',
            name: 'SyncService', error: e, stackTrace: s);
      }
    }

    final firestoreSummaries = await _firestore
        .collection('users')
        .doc(userId)
        .collection('summaries')
        .get();

    for (final doc in firestoreSummaries.docs) {
      final localSummary = await _localDb.getSummary(doc.id);
      if (localSummary == null) {
        final summary = Summary.fromFirestore(doc);
        final newLocalSummary = LocalSummary(
          id: summary.id,
          userId: userId,
          title: summary.title,
          content: summary.content,
          tags: summary.tags,
          timestamp: summary.timestamp.toDate(),
          isSynced: true,
        );
        await _localDb.saveSummary(newLocalSummary);
      } else {
        final firestoreSummary = Summary.fromFirestore(doc);
        if (firestoreSummary.timestamp
            .toDate()
            .isAfter(localSummary.timestamp)) {
          localSummary.title = firestoreSummary.title;
          localSummary.content = firestoreSummary.content;
          localSummary.tags = firestoreSummary.tags;
          localSummary.timestamp = firestoreSummary.timestamp.toDate();
          localSummary.isSynced = true;
          await _localDb.saveSummary(localSummary);
        }
      }
    }
  }

  Future<void> _syncQuizzes(String userId) async {
    final localQuizzes = await _localDb.getAllQuizzes(userId);
    final unsyncedQuizzes = localQuizzes.where((q) => !q.isSynced).toList();

    for (final localQuiz in unsyncedQuizzes) {
      try {
        final quiz = Quiz(
          id: localQuiz.id,
          userId: userId,
          title: localQuiz.title,
          questions: localQuiz.questions
              .map((q) => QuizQuestion(
                    question: q.question,
                    options: q.options,
                    correctAnswer: q.correctAnswer,
                    explanation: q.explanation,
                    questionType: q.questionType,
                  ))
              .toList(),
          timestamp: Timestamp.fromDate(localQuiz.timestamp),
          isExam: localQuiz.isExam,
        );

        await _firestore
            .collection('users')
            .doc(userId)
            .collection('quizzes')
            .doc(localQuiz.id)
            .set(quiz.toFirestore());

        await _localDb.updateQuizSyncStatus(localQuiz.id, true);
      } catch (e, s) {
        developer.log('Error syncing quiz ${localQuiz.id}',
            name: 'SyncService', error: e, stackTrace: s);
      }
    }

    final firestoreQuizzes = await _firestore
        .collection('users')
        .doc(userId)
        .collection('quizzes')
        .get();

    for (final doc in firestoreQuizzes.docs) {
      final localQuiz = await _localDb.getQuiz(doc.id);
      if (localQuiz == null) {
        final quiz = Quiz.fromFirestore(doc);
        final newLocalQuiz = LocalQuiz(
          id: quiz.id,
          userId: userId,
          title: quiz.title,
          questions: quiz.questions
              .map((q) => LocalQuizQuestion(
                    question: q.question,
                    options: q.options,
                    correctAnswer: q.correctAnswer,
                    explanation: q.explanation,
                    questionType: q.questionType,
                  ))
              .toList(),
          timestamp: quiz.timestamp.toDate(),
          isSynced: true,
          isExam: quiz.isExam,
        );
        await _localDb.saveQuiz(newLocalQuiz);
      } else {
        final firestoreQuiz = Quiz.fromFirestore(doc);
        if (firestoreQuiz.timestamp.toDate().isAfter(localQuiz.timestamp)) {
          localQuiz.title = firestoreQuiz.title;
          localQuiz.questions = firestoreQuiz.questions
              .map((q) => LocalQuizQuestion(
                    question: q.question,
                    options: q.options,
                    correctAnswer: q.correctAnswer,
                    explanation: q.explanation,
                    questionType: q.questionType,
                  ))
              .toList();
          localQuiz.timestamp = firestoreQuiz.timestamp.toDate();
          localQuiz.isSynced = true;
          localQuiz.isExam = firestoreQuiz.isExam;
          await _localDb.saveQuiz(localQuiz);
        }
      }
    }
  }

  Future<void> _syncFlashcardSets(String userId) async {
    final localFlashcardSets = await _localDb.getAllFlashcardSets(userId);
    final unsyncedFlashcardSets =
        localFlashcardSets.where((fs) => !fs.isSynced).toList();

    for (final localFlashcardSet in unsyncedFlashcardSets) {
      try {
        final flashcardSet = FlashcardSet(
          id: localFlashcardSet.id,
          title: localFlashcardSet.title,
          flashcards: localFlashcardSet.flashcards
              .map((f) => Flashcard(
                    id: f.id,
                    question: f.question,
                    answer: f.answer,
                  ))
              .toList(),
          timestamp: Timestamp.fromDate(localFlashcardSet.timestamp),
        );

        await _firestore
            .collection('users')
            .doc(userId)
            .collection('flashcard_sets')
            .doc(localFlashcardSet.id)
            .set(flashcardSet.toFirestore());

        await _localDb.updateFlashcardSetSyncStatus(localFlashcardSet.id, true);
      } catch (e, s) {
        developer.log('Error syncing flashcard set ${localFlashcardSet.id}',
            name: 'SyncService', error: e, stackTrace: s);
      }
    }

    final firestoreFlashcardSets = await _firestore
        .collection('users')
        .doc(userId)
        .collection('flashcard_sets')
        .get();

    for (final doc in firestoreFlashcardSets.docs) {
      final localFlashcardSet = await _localDb.getFlashcardSet(doc.id);
      if (localFlashcardSet == null) {
        final flashcardSet = FlashcardSet.fromFirestore(doc);
        final newLocalFlashcardSet = LocalFlashcardSet(
          id: flashcardSet.id,
          userId: userId,
          title: flashcardSet.title,
          flashcards: flashcardSet.flashcards
              .map((f) => LocalFlashcard(
                    id: f.id,
                    question: f.question,
                    answer: f.answer,
                  ))
              .toList(),
          timestamp: flashcardSet.timestamp.toDate(),
          isSynced: true,
        );
        await _localDb.saveFlashcardSet(newLocalFlashcardSet);
      } else {
        final firestoreFlashcardSet = FlashcardSet.fromFirestore(doc);
        if (firestoreFlashcardSet.timestamp
            .toDate()
            .isAfter(localFlashcardSet.timestamp)) {
          localFlashcardSet.title = firestoreFlashcardSet.title;
          localFlashcardSet.flashcards = firestoreFlashcardSet.flashcards
              .map((f) => LocalFlashcard(
                    id: f.id,
                    question: f.question,
                    answer: f.answer,
                  ))
              .toList();
          localFlashcardSet.timestamp =
              firestoreFlashcardSet.timestamp.toDate();
          localFlashcardSet.isSynced = true;
          await _localDb.saveFlashcardSet(localFlashcardSet);
        }
      }
    }
  }

  Future<void> _syncFolders(String userId) async {
    final localFolders = await _localDb.getAllFolders(userId);
    // Note: Folder model uses 'isSaved' as sync status
    final unsyncedFolders = localFolders.where((f) => !f.isSaved).toList();

    for (final localFolder in unsyncedFolders) {
      try {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('folders')
            .doc(localFolder.id)
            .set(localFolder.toFirestore());

        localFolder.isSaved = true;
        await _localDb.saveFolder(localFolder);
      } catch (e, s) {
        developer.log('Error syncing folder ${localFolder.id}',
            name: 'SyncService', error: e, stackTrace: s);
      }
    }

    final firestoreFolders = await _firestore
        .collection('users')
        .doc(userId)
        .collection('folders')
        .get();

    for (final doc in firestoreFolders.docs) {
      final localFolder = await _localDb.getFolder(doc.id);
      if (localFolder == null) {
        final newFolder = Folder.fromFirestore(doc.data(), doc.id);
        await _localDb.saveFolder(newFolder);
      } else {
        final firestoreFolderData = doc.data();
        final updatedAt =
            (firestoreFolderData['updatedAt'] as Timestamp?)?.toDate() ??
                DateTime.now();

        if (updatedAt.isAfter(localFolder.updatedAt)) {
          localFolder.name = firestoreFolderData['name'] ?? localFolder.name;
          localFolder.updatedAt = updatedAt;
          localFolder.isSaved = true;
          await _localDb.saveFolder(localFolder);
        }
      }
    }
  }

  Future<void> _syncContentRelations(String userId) async {
    // Relationships are unique by their key '$folderId-$contentId'
    // We fetch all relations from cloud and merge with local
    final firestoreRelations = await _firestore
        .collection('users')
        .doc(userId)
        .collection('content_folders')
        .get();

    for (final doc in firestoreRelations.docs) {
      final relation = ContentFolder.fromFirestore(doc.data());
      await _localDb.assignContentToFolder(
        relation.contentId,
        relation.folderId,
        relation.contentType,
        userId,
      );
    }

    // Push local relations to cloud
    final localRelations = await _localDb.getFolderContentsForUser(userId);
    for (final relation in localRelations) {
      try {
        final key = '${relation.folderId}-${relation.contentId}';
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('content_folders')
            .doc(key)
            .set(relation.toFirestore());
      } catch (e) {
        developer.log('Error syncing relation', name: 'SyncService', error: e);
      }
    }
  }

  Future<bool> isConnected() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return !connectivityResult.contains(ConnectivityResult.none);
  }
}
