import 'dart:async';
import 'dart:typed_data';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:sumquiz/models/extraction_result.dart';
import 'package:sumquiz/services/content_extraction_service.dart';
import 'package:sumquiz/services/enhanced_ai_service.dart';
import 'package:sumquiz/services/local_database_service.dart';
import 'package:sumquiz/services/usage_service.dart';
import 'package:sumquiz/services/youtube_service.dart';
import 'package:sumquiz/utils/cancellation_token.dart';
import 'package:sumquiz/utils/youtube_pro_gate.dart';
import 'package:uuid/uuid.dart';
import 'package:sumquiz/models/local_note.dart';

enum CreationPhase { source, extractionReview, config, processing, success, error }

enum StudyArchetype { sprinter, architect }

class CreateContentProvider with ChangeNotifier {
  final ContentExtractionService _extractionService;
  final EnhancedAIService _aiService;
  final LocalDatabaseService _localDb;
  final YoutubeService _youtubeService;
  final UsageService _usageService = UsageService();

  CreateContentProvider({
    required ContentExtractionService extractionService,
    required EnhancedAIService aiService,
    required LocalDatabaseService localDb,
    required YoutubeService youtubeService,
  })  : _extractionService = extractionService,
        _aiService = aiService,
        _localDb = localDb,
        _youtubeService = youtubeService;

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

  void setSource(String type, {String? fileName, Uint8List? bytes, String? mime, String? text}) {
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

  void proceedToConfig() {
    _phase = CreationPhase.config;
    notifyListeners();
  }

  void updateConfig({String? difficulty, int? quizCount, int? flashcardCount, List<String>? questionTypes, StudyArchetype? archetype}) {
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
    _selectedQuestionTypes = ['Multiple Choice'];
    _selectedArchetype = StudyArchetype.architect;
    _extractionResult = null;
    _saveAsNote = true;
    _preSelectedFolderId = null;
    notifyListeners();
  }

  Future<void> startGeneration(String userId,
      {required bool allowYouTubeImport}) async {
    if (_phase == CreationPhase.processing) return;

    _phase = CreationPhase.processing;
    _progressMessage = 'Preparing your content...';
    _errorMessage = '';
    _isCancelled = false;
    notifyListeners();

    _cancelToken = CancellationToken();
    final cancelToken = _cancelToken!;

    try {
      // 1. Check Usage Limits
      final action = _fileBytes != null ? 'upload' : 'generate';
      final canPerform = await _usageService.canPerformAction(userId, action);
      if (!canPerform) {
        throw Exception('USAGE_LIMIT_REACHED');
      }

      ExtractionResult? extractionResult;

      if (_selectedSourceType == 'youtube' && !allowYouTubeImport) {
        throw Exception(kYoutubeProRequiredMessage);
      }

      // Handle YouTube Transcript via Extraction Service
      if (_selectedSourceType == 'youtube') {
        _progressMessage = 'Analyzing YouTube video...';
        notifyListeners();
        try {
          extractionResult = await _extractionService.extractContent(
            type: 'youtube',
            input: _textContent,
            userId: userId,
            allowYouTubeImport: allowYouTubeImport,
            cancelToken: cancelToken,
            onProgress: (msg) {
              _progressMessage = msg;
              notifyListeners();
            },
          );
        } catch (e) {
          throw Exception('YouTube Error: ${e.toString().replaceFirst('Exception: ', '')}');
        }
      }
      
      // 2. Extract Content (Regular sources)
      else if (_selectedSourceType == 'text' || _selectedSourceType == 'topic') {
        if (_textContent.split(' ').length <= 8 && !_textContent.contains('\n') && _selectedSourceType == 'topic') {
           // Topic generation (Fast track)
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
           await _usageService.recordAction(userId, action);
           notifyListeners();
           return;
        } else {
          // Regular text
          extractionResult = ExtractionResult(text: _textContent, suggestedTitle: 'Pasted Content');
        }
      } else if (_fileBytes != null) {
        _progressMessage = 'Extracting content from your file...';
        notifyListeners();
        extractionResult = await _extractionService.extractContent(
          type: _selectedSourceType,
          input: _fileBytes!,
          userId: userId,
          mimeType: _mimeType,
          allowYouTubeImport: allowYouTubeImport,
          cancelToken: cancelToken,
          onProgress: (msg) {
            _progressMessage = msg;
            notifyListeners();
          },
        );
      } else if (_selectedSourceType == 'link') {
        _progressMessage = 'Analyzing webpage content...';
        notifyListeners();
        extractionResult = await _extractionService.extractContent(
          type: 'link',
          input: _textContent,
          userId: userId,
          allowYouTubeImport: allowYouTubeImport,
          cancelToken: cancelToken,
          onProgress: (msg) {
            _progressMessage = msg;
            notifyListeners();
          },
        );
      }

      if (extractionResult == null) {
        throw Exception('Failed to extract content. Please try again.');
      }

      // If we are in the source phase, we move to review first
      if (_phase == CreationPhase.processing && _extractionResult == null) {
        _extractionResult = extractionResult;
        _textContent = extractionResult.text;
        _phase = CreationPhase.extractionReview;
        _progressMessage = '';
        notifyListeners();
        return;
      }

      // 3. Record Action
      await _usageService.recordAction(userId, action);

      // 4. Generate Final Materials
      _progressMessage = 'Generating study materials...';
      notifyListeners();

      final title = extractionResult.suggestedTitle.isNotEmpty 
          ? extractionResult.suggestedTitle 
          : (_fileName ?? (_textContent.length > 30 ? '${_textContent.substring(0, 30)}...' : _textContent));

      _generatedFolderId = await _aiService.generateAndStoreOutputs(
        text: extractionResult.text,
        title: title,
        requestedOutputs: ['summary', 'quiz', 'flashcards'],
        userId: userId,
        localDb: _localDb,
        difficulty: _selectedDifficulty,
        questionCount: _quizCount,
        cardCount: _flashcardCount,
        questionTypes: _selectedQuestionTypes,
        existingFolderId: _preSelectedFolderId,
        onProgress: (msg) {
          _progressMessage = msg;
          notifyListeners();
        },
        cancelToken: cancelToken,
      );

      // 5. Auto-save as Note if requested
      if (_saveAsNote) {
        _progressMessage = 'Saving as note...';
        notifyListeners();
        final note = LocalNote(
          id: const Uuid().v4(),
          userId: userId,
          title: title,
          content: extractionResult.text,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          folderId: _generatedFolderId.isNotEmpty ? _generatedFolderId : _preSelectedFolderId,
          tags: [],
          isSynced: false,
        );
        await _localDb.saveNote(note);
      }

      _phase = CreationPhase.success;
      notifyListeners();

    } catch (e) {
      if (cancelToken.isCancelled) {
        _isCancelled = true;
        _phase = CreationPhase.source;
      } else {
        developer.log('Generation error in provider: $e', name: 'CreateContentProvider');
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _phase = CreationPhase.error;
      }
      notifyListeners();
    }
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
