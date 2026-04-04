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

enum CreationPhase { source, config, processing, success, error }

enum StudyArchetype { sprinter, architect }

class CreateContentProvider with ChangeNotifier {
  final ContentExtractionService _extractionService;
  final EnhancedAIService _aiService;
  final LocalDatabaseService _localDb;
  final UsageService _usageService = UsageService();

  CreateContentProvider({
    required ContentExtractionService extractionService,
    required EnhancedAIService aiService,
    required LocalDatabaseService localDb,
  })  : _extractionService = extractionService,
        _aiService = aiService,
        _localDb = localDb;

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

  int _selectedCount = 15;
  int get selectedCount => _selectedCount;

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

  bool _isCancelled = false;
  CancellationToken? _cancelToken;

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

  void updateConfig({String? difficulty, int? count, List<String>? questionTypes, StudyArchetype? archetype}) {
    if (difficulty != null) _selectedDifficulty = difficulty;
    if (count != null) _selectedCount = count;
    if (questionTypes != null) _selectedQuestionTypes = questionTypes;
    if (archetype != null) _selectedArchetype = archetype;
    notifyListeners();
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
    notifyListeners();
  }

  Future<void> startGeneration(String userId) async {
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

      // 2. Extract Content
      if (_selectedSourceType == 'text' || _selectedSourceType == 'topic') {
        if (_textContent.split(' ').length <= 8 && !_textContent.contains('\n') && _selectedSourceType == 'topic') {
           // Topic generation (Fast track)
           _progressMessage = 'Generating full study set from topic...';
           _generatedFolderId = await _aiService.generateFromTopic(
              topic: _textContent,
              userId: userId,
              localDb: _localDb,
              depth: _selectedDifficulty,
              cardCount: _selectedCount,
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
        questionCount: _selectedCount,
        cardCount: _selectedCount,
        questionTypes: _selectedQuestionTypes,
        onProgress: (msg) {
          _progressMessage = msg;
          notifyListeners();
        },
        cancelToken: cancelToken,
      );

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

  void backToSource() {
    _phase = CreationPhase.source;
    _errorMessage = '';
    notifyListeners();
  }
}
