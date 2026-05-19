import 'dart:async';
import 'dart:typed_data';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:sumquiz/models/extraction_result.dart';
import 'package:sumquiz/services/content_extraction_service.dart';
import 'package:sumquiz/services/enhanced_ai_service.dart';
import 'package:sumquiz/services/local_database_service.dart';
import 'package:sumquiz/services/usage_service.dart';
import 'package:sumquiz/utils/cancellation_token.dart';
import 'package:sumquiz/utils/youtube_pro_gate.dart';
import 'package:uuid/uuid.dart';
import 'package:sumquiz/models/local_note.dart';
import 'package:sumquiz/services/notification_service.dart';
import 'package:sumquiz/services/notification_integration.dart';

enum CreationPhase {
  source,
  extractionReview,
  config,
  processing,
  success,
  error
}

enum StudyArchetype { sprinter, architect }

class CreateContentProvider with ChangeNotifier {
  final ContentExtractionService _extractionService;
  final EnhancedAIService _aiService;
  final LocalDatabaseService _localDb;
  final NotificationService _notificationService;

  final List<String> _studyTips = [
    "Sumi Tip: Active recall is 3x more effective than re-reading!",
    "Sumi Tip: Taking a 5-minute break every 25 minutes keeps your brain fresh.",
    "Sumi Tip: Try teaching this topic to a friend to master it.",
    "Sumi Tip: Your brain processes information better when you sleep well.",
    "Sumi Tip: Connect new concepts to things you already know.",
    "Sumi Tip: Spaced repetition is the secret to long-term memory.",
  ];

  Timer? _tipTimer;
  String _currentTip = '';
  String get currentTip => _currentTip;

  CreateContentProvider({
    required ContentExtractionService extractionService,
    required EnhancedAIService aiService,
    required LocalDatabaseService localDb,
    required NotificationService notificationService,
  })  : _extractionService = extractionService,
        _aiService = aiService,
        _localDb = localDb,
        _notificationService = notificationService;

  // --- STATE ---
  CreationPhase _phase = CreationPhase.source;
  CreationPhase get phase => _phase;

  String _selectedSourceType = '';
  String get selectedSourceType => _selectedSourceType;

  String? _fileName;
  String? get fileName => _fileName;

  Uint8List? _fileBytes;
  String? _mimeType;

  String _textContent = '';
  String get textContent => _textContent;

  String _selectedDifficulty = 'intermediate';
  String get selectedDifficulty => _selectedDifficulty;

  int _quizCount = 15;
  int get quizCount => _quizCount;

  int _flashcardCount = 15;
  int get flashcardCount => _flashcardCount;

  List<String> _selectedQuestionTypes = ['Multiple Choice'];
  List<String> get selectedQuestionTypes => _selectedQuestionTypes;

  StudyArchetype _selectedArchetype = StudyArchetype.architect;
  StudyArchetype get selectedArchetype => _selectedArchetype;

  String _progressMessage = '';
  String get progressMessage => _progressMessage;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  String _generatedFolderId = '';
  String get generatedFolderId => _generatedFolderId;

  ExtractionResult? _extractionResult;
  ExtractionResult? get extractionResult => _extractionResult;

  bool _saveAsNote = true;
  bool get saveAsNote => _saveAsNote;

  bool _isCancelled = false;
  CancellationToken? _cancelToken;
  String? _preSelectedFolderId;
  String? get preSelectedFolderId => _preSelectedFolderId;

  void setPreSelectedFolderId(String? folderId) {
    _preSelectedFolderId = folderId;
    notifyListeners();
  }

  // --- ACTIONS ---

  void setSource(String type,
      {String? fileName, Uint8List? bytes, String? mime, String? text}) {
    _selectedSourceType = type;
    _fileName = fileName;
    _fileBytes = bytes;
    _mimeType = mime;
    if (text != null) _textContent = text;

    _phase = CreationPhase.config;
    _errorMessage = '';
    notifyListeners();
  }

  void setExtractionResult(ExtractionResult result) {
    _extractionResult = result;
    _textContent = result.text;
    _fileName = result.suggestedTitle;
    _phase = CreationPhase.extractionReview;
    notifyListeners();
  }

  void updateExtractedText(String text) {
    _textContent = text;
    if (_extractionResult != null) {
      _extractionResult = ExtractionResult(
        text: text,
        suggestedTitle: _extractionResult!.suggestedTitle,
      );
    }
    notifyListeners();
  }

  void updateTitle(String title) {
    _fileName = title;
    notifyListeners();
  }

