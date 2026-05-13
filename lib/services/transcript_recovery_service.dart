import 'dart:async';
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:developer' as developer;

class TranscriptRecoveryService {
  static const String _recoveryBoxName = 'transcript_recovery';
  late Box<String> _recoveryBox;
  bool _isInitialized = false;

  static final TranscriptRecoveryService _instance = TranscriptRecoveryService._internal();
  factory TranscriptRecoveryService() => _instance;
  TranscriptRecoveryService._internal();

  Future<void> init() async {
    if (_isInitialized) return;
    _recoveryBox = await Hive.openBox<String>(_recoveryBoxName);
    _isInitialized = true;
    _cleanupOldRecoveries();
  }

  /// Store a transcript chunk for recovery in case of a crash.
  Future<void> savePendingTranscript(String noteId, String content) async {
    if (!_isInitialized) await init();
    await _recoveryBox.put(noteId, content);
    await _recoveryBox.put('${noteId}_timestamp', DateTime.now().toIso8601String());
  }

  /// Retrieve a recovered transcript for a note.
  Future<String?> getRecoveredTranscript(String noteId) async {
    if (!_isInitialized) await init();
    return _recoveryBox.get(noteId);
  }

  /// Clear the recovery data for a note after successful save.
  Future<void> clearRecovery(String noteId) async {
    if (!_isInitialized) await init();
    await _recoveryBox.delete(noteId);
    await _recoveryBox.delete('${noteId}_timestamp');
  }

  /// Remove recovery data older than 24 hours.
  Future<void> _cleanupOldRecoveries() async {
    final now = DateTime.now();
    final keysToDelete = <String>[];

    for (final key in _recoveryBox.keys) {
      if (key.toString().endsWith('_timestamp')) {
        final timestampStr = _recoveryBox.get(key);
        if (timestampStr != null) {
          final timestamp = DateTime.tryParse(timestampStr);
          if (timestamp != null && now.difference(timestamp).inHours > 24) {
            final noteId = key.toString().replaceAll('_timestamp', '');
            keysToDelete.add(noteId);
            keysToDelete.add(key.toString());
          }
        }
      }
    }

    if (keysToDelete.isNotEmpty) {
      await _recoveryBox.deleteAll(keysToDelete);
      developer.log('Cleaned up ${keysToDelete.length ~/ 2} stale recoveries', name: 'TranscriptRecoveryService');
    }
  }
}
