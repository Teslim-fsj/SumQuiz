import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:async';
import 'dart:io';

import '../models/local_summary.dart';
import '../models/local_quiz.dart';
import '../models/local_quiz_question.dart';
import '../models/local_flashcard.dart';
import '../models/local_flashcard_set.dart';
import '../models/folder.dart';
import '../models/content_folder.dart';
import '../models/spaced_repetition.dart';
import '../models/daily_mission.dart';
import '../models/local_note.dart';
import '../models/local_recording.dart';
import '../models/mastery/topic_node.dart';
import '../models/local_drawing_stroke.dart';
import '../models/sumi_message.dart';
import '../models/mastery/mastery_history.dart';

class LocalDatabaseService {
  // Box names
  static const String _summariesBoxName = 'summaries';
  static const String _quizzesBoxName = 'quizzes';
  static const String _flashcardSetsBoxName = 'flashcardSets';
  static const String _foldersBoxName = 'folders';
  static const String _contentFoldersBoxName = 'contentFolders';
  static const String _spacedRepetitionBoxName = 'spaced_repetition';
  static const String _dailyMissionsBoxName = 'daily_missions';
  static const String _settingsBoxName = 'settings';
  static const String _notesBoxName = 'notes';
  static const String _recordingsBoxName = 'recordings';
  static const String _topicsBoxName = 'topics';
  static const String _chatBoxName = 'sumi_chat';
  static const String _historyBoxName = 'mastery_history';

  // Hive Boxes - late initialized
  late Box<LocalSummary> _summariesBox;
  late Box<LocalQuiz> _quizzesBox;
  late Box<LocalFlashcardSet> _flashcardSetsBox;
  late Box<Folder> _foldersBox;
  late Box<ContentFolder> _contentFoldersBox;
  late Box<SpacedRepetitionItem> _spacedRepetitionBox;
  late Box<DailyMission> _dailyMissionsBox;
  late Box<LocalNote> _notesBox;
  late Box<LocalRecording> _recordingsBox;
  late Box<TopicNode> _topicsBox;
  late Box<SumiMessage> _chatBox;
  late Box<MasteryHistory> _historyBox;
  late Box _settingsBox;

  // Singleton pattern
  static final LocalDatabaseService _instance =
      LocalDatabaseService._internal();
  factory LocalDatabaseService() => _instance;
  LocalDatabaseService._internal();

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      await Hive.initFlutter();

