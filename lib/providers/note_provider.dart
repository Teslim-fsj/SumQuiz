import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:uuid/uuid.dart';
import '../models/local_note.dart';
import '../models/local_recording.dart';
import '../models/local_drawing_stroke.dart';
import '../services/local_database_service.dart';
import '../services/enhanced_ai_service.dart';
import '../services/recording_service.dart';
import '../services/speech_service.dart';
import '../services/usage_service.dart';
import '../services/transcript_recovery_service.dart';

enum NoteProcessingState { idle, recording, transcribing, generating, error }

class NoteProvider with ChangeNotifier {
  final LocalDatabaseService _localDb;
  final EnhancedAIService _aiService;
  final RecordingService _recordingService;
  final SpeechService _speechService;

  StreamSubscription? _speechSub;
  StreamSubscription? _partialSub;
  StreamSubscription? _speechErrorSub;
  final _transcriptChunkController = StreamController<String>.broadcast();
  Stream<String> get transcriptChunkStream => _transcriptChunkController.stream;

  /// Debounce timer for auto-saving content changes.
  Timer? _saveDebounce;

  final UsageService? _usageService;

  NoteProvider({
    required LocalDatabaseService localDb,
    required EnhancedAIService aiService,
    required RecordingService recordingService,
    required SpeechService speechService,
    UsageService? usageService,
  })  : _localDb = localDb,
        _aiService = aiService,
        _recordingService = recordingService,
        _speechService = speechService,
        _usageService = usageService {
    _initRecordingStreams();
    _initSpeechErrorStream();
  }

  // --- STATE ---
  NoteProcessingState _state = NoteProcessingState.idle;
  NoteProcessingState get state => _state;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  void clearError() {
    _errorMessage = '';
    _limitReached = false;
    if (_state == NoteProcessingState.error) {
      _state = NoteProcessingState.idle;
    }
    notifyListeners();
  }

  bool _limitReached = false;
  bool get limitReached => _limitReached;

  Duration _recordingDuration = Duration.zero;
  Duration get recordingDuration => _recordingDuration;

  LocalNote? _currentNote;
  LocalNote? get currentNote => _currentNote;

  final List<LocalRecording> _currentNoteRecordings = [];
  List<LocalRecording> get currentNoteRecordings =>
      List.unmodifiable(_currentNoteRecordings);

  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<List<LocalNote>>? _notesSub;
  StreamSubscription<List<LocalRecording>>? _recordingsSub;

  List<LocalNote> _allNotes = [];
  List<LocalNote> get allNotes => _allNotes;

  /// Whether STT is currently auto-restarting after a platform timeout.
  bool get isAutoRestarting =>
      _speechService.isActive && _state == NoteProcessingState.recording;

  /// Real-time amplitude stream (0.0 – 1.0) for waveform visualization.
  Stream<double> get amplitudeStream => _recordingService.amplitudeStream;

  void _initRecordingStreams() {
    _durationSub = _recordingService.durationStream.listen((duration) {
      _recordingDuration = duration;
      notifyListeners();
    });
  }

  void _initSpeechErrorStream() {
    _speechErrorSub = _speechService.errorStream.listen((error) {
      developer.log('Speech error emitted: $error', name: 'NoteProvider');
      _errorMessage = "Microphone Issue: $error";
      notifyListeners();
    });
  }

  // --- ACTIONS ---

  void watchNotes(String userId) {
    _notesSub?.cancel();
    _notesSub = _localDb.watchAllNotes(userId).listen((notes) {
      _allNotes = notes;
      notifyListeners();
    }, onError: (e) {
      developer.log('Error watching notes: $e', name: 'NoteProvider');
    });
  }

  Future<void> loadNote(String noteId) async {
    try {
      _currentNote = await _localDb.getNote(noteId);
      if (_currentNote != null) {
        _watchRecordings(noteId);
      }
      notifyListeners();
    } catch (e) {
      developer.log('Error loading note $noteId: $e', name: 'NoteProvider');
      _errorMessage = "Failed to load note data.";
      _state = NoteProcessingState.error;
      notifyListeners();
    }
  }

  void _watchRecordings(String noteId) {
    _recordingsSub?.cancel();
    _recordingsSub =
        _localDb.watchRecordingsForNote(noteId).listen((recordings) {
      _currentNoteRecordings.clear();
      _currentNoteRecordings.addAll(recordings);
      notifyListeners();
    }, onError: (e) {
      developer.log('Error watching recordings for note $noteId: $e',
          name: 'NoteProvider');
    });
  }

