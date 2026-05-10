import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/local_note.dart';
import '../models/local_recording.dart';
import '../models/local_drawing_stroke.dart';
import '../services/local_database_service.dart';
import '../services/enhanced_ai_service.dart';
import '../services/recording_service.dart';

enum NoteProcessingState { idle, recording, transcribing, generating, error }

class NoteProvider with ChangeNotifier {
  final LocalDatabaseService _localDb;
  final EnhancedAIService _aiService;
  final RecordingService _recordingService;

  NoteProvider({
    required LocalDatabaseService localDb,
    required EnhancedAIService aiService,
    required RecordingService recordingService,
  })  : _localDb = localDb,
        _aiService = aiService,
        _recordingService = recordingService {
    _initRecordingStreams();
  }

  // --- STATE ---
  NoteProcessingState _state = NoteProcessingState.idle;
  NoteProcessingState get state => _state;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

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

  void _initRecordingStreams() {
    _durationSub = _recordingService.durationStream.listen((duration) {
      _recordingDuration = duration;
      notifyListeners();
    });
  }

  // --- ACTIONS ---

  void watchNotes(String userId) {
    _notesSub?.cancel();
    _notesSub = _localDb.watchAllNotes(userId).listen((notes) {
      _allNotes = notes;
      notifyListeners();
    });
  }

  Future<void> loadNote(String noteId) async {
    _currentNote = await _localDb.getNote(noteId);
    if (_currentNote != null) {
      _watchRecordings(noteId);
    }
    notifyListeners();
  }

  void _watchRecordings(String noteId) {
    _recordingsSub?.cancel();
    _recordingsSub =
        _localDb.watchRecordingsForNote(noteId).listen((recordings) {
      _currentNoteRecordings.clear();
      _currentNoteRecordings.addAll(recordings);
      notifyListeners();
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
    await _localDb.saveNote(_currentNote!);
    notifyListeners();
  }

  Future<void> deleteNote(String noteId) async {
    await _localDb.deleteNote(noteId);
    if (_currentNote?.id == noteId) {
      setCurrentNote(null);
    }
  }

  // --- HANDWRITING ACTIONS ---

  List<LocalDrawingStroke> get drawingStrokes => _currentNote?.strokes ?? [];

  Future<void> addDrawingStroke(LocalDrawingStroke stroke) async {
    if (_currentNote == null) return;
    
    final updatedStrokes = List<LocalDrawingStroke>.from(_currentNote!.strokes)..add(stroke);
    _currentNote = _currentNote!.copyWith(
      strokes: updatedStrokes,
      updatedAt: DateTime.now(),
    );
    
    // We save to DB after each stroke for maximum data safety in production
    await _localDb.saveNote(_currentNote!);
    notifyListeners();
  }

  Future<void> clearStrokes() async {
    if (_currentNote == null) return;
    _currentNote = _currentNote!.copyWith(strokes: [], updatedAt: DateTime.now());
    await _localDb.saveNote(_currentNote!);
    notifyListeners();
  }

  // --- RECORDING ACTIONS ---

  List<String> _liveInsights = [];
  List<String> get liveInsights => _liveInsights;

  Timer? _insightTimer;

  String get liveTranscript => _liveInsights.isNotEmpty ? _liveInsights.last : '';

  Future<void> startRecording(String userId) async {
    if (_currentNote == null) {
      await createNewNote(userId);
    }

    try {
      await _recordingService.startRecording(userId);
      _state = NoteProcessingState.recording;
      _errorMessage = '';
      _liveInsights.clear();
      _startInsightSimulation();
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _state = NoteProcessingState.error;
      notifyListeners();
    }
  }

  void _startInsightSimulation() {
    _insightTimer?.cancel();
    _insightTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_state != NoteProcessingState.recording) {
        timer.cancel();
        return;
      }
      
      final phrases = [
        "Analyzing audio frequency...",
        "Detecting key educational concepts...",
        "Capturing core lecture points...",
        "Neural processing active...",
        "Sumi is listening and indexing...",
      ];
      
      _liveInsights.add(phrases[timer.tick % phrases.length]);
      notifyListeners();
    });
  }

  Future<void> stopRecording() async {
    if (_state != NoteProcessingState.recording) return;

    try {
      _insightTimer?.cancel();
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
      }
      _state = NoteProcessingState.idle;
      _recordingDuration = Duration.zero;
      _liveInsights.clear();
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
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
      _errorMessage = e.toString();
      _state = NoteProcessingState.error;
      notifyListeners();
    }
  }

  Future<void> generateStudyMaterials(String userId) async {
    if (_currentNote == null || _currentNote!.content.isEmpty) return;

    _state = NoteProcessingState.generating;
    _errorMessage = '';
    notifyListeners();

    try {
      await _aiService.generateAndStoreOutputs(
        text: _currentNote!.content,
        title: _currentNote!.title,
        requestedOutputs: ['summary', 'quiz', 'flashcards'],
        userId: userId,
        localDb: _localDb,
        onProgress: (msg) {
          developer.log('Generation progress: $msg', name: 'NoteProvider');
        },
      );
      _state = NoteProcessingState.idle;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _state = NoteProcessingState.error;
      notifyListeners();
    }
  }

  // --- AUDIO ACTIONS ---
  void seekAudio(Duration time) {
    // Integration with an audio player would go here
    notifyListeners();
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

  @override
  void dispose() {
    _durationSub?.cancel();
    _notesSub?.cancel();
    _recordingsSub?.cancel();
    super.dispose();
  }
}
