import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/services/time_sync_service.dart';

class UsageConfig {
  // Credits costs (Internal economics)
  static const int baseSummaryCost = 2; 
  static const int baseQuizCost = 5;    
  static const int baseExamCost = 15;   

  // Multipliers
  static const double youtubeMultiplier = 1.5;
  static const double pdfImageMultiplier = 1.3;
  static const double examMultiplier = 1.7;

  // Invisible Daily Soft Caps (Session throttling)
  static const int freeDailyUnitCap = 15;
  static const int starterProDailyUnitCap = 40;
  static const int standardProDailyUnitCap = 120;
  static const int powerProDailyUnitCap = 300;
  static const int creatorDailyUnitCap = 800;
}

class UsageService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Check if user can proceed with a study session (Invisibly checks credits)
  Future<bool> canStartStudySession(String uid, String actionType) async {
    try {
      final userDoc = await _db.collection('users').doc(uid).get();
      if (!userDoc.exists) return false;
      final user = UserModel.fromFirestore(userDoc);

      // 1. Invisible Cost Calculation
      int approximateCost = _calculateInternalCost(actionType);
      
      // 2. Burst Control (Abuse protection)
      if (await _isBursting(uid, user)) {
        developer.log('Burst control triggered for user: $uid', name: 'UsageService');
        return false;
      }

      // 3. Adaptive Throttling (Protect margins)
      if (user.credits < approximateCost) {
        developer.log('Credit block (Hidden as Daily Limit) for user: $uid', name: 'UsageService');
        return false;
      }

      return true;
    } catch (e) {
      developer.log('Session check error', name: 'UsageService', error: e);
      return false;
    }
  }

  /// Internal adaptive throttling check (Burst protection)
  Future<bool> _isBursting(String uid, UserModel user) async {
    // Logic to check if user had too many generations in last 5 mins
    final now = TimeSyncService.now;
    final lastAction = user.lastDeckGenerationDate;
    
    if (lastAction == null) return false;

    final diff = now.difference(lastAction);
    
    // Free users can't spam within 60 seconds
    if (!user.isPro && diff.inSeconds < 60) return true;
    
    // Pros can spam up to 5 bursts, then get throttled (simplified check)
    if (user.isPro && diff.inSeconds < 5) return true;

    return false;
  }

  /// Record a Study Session (Deduct credits invisibly)
  Future<void> recordStudySession(String uid, String actionType, {bool isHeavy = false}) async {
    try {
      int cost = _calculateInternalCost(actionType, isHeavy: isHeavy);

      await _db.runTransaction((transaction) async {
        final userRef = _db.collection('users').doc(uid);
        final userDoc = await transaction.get(userRef);
        if (!userDoc.exists) return;

        final user = UserModel.fromFirestore(userDoc);
        final newCredits = user.credits - cost;
        
        transaction.update(userRef, {
          'credits': newCredits < 0 ? 0 : newCredits,
          'totalDecksGenerated': user.totalDecksGenerated + 1,
          'lastDeckGenerationDate': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      
      developer.log('Recorded session: $actionType (Cost: $cost)', name: 'UsageService');
    } catch (e) {
      developer.log('Error recording session', name: 'UsageService', error: e);
    }
  }

  int _calculateInternalCost(String actionType, {bool isHeavy = false}) {
    double base = UsageConfig.baseQuizCost.toDouble();
    if (actionType == 'summary') base = UsageConfig.baseSummaryCost.toDouble();
    if (actionType == 'exam') base = UsageConfig.baseExamCost.toDouble();

    if (isHeavy) base *= 1.5;
    return base.ceil();
  }

  // --- COMPATIBILITY SHIMS (Legacy) ---
  Future<bool> canPerformAction(String uid, String action) => canStartStudySession(uid, action);
  Future<void> recordAction(String uid, String action) => recordStudySession(uid, action);
  Future<bool> canGenerateDeck(String uid) => canStartStudySession(uid, 'quiz');
}