  void toggleSaveAsNote(bool value) {
    _saveAsNote = value;
    notifyListeners();
  }

  /// Immediately persists the extracted text as a note in the local database.
  /// Called by the UI at the moment the user confirms extraction review,
  /// before generation begins — ensuring the note is saved even if generation
  /// fails or is blocked by a usage limit.
  Future<void> saveNoteNow() async {
    if (!_saveAsNote) return;
    final title =
        _fileName ?? _extractionResult?.suggestedTitle ?? 'Untitled Note';
    final text = _textContent;
    if (text.trim().isEmpty) return;

    try {
      developer.log('saveNoteNow: saving note "$title"',
          name: 'CreateContentProvider');
      final note = LocalNote(
        id: const Uuid().v4(),
        userId: '', // Will be replaced by the caller if needed; stored locally
        title: title,
        content: text,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        folderId: _preSelectedFolderId,
        tags: [],
        isSynced: false,
      );
      await _localDb.saveNote(note);
      developer.log('saveNoteNow: success', name: 'CreateContentProvider');
    } catch (e) {
      developer.log('saveNoteNow failed: $e', name: 'CreateContentProvider');
      rethrow;
    }
  }

  void proceedToConfig() {
    _phase = CreationPhase.config;
    notifyListeners();
  }

  void updateConfig(
      {String? difficulty,
      int? quizCount,
      int? flashcardCount,
      List<String>? questionTypes,
      StudyArchetype? archetype}) {
    if (difficulty != null) _selectedDifficulty = difficulty;
    if (quizCount != null) _quizCount = quizCount;
    if (flashcardCount != null) _flashcardCount = flashcardCount;
    if (questionTypes != null) _selectedQuestionTypes = questionTypes;
    if (archetype != null) _selectedArchetype = archetype;
    notifyListeners();
  }

  Future<void> refineExtractedText() async {
    if (_textContent.isEmpty) return;

    _progressMessage = 'AI is cleaning up your text...';
    notifyListeners();

    try {
      final refined = await _aiService.refineContent(_textContent);
      if (refined.isNotEmpty) {
        updateExtractedText(refined);
      }
    } catch (e) {
      developer.log('Refinement error: $e');
    } finally {
      _progressMessage = '';
      notifyListeners();
    }
  }

  void toggleQuestionType(String type) {
    if (_selectedQuestionTypes.contains(type)) {
      if (_selectedQuestionTypes.length > 1) {
        _selectedQuestionTypes.remove(type);
      }
    } else {
      _selectedQuestionTypes.add(type);
    }
    notifyListeners();
  }

  void reset() {
    _cancelToken?.cancel();
    _phase = CreationPhase.source;
    _selectedSourceType = '';
    _fileName = null;
    _fileBytes = null;
    _mimeType = null;
    _textContent = '';
    _progressMessage = '';
    _errorMessage = '';
    _generatedFolderId = '';
    _isCancelled = false;
    _limitReached = false;
    _selectedQuestionTypes = ['Multiple Choice'];
    _selectedArchetype = StudyArchetype.architect;
    _extractionResult = null;
    _saveAsNote = true;
    _preSelectedFolderId = null;
    _stopTipRotation();
    notifyListeners();
  }