  void setCurrentNote(LocalNote? note) {
    _currentNote = note;
    if (note != null) {
      _watchRecordings(note.id);
    } else {
      _currentNoteRecordings.clear();
      _recordingsSub?.cancel();
    }
    notifyListeners();
  }

  Future<LocalNote> createNewNote(String userId) async {
    final note = LocalNote(
      id: const Uuid().v4(),
      userId: userId,
      title: 'New Note',
      content: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      strokes: [],
    );
    await _localDb.saveNote(note);
    setCurrentNote(note);
    return note;
  }

  Future<void> updateNoteTitle(String title) async {
    if (_currentNote == null) return;
    _currentNote =
        _currentNote!.copyWith(title: title, updatedAt: DateTime.now());
    await _localDb.saveNote(_currentNote!);
    notifyListeners();
  }

  Future<void> updateNoteContent(String content) async {
    if (_currentNote == null) return;
    _currentNote =
        _currentNote!.copyWith(content: content, updatedAt: DateTime.now());

    // Debounce saves to avoid thrashing disk on every keystroke.
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(seconds: 2), () async {
      if (_currentNote != null) {
        try {
          await _localDb.saveNote(_currentNote!);
          developer.log('Auto-saved note content', name: 'NoteProvider');
        } catch (e) {
          developer.log('Auto-save failed: $e', name: 'NoteProvider');
        }
      }
    });
    // Removed notifyListeners() to prevent rebuilding the editor and parent screen on every keystroke.
  }

  Future<void> deleteNote(String noteId) async {
    try {
      await _localDb.deleteNote(noteId);
      if (_currentNote?.id == noteId) {
        setCurrentNote(null);
      }
    } catch (e) {
      developer.log('Error deleting note $noteId: $e', name: 'NoteProvider');
    }
  }

  // --- HANDWRITING ACTIONS ---

  List<LocalDrawingStroke> get drawingStrokes => _currentNote?.strokes ?? [];

  Future<void> addDrawingStroke(LocalDrawingStroke stroke) async {
    if (_currentNote == null) return;

    final updatedStrokes = List<LocalDrawingStroke>.from(_currentNote!.strokes)
      ..add(stroke);
    _currentNote = _currentNote!.copyWith(
      strokes: updatedStrokes,
      updatedAt: DateTime.now(),
    );

    // We save to DB after each stroke for maximum data safety in production
    await _localDb.saveNote(_currentNote!);
    notifyListeners();
  }

  Future<void> undoLastStroke() async {
    if (_currentNote == null || _currentNote!.strokes.isEmpty) return;
    final updatedStrokes = List<LocalDrawingStroke>.from(_currentNote!.strokes)
      ..removeLast();
    _currentNote = _currentNote!
        .copyWith(strokes: updatedStrokes, updatedAt: DateTime.now());
    await _localDb.saveNote(_currentNote!);
    notifyListeners();
  }

  Future<void> clearStrokes() async {
    if (_currentNote == null) return;
    _currentNote =
        _currentNote!.copyWith(strokes: [], updatedAt: DateTime.now());
    await _localDb.saveNote(_currentNote!);
    notifyListeners();
  }

  // --- RECORDING ACTIONS ---

  final List<String> _liveInsights = [];
  List<String> get liveInsights => _liveInsights;

  String _livePartialTranscript = '';
  String get livePartialTranscript => _livePartialTranscript;

  String get liveTranscript => _livePartialTranscript.isNotEmpty
      ? _livePartialTranscript
      : (_liveInsights.isNotEmpty ? _liveInsights.last : '');

  Future<void> startRecording(String userId) async {
    if (userId.isEmpty) {
      _errorMessage = "Authentication required for recording.";
      _state = NoteProcessingState.error;
      notifyListeners();
      return;
    }

    if (_usageService != null) {
      try {
        final canProceed =
            await _usageService!.canPerformAction(userId, 'lecture');
        if (!canProceed) {
          developer.log('Limit reached for lecture', name: 'NoteProvider');
          _limitReached = true;
          // We don't set an ugly error string anymore, let UI handle UpgradeDialog
          _state = NoteProcessingState.idle;
          notifyListeners();
          return;
        }
      } catch (e) {
        developer.log('Usage check failed: $e', name: 'NoteProvider');
      }
    }

    if (_currentNote == null) {
      await createNewNote(userId);
    }

    try {
      _state = NoteProcessingState.recording; // Set early to show UI feedback
      _errorMessage = '';
      _liveInsights.clear();
      _livePartialTranscript = '';
      notifyListeners();

      await _recordingService.startRecording(userId);
      await _speechService.init();

      _speechSub?.cancel();
      _speechSub = _speechService.transcriptStream.listen((text) {
        if (text.trim().isEmpty) return;

        _liveInsights.add(text);
        _transcriptChunkController.add(text);
        _livePartialTranscript = ''; // Clear partial when committed

        // Save for recovery
        if (_currentNote != null) {
          TranscriptRecoveryService()
              .savePendingTranscript(_currentNote!.id, _liveInsights.join(" "));
        }

        notifyListeners();
      }, onError: (e) {
        developer.log('Speech stream error: $e', name: 'NoteProvider');
      });

      _partialSub = _speechService.partialStream.listen((text) {
        _livePartialTranscript = text;
        notifyListeners();
      }, onError: (e) {
        developer.log('Partial speech stream error: $e', name: 'NoteProvider');
      });

      await _speechService.startListening();
      developer.log('Lecture recording session started', name: 'NoteProvider');
    } catch (e) {
      developer.log('Failed to start recording: $e', name: 'NoteProvider');
      _errorMessage = "Could not access microphone. Please check permissions.";
      _clearRecordingState();
      notifyListeners();
    }
  }

  void _clearRecordingState() {
    _state = NoteProcessingState.idle;
    _recordingDuration = Duration.zero;
    _livePartialTranscript = '';
    _speechSub?.cancel();
    _partialSub?.cancel();
  }

  Future<void> stopRecording() async {
    if (_state != NoteProcessingState.recording) return;

    try {
      developer.log('Stopping lecture recording...', name: 'NoteProvider');
      await _speechService.stopListening();
      _speechSub?.cancel();
      _partialSub?.cancel();
      _livePartialTranscript = '';

      final path = await _recordingService.stopRecording();
      if (path != null && _currentNote != null) {
        final recording = LocalRecording(
          id: const Uuid().v4(),
          userId: _currentNote!.userId,
          noteId: _currentNote!.id,
          filePath: path,
          durationSeconds: _recordingDuration.inSeconds,
          createdAt: DateTime.now(),
        );
        await _localDb.saveRecording(recording);

        // Clear recovery data on success
        await TranscriptRecoveryService().clearRecovery(_currentNote!.id);

        // Record usage after successful capture
        final usage = _usageService;
        if (usage != null) {
          await usage.recordAction(_currentNote!.userId, 'lecture');
        }
        developer.log('Recording saved successfully: $path',
            name: 'NoteProvider');
      }

      _state = NoteProcessingState.idle;
      _recordingDuration = Duration.zero;
      _liveInsights.clear();
      notifyListeners();
    } catch (e) {
      developer.log('Error stopping recording: $e', name: 'NoteProvider');
      _errorMessage = "Failed to save the recording correctly.";
      _state = NoteProcessingState.error;
      notifyListeners();
    }
  }

  Future<void> transcribeRecording(LocalRecording recording) async {
    if (_state != NoteProcessingState.idle) return;

    _state = NoteProcessingState.transcribing;
    _errorMessage = '';
    notifyListeners();

    try {
      final transcript = await _aiService.transcribeRecording(
        filePath: recording.filePath,
        userId: recording.userId,
      );

      final updatedRecording = recording.copyWith(
        transcript: transcript,
        isTranscribed: true,
      );
      await _localDb.saveRecording(updatedRecording);

      _state = NoteProcessingState.idle;
      notifyListeners();
    } catch (e) {
      developer.log('Transcription failed for recording ${recording.id}: $e',
          name: 'NoteProvider');
      _errorMessage = "AI transcription failed. Please try again later.";
      _state = NoteProcessingState.error;
      notifyListeners();
    }
  }

  Future<String?> generateStudyMaterials(String userId) async {
    if (_currentNote == null || _currentNote!.content.isEmpty) return null;

    if (_usageService != null) {
      try {
        final canProceed =
            await _usageService!.canPerformAction(userId, 'generate');
        if (!canProceed) {
          developer.log('Limit reached for synthesis', name: 'NoteProvider');
          _limitReached = true;
          _state = NoteProcessingState.idle;
          notifyListeners();
          return null;
        }
      } catch (e) {
        developer.log('Usage check failed: $e', name: 'NoteProvider');
      }
    }

    _state = NoteProcessingState.generating;
    _errorMessage = '';
    notifyListeners();

    try {
      // Decode Quill Delta JSON -> plain text for AI consumption.
      // The stored content is a JSON-encoded Delta; we must extract
      // readable text so the AI doesn't receive raw JSON syntax.
      String plainText;
      try {
        final decoded = jsonDecode(_currentNote!.content);
        final doc = quill.Document.fromJson(decoded as List);
        plainText = doc.toPlainText().trim();
      } catch (_) {
        // Fallback: treat as raw plain text (legacy notes or live transcripts)
        plainText = _currentNote!.content.trim();
      }

      if (plainText.isEmpty) {
        _errorMessage = 'Note is empty. Add some content before synthesizing.';
        _state = NoteProcessingState.error;
        notifyListeners();
        return null;
      }

      final folderId = await _aiService.generateAndStoreOutputs(
        text: plainText,
        title: _currentNote!.title,
        requestedOutputs: ['summary', 'quiz', 'flashcards'],
        userId: userId,
        localDb: _localDb,
        onProgress: (msg) {
          developer.log('Generation progress: $msg', name: 'NoteProvider');
        },
      );
      // Record usage after successful generation
      final usage = _usageService;
      if (usage != null) {
        await usage.recordAction(userId, 'generate');
      }

      _state = NoteProcessingState.idle;
      notifyListeners();
      return folderId;
    } catch (e) {
      developer.log('AI synthesis failed: $e', name: 'NoteProvider');
      _errorMessage =
          "Failed to generate study materials. Check your connection.";
      _state = NoteProcessingState.error;
      notifyListeners();
      return null;
    }
  }

  // --- AUDIO ACTIONS ---

  /// Seek to a specific position during recording playback.
  Future<void> seekAudio(Duration time) async {
    try {
      await _recordingService.seek(time);
      notifyListeners();
    } catch (e) {
      developer.log('Seek failed: $e', name: 'NoteProvider');
    }
  }

  /// Play a specific recording file.
  Future<void> playRecording(LocalRecording recording) async {
    try {
      await _recordingService.play(recording.filePath);
    } catch (e) {
      developer.log('Playback failed: $e', name: 'NoteProvider');
      _errorMessage = "Playback error. File might be missing.";
      _state = NoteProcessingState.error;
      notifyListeners();
    }
  }

  /// Stop playback.
  Future<void> stopPlayback() async {
    await _recordingService.stopPlayer();
  }

  /// Delete a recording and its file from disk.
  Future<void> deleteRecording(String recordingId) async {
    try {
      final recording = _currentNoteRecordings.firstWhere(
        (r) => r.id == recordingId,
        orElse: () => throw Exception('Recording not found'),
      );
      await _recordingService.deleteRecordingFile(recording.filePath);
      await _localDb.deleteRecording(recordingId);
      notifyListeners();
    } catch (e) {
      developer.log('Deletion failed for recording $recordingId: $e',
          name: 'NoteProvider');
    }
  }

  void toggleBackLink(String id) {
    if (_currentNote == null) return;
    final links = List<String>.from(_currentNote!.backLinks);
    if (links.contains(id)) {
      links.remove(id);
    } else {
      links.add(id);
    }
    _currentNote = _currentNote!.copyWith(backLinks: links);
    _localDb.saveNote(_currentNote!);
    notifyListeners();
  }

  /// Force-save any pending debounced content.
  Future<void> flushPendingSave() async {
    _saveDebounce?.cancel();
    if (_currentNote != null) {
      try {
        await _localDb.saveNote(_currentNote!);
      } catch (e) {
        developer.log('Flush save failed: $e', name: 'NoteProvider');
      }
    }
  }

  @override
  void dispose() {
    // Safety: stop any active recording to prevent orphaned files.
    if (_state == NoteProcessingState.recording) {
      stopRecording();
    }
    _saveDebounce?.cancel();
    _durationSub?.cancel();
    _notesSub?.cancel();
    _recordingsSub?.cancel();
    _speechSub?.cancel();
    _partialSub?.cancel();
    _speechErrorSub?.cancel();
    _transcriptChunkController.close();
    super.dispose();
  }
}