      // Register adapters only if they haven't been registered yet
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(LocalSummaryAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(LocalQuizAdapter());
      }
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(LocalQuizQuestionAdapter());
      }
      if (!Hive.isAdapterRegistered(3)) {
        Hive.registerAdapter(LocalFlashcardAdapter());
      }
      if (!Hive.isAdapterRegistered(4)) {
        Hive.registerAdapter(LocalFlashcardSetAdapter());
      }
      if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(FolderAdapter());
      if (!Hive.isAdapterRegistered(6)) {
        Hive.registerAdapter(ContentFolderAdapter());
      }
      if (!Hive.isAdapterRegistered(8)) {
        Hive.registerAdapter(SpacedRepetitionItemAdapter());
      }
      if (!Hive.isAdapterRegistered(21)) {
        Hive.registerAdapter(DailyMissionAdapter());
      }
      if (!Hive.isAdapterRegistered(22)) {
        Hive.registerAdapter(LocalNoteAdapter());
      }
      if (!Hive.isAdapterRegistered(23)) {
        Hive.registerAdapter(LocalRecordingAdapter());
      }
      if (!Hive.isAdapterRegistered(30)) {
        Hive.registerAdapter(TopicNodeAdapter());
      }
      if (!Hive.isAdapterRegistered(31)) {
        Hive.registerAdapter(LocalDrawingStrokeAdapter());
      }
      if (!Hive.isAdapterRegistered(32)) {
        Hive.registerAdapter(OffsetAdapter());
      }
      if (!Hive.isAdapterRegistered(33)) {
        Hive.registerAdapter(MessageRoleAdapter());
      }
      if (!Hive.isAdapterRegistered(34)) {
        Hive.registerAdapter(SumiMessageAdapter());
      }
      if (!Hive.isAdapterRegistered(35)) {
        Hive.registerAdapter(MasteryHistoryAdapter());
      }
      if (!Hive.isAdapterRegistered(36)) {
        Hive.registerAdapter(DurationAdapter());
      }

      // Open boxes
      _summariesBox = await Hive.openBox<LocalSummary>(_summariesBoxName);
      _quizzesBox = await Hive.openBox<LocalQuiz>(_quizzesBoxName);
      _flashcardSetsBox =
          await Hive.openBox<LocalFlashcardSet>(_flashcardSetsBoxName);
      _foldersBox = await Hive.openBox<Folder>(_foldersBoxName);
      _contentFoldersBox =
          await Hive.openBox<ContentFolder>(_contentFoldersBoxName);
      _spacedRepetitionBox =
          await Hive.openBox<SpacedRepetitionItem>(_spacedRepetitionBoxName);
      _dailyMissionsBox =
          await Hive.openBox<DailyMission>(_dailyMissionsBoxName);
      _notesBox = await Hive.openBox<LocalNote>(_notesBoxName);
      _recordingsBox = await Hive.openBox<LocalRecording>(_recordingsBoxName);
      _topicsBox = await Hive.openBox<TopicNode>(_topicsBoxName);
      _chatBox = await Hive.openBox<SumiMessage>(_chatBoxName);
      _historyBox = await Hive.openBox<MasteryHistory>(_historyBoxName);
      _settingsBox = await Hive.openBox(_settingsBoxName);

      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing local database: $e');
      rethrow;
    }
  }

  // --- WATCH METHODS ---

  Stream<List<MasteryHistory>> watchMasteryHistory(String userId) async* {
    await init();
    yield _historyBox.values.where((h) => h.userId == userId).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    await for (final _ in _historyBox.watch()) {
      yield _historyBox.values.where((h) => h.userId == userId).toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }
  }

  Stream<List<Folder>> watchAllFolders(String userId) async* {
    await init();
    yield _foldersBox.values.where((f) => f.userId == userId).toList();
    await for (final _ in _foldersBox.watch()) {
      yield _foldersBox.values.where((f) => f.userId == userId).toList();
    }
  }

  Stream<List<LocalSummary>> watchAllSummaries(String userId) async* {
    await init();
    yield _summariesBox.values.where((s) => s.userId == userId).toList();
    await for (final _ in _summariesBox.watch()) {
      yield _summariesBox.values.where((s) => s.userId == userId).toList();
    }
  }

  Stream<List<LocalQuiz>> watchAllQuizzes(String userId) async* {
    await init();
    yield _quizzesBox.values.where((q) => q.userId == userId).toList();
    await for (final _ in _quizzesBox.watch()) {
      yield _quizzesBox.values.where((q) => q.userId == userId).toList();
    }
  }

  Stream<List<LocalFlashcardSet>> watchAllFlashcardSets(String userId) async* {
    await init();
    yield _flashcardSetsBox.values.where((fs) => fs.userId == userId).toList();
    await for (final _ in _flashcardSetsBox.watch()) {
      yield _flashcardSetsBox.values
          .where((fs) => fs.userId == userId)
          .toList();
    }
  }

  Stream<List<SumiMessage>> watchChatHistory() async* {
    await init();
    yield _chatBox.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    await for (final _ in _chatBox.watch()) {
      yield _chatBox.values.toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }
  }

  Stream<List<LocalNote>> watchAllNotes(String userId) async* {
    await init();
    yield _notesBox.values.where((n) => n.userId == userId).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await for (final _ in _notesBox.watch()) {
      yield _notesBox.values.where((n) => n.userId == userId).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }
  }

  Stream<List<LocalRecording>> watchRecordingsForNote(String noteId) async* {
    await init();
    yield _recordingsBox.values.where((r) => r.noteId == noteId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await for (final _ in _recordingsBox.watch()) {
      yield _recordingsBox.values.where((r) => r.noteId == noteId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
  }

  Stream<List<String>> watchContentIdsInFolder(String folderId) async* {
    await init();
    yield _contentFoldersBox.values
        .where((cf) => cf.folderId == folderId)
        .map((cf) => cf.contentId)
        .toList();
    await for (final _ in _contentFoldersBox.watch()) {
      yield _contentFoldersBox.values
          .where((cf) => cf.folderId == folderId)
          .map((cf) => cf.contentId)
          .toList();
    }
  }

  // --- CRUD & SYNC OPERATIONS ---

  Future<void> saveSummary(LocalSummary summary, [String? folderId]) async {
    await init();
    await _summariesBox.put(summary.id, summary);
    if (folderId != null) {
      await assignContentToFolder(
          summary.id, folderId, 'summary', summary.userId);
    }
  }

  Future<void> saveQuiz(LocalQuiz quiz, [String? folderId]) async {
    await init();
    await _quizzesBox.put(quiz.id, quiz);
    if (folderId != null) {
      await assignContentToFolder(quiz.id, folderId, 'quiz', quiz.userId);
    }
  }

  Future<void> saveFlashcardSet(LocalFlashcardSet flashcardSet,
      [String? folderId]) async {
    await init();
    await _flashcardSetsBox.put(flashcardSet.id, flashcardSet);
    if (folderId != null) {
      await assignContentToFolder(
          flashcardSet.id, folderId, 'flashcardSet', flashcardSet.userId);
    }
  }

  Future<void> saveFolder(Folder folder) async {
    await init();
    await _foldersBox.put(folder.id, folder);
  }

  Future<void> saveNote(LocalNote note) async {
    await init();
    await _notesBox.put(note.id, note);
  }

  Future<void> saveRecording(LocalRecording recording) async {
    await init();
    await _recordingsBox.put(recording.id, recording);
  }

  Future<void> saveChatMessage(SumiMessage message) async {
    await init();
    await _chatBox.add(message);
  }

  Future<void> clearChatHistory() async {
    await init();
    await _chatBox.clear();
  }

  Future<void> saveMasteryHistory(MasteryHistory history) async {
    await init();
    await _historyBox.add(history);
  }

  Future<void> pruneHistory(String userId, int keepDays) async {
    await init();
    final threshold = DateTime.now().subtract(Duration(days: keepDays));
    
    final keysToDelete = _historyBox.keys.where((key) {
      final item = _historyBox.get(key);
      return item != null && item.userId == userId && item.timestamp.isBefore(threshold);
    }).toList();

    for (final key in keysToDelete) {
      await _historyBox.delete(key);
    }
    if (keysToDelete.isNotEmpty) {
      debugPrint('Pruned ${keysToDelete.length} history entries');
    }
  }

  Future<void> updateSummarySyncStatus(String id, bool isSynced) async {
    await init();
    final summary = _summariesBox.get(id);
    if (summary != null) {
      summary.isSynced = isSynced;
      await _summariesBox.put(id, summary);
    }
  }

  Future<void> updateQuizSyncStatus(String id, bool isSynced) async {
    await init();
    final quiz = _quizzesBox.get(id);
    if (quiz != null) {
      quiz.isSynced = isSynced;
      await _quizzesBox.put(id, quiz);
    }
  }

  Future<void> updateFlashcardSetSyncStatus(String id, bool isSynced) async {
    await init();
    final flashcardSet = _flashcardSetsBox.get(id);
    if (flashcardSet != null) {
      flashcardSet.isSynced = isSynced;
      await _flashcardSetsBox.put(id, flashcardSet);
    }
  }

  Future<void> updateNoteSyncStatus(String id, bool isSynced) async {
    await init();
    final note = _notesBox.get(id);
    if (note != null) {
      note.isSynced = isSynced;
      await _notesBox.put(id, note);
    }
  }

  Future<void> updateNoteLinks(String id, List<String> backLinks) async {
    await init();
    final note = _notesBox.get(id);
    if (note != null) {
      note.backLinks = backLinks;
      await _notesBox.put(id, note);
    }
  }

  // --- GETTERS ---

  Future<LocalSummary?> getSummary(String id) async {
    await init();
    return _summariesBox.get(id);
  }

  Future<List<LocalSummary>> getAllSummaries(String userId) async {
    await init();
    return _summariesBox.values.where((s) => s.userId == userId).toList();
  }

  Future<LocalQuiz?> getQuiz(String id) async {
    await init();
    return _quizzesBox.get(id);
  }

  Future<List<LocalQuiz>> getAllQuizzes(String userId) async {
    await init();
    return _quizzesBox.values.where((q) => q.userId == userId).toList();
  }

  Future<LocalFlashcardSet?> getFlashcardSet(String id) async {
    await init();
    return _flashcardSetsBox.get(id);
  }

  Future<List<LocalFlashcardSet>> getAllFlashcardSets(String userId) async {
    await init();
    return _flashcardSetsBox.values
        .where((set) => set.userId == userId)
        .toList();
  }

  Future<List<LocalNote>> getAllNotes(String userId) async {
    await init();
    return _notesBox.values.where((n) => n.userId == userId).toList();
  }

  Future<List<LocalFlashcard>> getFlashcardsByIds(
      String userId, List<String> cardIds) async {
    await init();
    final sets = await getAllFlashcardSets(userId);
    final allCards = sets.expand((s) => s.flashcards).toList();
    return allCards.where((c) => cardIds.contains(c.id)).toList();
  }

  Future<Folder?> getFolder(String id) async {
    await init();
    return _foldersBox.get(id);
  }

  Future<List<Folder>> getAllFolders(String userId) async {
    await init();
    return _foldersBox.values
        .where((folder) => folder.userId == userId)
        .toList();
  }

  Future<LocalNote?> getNote(String id) async {
    await init();
    return _notesBox.get(id);
  }

  Future<LocalNote?> getNoteByTitle(String userId, String title) async {
    await init();
    try {
      return _notesBox.values.firstWhere(
        (n) =>
            n.userId == userId && n.title.toLowerCase() == title.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<LocalRecording?> getRecording(String id) async {
    await init();
    return _recordingsBox.get(id);
  }

  // --- DELETERS ---

  Future<void> _removeContentRelations(String contentId) async {
    final relations = _contentFoldersBox.values
        .where((cf) => cf.contentId == contentId)
        .toList();
    for (final relation in relations) {
      await _contentFoldersBox.delete(relation.key);
    }
  }

  Future<void> deleteSummary(String id) async {
    await init();
    await _removeContentRelations(id);
    await _summariesBox.delete(id);
  }

  Future<void> deleteQuiz(String id) async {
    await init();
    await _removeContentRelations(id);
    await _quizzesBox.delete(id);
  }

  Future<void> deleteFlashcardSet(String id) async {
    await init();
    await _removeContentRelations(id);
    await _flashcardSetsBox.delete(id);
  }

  Future<void> deleteFolder(String id) async {
    await init();
    final relations =
        _contentFoldersBox.values.where((cf) => cf.folderId == id).toList();
    for (final relation in relations) {
      await _contentFoldersBox.delete(relation.key);
    }
    await _foldersBox.delete(id);
  }

  Future<void> deleteNote(String id) async {
    await init();
    final recordings =
        _recordingsBox.values.where((r) => r.noteId == id).toList();
    for (final r in recordings) {
      await deleteRecording(r.id);
    }
    await _notesBox.delete(id);
  }

  Future<void> deleteRecording(String id) async {
    await init();
    final rec = _recordingsBox.get(id);
    if (rec != null) {
      final file = File(rec.filePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await _recordingsBox.delete(id);
  }

  // --- RELATIONSHIP MANAGEMENT ---

  Future<void> assignContentToFolder(String contentId, String folderId,
      String contentType, String userId) async {
    await init();
    final key = '$folderId-$contentId';
    final contentFolder = ContentFolder(
      contentId: contentId,
      folderId: folderId,
      contentType: contentType,
      userId: userId,
      assignedAt: DateTime.now(),
    );
    await _contentFoldersBox.put(key, contentFolder);
  }

  Future<List<ContentFolder>> getFolderContents(String folderId) async {
    await init();
    return _contentFoldersBox.values
        .where((cf) => cf.folderId == folderId)
        .toList();
  }

  Future<List<ContentFolder>> getFolderContentsForUser(String userId) async {
    await init();
    return _contentFoldersBox.values
        .where((cf) => cf.userId == userId)
        .toList();
  }

  Future<String?> getParentFolderId(String contentId) async {
    await init();
    for (final cf in _contentFoldersBox.values) {
      if (cf.contentId == contentId) return cf.folderId;
    }
    return null;
  }

  // --- SPACED REPETITION & MISSIONS ---

  Box<SpacedRepetitionItem> getSpacedRepetitionBox() {
    return _spacedRepetitionBox;
  }

  Box<TopicNode> getTopicsBox() {
    return _topicsBox;
  }

  Future<DailyMission?> getDailyMission(String id) async {
    await init();
    return _dailyMissionsBox.get(id);
  }

  Future<void> saveDailyMission(DailyMission mission) async {
    await init();
    await _dailyMissionsBox.put(mission.id, mission);
  }

  // --- OTHER ---

  Future<bool> isOfflineModeEnabled() async {
    await init();
    return _settingsBox.get('offlineMode', defaultValue: false);
  }

  Future<void> setOfflineMode(bool isEnabled) async {
    await init();
    await _settingsBox.put('offlineMode', isEnabled);
  }

  Future<void> clearAllData() async {
    await init();
    await _summariesBox.clear();
    await _quizzesBox.clear();
    await _flashcardSetsBox.clear();
    await _foldersBox.clear();
    await _contentFoldersBox.clear();
    await _settingsBox.clear();
    await _spacedRepetitionBox.clear();
    await _dailyMissionsBox.clear();
  }
}