  void _startTipRotation() {
    _tipTimer?.cancel();
    _currentTip = _studyTips[DateTime.now().second % _studyTips.length];
    _tipTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _currentTip = _studyTips[timer.tick % _studyTips.length];
      notifyListeners();
    });
    notifyListeners();
  }

  void _stopTipRotation() {
    _tipTimer?.cancel();
    _tipTimer = null;
    _currentTip = '';
  }

  Future<void> startGeneration(String userId,
      {required bool allowYouTubeImport,
      required bool allowPdfImport,
      required bool allowWebImport}) async {
    if (_phase == CreationPhase.processing) return;

    // Phase 1: Extraction (Free, no CU cost yet)
    if (_extractionResult == null &&
        _selectedSourceType != 'text' &&
        _selectedSourceType != 'topic') {
      await extractContent(userId,
          allowYouTubeImport: allowYouTubeImport,
          allowPdfImport: allowPdfImport,
          allowWebImport: allowWebImport);
      return;
    }

    // Phase 2: Generation (Paid, costs CU)
    await generateStudyPack(userId);
  }

  Future<void> extractContent(String userId,
      {required bool allowYouTubeImport,
      required bool allowPdfImport,
      required bool allowWebImport}) async {
    _phase = CreationPhase.processing;
    _progressMessage = 'Preparing your content...';
    _errorMessage = '';
    _isCancelled = false;
    _startTipRotation();
    notifyListeners();

    _cancelToken = CancellationToken();
    final cancelToken = _cancelToken!;

    try {
      if (_selectedSourceType == 'youtube' && !allowYouTubeImport) {
        throw Exception(kYoutubeProRequiredMessage);
      }
      if (_selectedSourceType == 'pdf' && !allowPdfImport) {
        throw Exception(kPdfProRequiredMessage);
      }
      if (_selectedSourceType == 'link' && !allowWebImport) {
        throw Exception(kWebProRequiredMessage);
      }

      ExtractionResult? result;

      if (_selectedSourceType == 'youtube') {
        _progressMessage = 'Analyzing YouTube video...';
        notifyListeners();
        result = await _extractionService.extractContent(
          type: 'youtube',
          input: _textContent,
          userId: userId,
          allowYouTubeImport: allowYouTubeImport,
          allowPdfImport: allowPdfImport,
          allowWebImport: allowWebImport,
          cancelToken: cancelToken,
          onProgress: (msg) {
            _progressMessage = msg;
            notifyListeners();
          },
        );
      } else if (_fileBytes != null) {
        _progressMessage = 'Extracting content from your file...';
        notifyListeners();
        result = await _extractionService.extractContent(
          type: _selectedSourceType,
          input: _fileBytes!,
          userId: userId,
          mimeType: _mimeType,
          allowYouTubeImport: allowYouTubeImport,
          allowPdfImport: allowPdfImport,
          allowWebImport: allowWebImport,
          cancelToken: cancelToken,
          onProgress: (msg) {
            _progressMessage = msg;
            notifyListeners();
          },
        );
      } else if (_selectedSourceType == 'link') {
        _progressMessage = 'Analyzing webpage content...';
        notifyListeners();
        result = await _extractionService.extractContent(
          type: 'link',
          input: _textContent,
          userId: userId,
          allowYouTubeImport: allowYouTubeImport,
          allowPdfImport: allowPdfImport,
          allowWebImport: allowWebImport,
          cancelToken: cancelToken,
          onProgress: (msg) {
            _progressMessage = msg;
            notifyListeners();
          },
        );
      }

      if (result == null) {
        throw Exception('Failed to extract content. Please try again.');
      }

      _extractionResult = result;
      _textContent = result.text;
      _phase = CreationPhase.extractionReview;
      _progressMessage = '';
      _stopTipRotation();
      notifyListeners();
    } catch (e) {
      _handleError(e, cancelToken);
    }
  }

  Future<void> generateStudyPack(String userId) async {
    _phase = CreationPhase.processing;
    _progressMessage = 'Generating study materials...';
    _errorMessage = '';
    _isCancelled = false;
    _startTipRotation();
    notifyListeners();

    _cancelToken = CancellationToken();
    final cancelToken = _cancelToken!;

    final title =
        _fileName ?? _extractionResult?.suggestedTitle ?? 'Study Deck';
    final textToProcess = _textContent;
    final folderIdToUse = _preSelectedFolderId ?? const Uuid().v4();

    // 1. Gated Usage / Credit Unit Check (Pre-generation)
    final usageService = UsageService();
    try {
      final canProceed =
          await usageService.canPerformAction(userId, 'generate');
      if (!canProceed) {
        developer.log('Limit reached for synthesis',
            name: 'CreateContentProvider');
        _limitReached = true;
        // Don't show error view, revert to previous view so user can upgrade and retry
        _phase = _extractionResult != null
            ? CreationPhase.extractionReview
            : CreationPhase.source;
        _stopTipRotation();
        notifyListeners();
        return;
      }
    } catch (e) {
      developer.log('Usage check failed: $e', name: 'CreateContentProvider');
    }

    final startTime = DateTime.now();
    try {
      _progressMessage = 'Orchestrating neural compute...';
      notifyListeners();

      // 3. Fast-track for Topic generation
      if (_selectedSourceType == 'topic' &&
          _textContent.split(' ').length <= 8) {
        _progressMessage = 'Generating full study set from topic...';
        _generatedFolderId = await _aiService.generateFromTopic(
          topic: _textContent,
          userId: userId,
          localDb: _localDb,
          depth: _selectedDifficulty,
          quizCount: _quizCount,
          cardCount: _flashcardCount,
          questionTypes: _selectedQuestionTypes,
          onProgress: (msg) {
            _progressMessage = msg;
            notifyListeners();
          },
          cancelToken: cancelToken,
        );
        _phase = CreationPhase.success;
        _stopTipRotation();

        // Record usage on success
        try {
          await usageService.recordAction(userId, 'generate');
        } catch (e) {
          developer.log('Error recording topic generation usage: $e',
              name: 'CreateContentProvider');
        }

        notifyListeners();
        return;
      }

      // 4. Standard Generation Flow
      _generatedFolderId = await _aiService.generateAndStoreOutputs(
        text: textToProcess,
        title: title,
        requestedOutputs: ['summary', 'quiz', 'flashcards'],
        userId: userId,
        localDb: _localDb,
        difficulty: _selectedDifficulty,
        questionCount: _quizCount,
        cardCount: _flashcardCount,
        questionTypes: _selectedQuestionTypes,
        existingFolderId: folderIdToUse,
        onProgress: (msg) {
          _progressMessage = msg;
          notifyListeners();
        },
        cancelToken: cancelToken,
      );

      // 5. Validation Pass
      onProgress('Verifying neural artifacts...');
      final folderContents = await _localDb.getFolderContentsForUser(userId);
      final hasArtifacts =
          folderContents.any((c) => c.folderId == _generatedFolderId);
      if (!hasArtifacts) {
        throw Exception(
            'Generation completed but artifacts were not stored correctly.');
      }

      // Record usage on successful standard generation
      try {
        await usageService.recordAction(userId, 'generate');
      } catch (e) {
        developer.log('Error recording generation usage: $e',
            name: 'CreateContentProvider');
      }

      final duration = DateTime.now().difference(startTime);
      developer.log('Study pack generation SUCCESS in ${duration.inSeconds}s',
          name: 'CreateContentProvider');

      _progressMessage = ''; // Clear progress message
      _phase = CreationPhase.success;
      _stopTipRotation();

      // 6. Notifications
      NotificationIntegration.coreOnContentGenerated(
        notificationService: _notificationService,
        localDb: _localDb,
        userId: userId,
        topic: title,
      );

      notifyListeners();
    } catch (e) {
      _handleError(e, cancelToken);
    }
  }

  bool _limitReached = false;

  bool get isProcessing => _phase == CreationPhase.processing;
  bool get limitReached => _limitReached;

  void clearLimitReached() {
    _limitReached = false;
    notifyListeners();
  }

  void _handleError(dynamic e, CancellationToken cancelToken) {
    _stopTipRotation();
    if (cancelToken.isCancelled) {
      developer.log('Generation CANCELLED by user.',
          name: 'CreateContentProvider');
      _isCancelled = true;
      _phase = CreationPhase.source;
    } else {
      developer.log('NEURAL FAILURE in provider: $e',
          name: 'CreateContentProvider', error: e);
      final errorStr = e.toString();

      if (errorStr.contains('CAPACITY_STABILIZING') ||
          errorStr.contains('CAPACITY_DEPLETED')) {
        developer.log('Blocking generation: Capacity limits hit.',
            name: 'CreateContentProvider');
        _errorMessage =
            "Your neural momentum is currently stabilizing! Sumi suggests a quick 5-minute break while your learning circuits reset.";
        NotificationIntegration.coreOnUsageLimitHit(
          notificationService: _notificationService,
          localDb: _localDb,
        );
      } else if (errorStr.contains('SYSTEM_OVERLOADED')) {
        _errorMessage =
            "Learning pathways are currently very busy. Let's try again in a few moments!";
      } else if (errorStr.contains('MALFORMED_JSON') ||
          errorStr.contains('MALFORMED_RESPONSE')) {
        developer.log('AI Logic Error: Malformed response block.',
            name: 'CreateContentProvider');
        _errorMessage =
            "Sumi had trouble structuring the data this time. Try refining the source text and starting over.";
      } else {
        _errorMessage =
            "Sumi hit a small bump in the neural path: ${errorStr.replaceFirst('Exception: ', '')}";
      }
      _phase = CreationPhase.error;
    }
    notifyListeners();
  }

  void onProgress(String msg) {
    _progressMessage = msg;
    notifyListeners();
  }

  void backToConfig() {
    _phase = CreationPhase.config;
    _errorMessage = '';
    notifyListeners();
  }

  void backToReview() {
    _phase = CreationPhase.extractionReview;
    _errorMessage = '';
    notifyListeners();
  }

  void backToSource() {
    _phase = CreationPhase.source;
    _errorMessage = '';
    notifyListeners();
  }
}
