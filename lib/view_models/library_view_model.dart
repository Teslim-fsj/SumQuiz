import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import 'dart:developer' as developer;

import '../models/folder.dart';
import '../models/library_item.dart';
import '../services/local_database_service.dart';
import '../services/firestore_service.dart';
import '../services/sync_service.dart';

class LibraryViewModel with ChangeNotifier {
  final LocalDatabaseService localDb;
  final FirestoreService firestoreService;
  final SyncService syncService;
  final String userId;

  final _selectedFolderController = BehaviorSubject<Folder?>.seeded(null);
  Stream<Folder?> get selectedFolderStream => _selectedFolderController.stream;
  Folder? get selectedFolder => _selectedFolderController.value;

  final _isSyncing = BehaviorSubject<bool>.seeded(false);
  Stream<bool> get isSyncingStream => _isSyncing.stream;
  bool get isSyncing => _isSyncing.value;

  // Stream declarations
  late Stream<List<LibraryItem>> allItems$;
  late Stream<List<LibraryItem>> allSummaries$;
  late Stream<List<LibraryItem>> allQuizzes$;
  late Stream<List<LibraryItem>> allExams$;
  late Stream<List<LibraryItem>> allFlashcards$;
  late Stream<List<LibraryItem>> allNotes$;
  late Stream<List<LibraryItem>> allRecentlyViewed$;
  late Stream<List<Folder>> allFolders$;

  // Composite streams
  late Stream<List<LibraryItem>> studyPack$;

  LibraryViewModel({
    required this.localDb,
    required this.firestoreService,
    required this.syncService,
    required this.userId,
  }) {
    _initializeStreams();
    syncAllData();
  }

  void _initializeStreams() {
    // Folders stream
    allFolders$ = localDb.watchAllFolders(userId).shareReplay(maxSize: 1);

    // Create independent streams for each content type from the database
    final allSummariesFromDb$ = localDb
        .watchAllSummaries(userId)
        .map(
            (summaries) => summaries.map(LibraryItem.fromLocalSummary).toList())
        .shareReplay(maxSize: 1);

    final allQuizzesAndExamsFromDb$ = localDb
        .watchAllQuizzes(userId)
        .map((quizzes) => quizzes.map(LibraryItem.fromLocalQuiz).toList())
        .shareReplay(maxSize: 1);

    final allQuizzesFromDb$ = allQuizzesAndExamsFromDb$
        .map((items) =>
            items.where((i) => i.type == LibraryItemType.quiz).toList())
        .shareReplay(maxSize: 1);

    final allExamsFromDb$ = allQuizzesAndExamsFromDb$
        .map((items) =>
            items.where((i) => i.type == LibraryItemType.exam).toList())
        .shareReplay(maxSize: 1);

    final allFlashcardsFromDb$ = localDb
        .watchAllFlashcardSets(userId)
        .map((flashcards) =>
            flashcards.map(LibraryItem.fromLocalFlashcardSet).toList())
        .shareReplay(maxSize: 1);

    final allNotesFromDb$ = localDb
        .watchAllNotes(userId)
        .map((notes) => notes.map(LibraryItem.fromLocalNote).toList())
        .shareReplay(maxSize: 1);

    // Main tabs assignments
    allSummaries$ = allSummariesFromDb$;
    allQuizzes$ = allQuizzesFromDb$;
    allExams$ = allExamsFromDb$;
    allFlashcards$ = allFlashcardsFromDb$;
    allNotes$ = allNotesFromDb$;

    // Combine for "All" (notes, study packs, quizzes, flashcards, exams)
    allItems$ = Rx.combineLatest5<
        List<LibraryItem>,
        List<LibraryItem>,
        List<LibraryItem>,
        List<LibraryItem>,
        List<LibraryItem>,
        List<LibraryItem>>(
      allNotesFromDb$,
      allSummariesFromDb$,
      allQuizzesFromDb$,
      allFlashcardsFromDb$,
      allExamsFromDb$,
      (notes, summaries, quizzes, flashcards, exams) {
        final all = [...notes, ...summaries, ...quizzes, ...flashcards, ...exams];
        all.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return all;
      },
    ).shareReplay(maxSize: 1);

    // Study Pack combines summaries, quizzes, flashcards
    studyPack$ = Rx.combineLatest3<List<LibraryItem>, List<LibraryItem>,
            List<LibraryItem>, List<LibraryItem>>(
        allSummariesFromDb$,
        allQuizzesFromDb$,
        allFlashcardsFromDb$,
        (summaries, quizzes, flashcards) =>
            [...summaries, ...quizzes, ...flashcards]).shareReplay(maxSize: 1);

    allRecentlyViewed$ = allItems$.map((items) {
      final sorted = List<LibraryItem>.from(items);
      sorted.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return sorted.take(10).toList();
    }).shareReplay(maxSize: 1);
  }

