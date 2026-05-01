import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:async';
import '../models/local_note.dart';
import '../models/local_recording.dart';

class NoteService {
  static const String _notesBoxName = 'notes';
  static const String _recordingsBoxName = 'recordings';

  late Box<LocalNote> _notesBox;
  late Box<LocalRecording> _recordingsBox;

  static final NoteService _instance = NoteService._internal();
  factory NoteService() => _instance;
  NoteService._internal();

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      await Hive.initFlutter();

      if (!Hive.isAdapterRegistered(22)) {
        Hive.registerAdapter(LocalNoteAdapter());
      }
      if (!Hive.isAdapterRegistered(23)) {
        Hive.registerAdapter(LocalRecordingAdapter());
      }

      _notesBox = await Hive.openBox<LocalNote>(_notesBoxName);
      _recordingsBox = await Hive.openBox<LocalRecording>(_recordingsBoxName);

      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing note database: $e');
      rethrow;
    }
  }

  // --- NOTES CRUD ---

  Stream<List<LocalNote>> watchAllNotes(String userId) async* {
    await init();
    yield _notesBox.values.where((n) => n.userId == userId).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    
    await for (final _ in _notesBox.watch()) {
      yield _notesBox.values.where((n) => n.userId == userId).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }
  }

  Future<void> saveNote(LocalNote note) async {
    await init();
    await _notesBox.put(note.id, note);
  }

  Future<LocalNote?> getNote(String id) async {
    await init();
    return _notesBox.get(id);
  }

  Future<void> deleteNote(String id) async {
    await init();
    // Delete associated recordings first
    final associatedRecordings = _recordingsBox.values.where((r) => r.noteId == id).toList();
    for (final rec in associatedRecordings) {
      await deleteRecording(rec.id);
    }
    await _notesBox.delete(id);
  }

  // --- RECORDINGS CRUD ---

  Stream<List<LocalRecording>> watchRecordingsForNote(String noteId) async* {
    await init();
    yield _recordingsBox.values.where((r) => r.noteId == noteId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    await for (final _ in _recordingsBox.watch()) {
      yield _recordingsBox.values.where((r) => r.noteId == noteId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
  }

  Future<void> saveRecording(LocalRecording recording) async {
    await init();
    await _recordingsBox.put(recording.id, recording);
  }

  Future<LocalRecording?> getRecording(String id) async {
    await init();
    return _recordingsBox.get(id);
  }

  Future<void> deleteRecording(String id) async {
    await init();
    await _recordingsBox.delete(id);
    // Note: Actual file deletion should be handled by RecordingService or here
  }

  Future<void> updateNoteSyncStatus(String id, bool isSynced) async {
    await init();
    final note = _notesBox.get(id);
    if (note != null) {
      note.isSynced = isSynced;
      await _notesBox.put(id, note);
    }
  }
}