  // Helper methods for folder-specific content
  Stream<List<LibraryItem>> getFolderItemsStream(String folderId) {
    return localDb.watchContentIdsInFolder(folderId).switchMap((contentIds) {
      return Rx.combineLatest3<List<LibraryItem>, List<LibraryItem>,
          List<LibraryItem>, List<LibraryItem>>(
        localDb.watchAllSummaries(userId).map((summaries) => summaries
            .where((s) => contentIds.contains(s.id))
            .map(LibraryItem.fromLocalSummary)
            .toList()),
        localDb.watchAllQuizzes(userId).map((quizzes) => quizzes
            .where((q) => contentIds.contains(q.id))
            .map(LibraryItem.fromLocalQuiz)
            .toList()),
        localDb.watchAllFlashcardSets(userId).map((flashcards) => flashcards
            .where((f) => contentIds.contains(f.id))
            .map(LibraryItem.fromLocalFlashcardSet)
            .toList()),
        (summaries, quizzes, flashcards) =>
            [...summaries, ...quizzes, ...flashcards],
      );
    });
  }

  // New method for consolidated folder content
  Stream<List<LibraryItem>> getFolderStudyPackStream(String folderId) {
    return localDb.watchContentIdsInFolder(folderId).switchMap((contentIds) {
      return Rx.combineLatest3<List<LibraryItem>, List<LibraryItem>,
          List<LibraryItem>, List<LibraryItem>>(
        localDb.watchAllSummaries(userId).map((summaries) => summaries
            .where((s) => contentIds.contains(s.id))
            .map(LibraryItem.fromLocalSummary)
            .toList()),
        localDb.watchAllQuizzes(userId).map((quizzes) => quizzes
            .where((q) => contentIds.contains(q.id) && !q.isExam)
            .map(LibraryItem.fromLocalQuiz)
            .toList()),
        localDb.watchAllFlashcardSets(userId).map((flashcards) => flashcards
            .where((f) => contentIds.contains(f.id))
            .map(LibraryItem.fromLocalFlashcardSet)
            .toList()),
        (summaries, quizzes, flashcards) =>
            [...summaries, ...quizzes, ...flashcards],
      );
    });
  }

  Stream<List<LibraryItem>> getFolderSummariesStream(String folderId) {
    return localDb.watchContentIdsInFolder(folderId).switchMap((contentIds) {
      return localDb.watchAllSummaries(userId).map((summaries) {
        return summaries
            .where((summary) => contentIds.contains(summary.id))
            .map(LibraryItem.fromLocalSummary)
            .toList();
      });
    });
  }

  Stream<List<LibraryItem>> getFolderQuizzesStream(String folderId) {
    return localDb.watchContentIdsInFolder(folderId).switchMap((contentIds) {
      return localDb.watchAllQuizzes(userId).map((quizzes) {
        return quizzes
            .where((quiz) => contentIds.contains(quiz.id) && !quiz.isExam)
            .map(LibraryItem.fromLocalQuiz)
            .toList();
      });
    });
  }

  Stream<List<LibraryItem>> getFolderExamsStream(String folderId) {
    return localDb.watchContentIdsInFolder(folderId).switchMap((contentIds) {
      return localDb.watchAllQuizzes(userId).map((quizzes) {
        return quizzes
            .where((quiz) => contentIds.contains(quiz.id) && quiz.isExam)
            .map(LibraryItem.fromLocalQuiz)
            .toList();
      });
    });
  }

  Stream<List<LibraryItem>> getFolderFlashcardsStream(String folderId) {
    return localDb.watchContentIdsInFolder(folderId).switchMap((contentIds) {
      return localDb.watchAllFlashcardSets(userId).map((flashcardSets) {
        return flashcardSets
            .where((set) => contentIds.contains(set.id))
            .map(LibraryItem.fromLocalFlashcardSet)
            .toList();
      });
    });
  }

  Stream<List<LibraryItem>> getFolderNotesStream(String folderId) {
    return localDb.watchContentIdsInFolder(folderId).switchMap((contentIds) {
      return localDb.watchAllNotes(userId).map((notes) {
        return notes
            .where((note) => contentIds.contains(note.id))
            .map(LibraryItem.fromLocalNote)
            .toList();
      });
    });
  }

  void selectFolder(Folder? folder) {
    _selectedFolderController.add(folder);
  }

  Future<void> syncAllData() async {
    if (_isSyncing.value) return;
    _isSyncing.add(true);
    notifyListeners();

    try {
      await syncService.syncAllData();
    } catch (e, s) {
      developer.log('Error during sync',
          name: 'LibraryViewModel', error: e, stackTrace: s);
    } finally {
      _isSyncing.add(false);
      notifyListeners();
    }
  }

  Future<void> deleteItem(LibraryItem item) async {
    try {
      switch (item.type) {
        case LibraryItemType.summary:
          await localDb.deleteSummary(item.id);
          break;
        case LibraryItemType.quiz:
        case LibraryItemType.exam:
          await localDb.deleteQuiz(item.id);
          break;
        case LibraryItemType.flashcards:
          await localDb.deleteFlashcardSet(item.id);
          break;
        case LibraryItemType.note:
          await localDb.deleteNote(item.id);
          break;
        case LibraryItemType.folder:
          await localDb.deleteFolder(item.id);
          break;
      }
      await firestoreService.deleteItem(userId, item);
    } catch (e, s) {
      developer.log('Error deleting item',
          name: 'LibraryViewModel', error: e, stackTrace: s);
    }
  }

  Future<void> renameItem(LibraryItem item, String newTitle) async {
    try {
      switch (item.type) {
        case LibraryItemType.summary:
          final s = await localDb.getSummary(item.id);
          if (s != null) {
            s.title = newTitle;
            await localDb.saveSummary(s);
          }
          break;
        case LibraryItemType.quiz:
        case LibraryItemType.exam:
          final q = await localDb.getQuiz(item.id);
          if (q != null) {
            q.title = newTitle;
            await localDb.saveQuiz(q);
          }
          break;
        case LibraryItemType.flashcards:
          final f = await localDb.getFlashcardSet(item.id);
          if (f != null) {
            f.title = newTitle;
            await localDb.saveFlashcardSet(f);
          }
          break;
        case LibraryItemType.note:
          final n = await localDb.getNote(item.id);
          if (n != null) {
            n.title = newTitle;
            await localDb.saveNote(n);
          }
          break;
        case LibraryItemType.folder:
          final folder = await localDb.getFolder(item.id);
          if (folder != null) {
            folder.name = newTitle;
            folder.updatedAt = DateTime.now();
            await localDb.saveFolder(folder);
          }
          break;
      }
    } catch (e, s) {
      developer.log('Error renaming item',
          name: 'LibraryViewModel', error: e, stackTrace: s);
    }
  }

  @override
  void dispose() {
    _selectedFolderController.close();
    _isSyncing.close();
    super.dispose();
  }
}
