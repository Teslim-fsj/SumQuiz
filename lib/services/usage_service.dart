import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/services/time_sync_service.dart';
import 'package:sumquiz/services/referral_service.dart';

class UsageConfig {
  // Compute Unit (CU) Weights (Internal Economics)
  static const double cuNano = 0.5;      // Mascot state, tiny nudges
  static const double cuMicro = 1.5;     // Summaries, Title generation
  static const double cuStandard = 6.0;  // Quizzes (10q), Flashcards (20c)
  static const double cuMacro = 20.0;    // Exams, Long PDFs, YouTube
  static const double cuExtreme = 45.0;  // Live Lecture recordings (Neural Intake)
  static const double cuTutor = 8.0;      // AI Tutor Interaction (Voice or Chat)
  static const double cuTutorSession = 25.0; // Start a Live Voice Session

  // Adaptive Multipliers
  static const double multiYoutube = 1.5;
  static const double multiPdfImage = 1.3;
  static const double multiHeavy = 1.8;

  // Tier-Based Daily Neural Capacity (CU)
  static const double capFree = 25.0;
  static const double capStarterPro = 60.0;
  static const double capStandardPro = 180.0;
  static const double capPowerPro = 450.0;
  static const double capCreator = 1200.0;
}

class UsageService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Check if user can proceed with a study session (Invisibly checks CU)
  Future<bool> canStartStudySession(String uid, String actionType) async {
    try {
      final userDoc = await _db.collection('users').doc(uid).get();
      if (!userDoc.exists) return false;
      final user = UserModel.fromFirestore(userDoc);

      // 1. Invisible Cost Calculation
      double approximateCost = _calculateInternalCost(actionType);

      // 2. High Tier Bypass (Creators/Power Pros have large buffers)
      if (user.tier == 'creator' || user.tier == 'power_pro') {
        return true;
      }

      // 3. Burst Control (Abuse protection)
      if (await _isBursting(uid, user)) {
        developer.log('Burst control triggered for user: $uid',
            name: 'UsageService');
        return false;
      }

      // 4. Capacity Check (Neural Energy)
      if (user.computeUnits < approximateCost) {
        developer.log('Capacity depleted (Invisibly blocked) for user: $uid',
            name: 'UsageService');
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
    final now = TimeSyncService.now;
    final lastAction = user.lastDeckGenerationDate;

    if (lastAction == null) return false;

    final diff = now.difference(lastAction);

    // Free users: 2 mins between heavy actions
    if (user.tier == 'free' && diff.inSeconds < 120) return true;

    // Pros: 15 seconds between actions (prevents bot-like behavior)
    if (user.isPro && diff.inSeconds < 15) return true;

    return false;
  }

  /// Record a Study Session (Deduct CU invisibly)
  Future<void> recordStudySession(String uid, String actionType,
      {bool isHeavy = false, bool isYoutube = false, bool isMultimodal = false}) async {
    try {
      double cost = _calculateInternalCost(actionType, 
          isHeavy: isHeavy, isYoutube: isYoutube, isMultimodal: isMultimodal);

      UserModel? userBeforeTx;
      await _db.runTransaction((transaction) async {
        final userRef = _db.collection('users').doc(uid);
        final userDoc = await transaction.get(userRef);
        if (!userDoc.exists) return;

        userBeforeTx = UserModel.fromFirestore(userDoc);
        final newCompute = userBeforeTx!.computeUnits - cost;

        transaction.update(userRef, {
          'computeUnits': newCompute < 0 ? 0.0 : newCompute,
          'totalDecksGenerated': userBeforeTx!.totalDecksGenerated + 1,
          'lastDeckGenerationDate': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      developer.log('Recorded compute burn: $actionType (CU: $cost)',
          name: 'UsageService');

      // Referral Reward Logic
      if (userBeforeTx != null &&
          userBeforeTx!.totalDecksGenerated == 0 &&
          userBeforeTx!.referredBy != null &&
          userBeforeTx!.referredBy!.isNotEmpty) {
        try {
          final ReferralService referralService = ReferralService();
          await referralService.grantReferrerReward(userBeforeTx!.referredBy!);
        } catch (e) {
          developer.log('Referral reward failed', name: 'UsageService', error: e);
        }
      }
    } catch (e) {
      developer.log('Error recording compute', name: 'UsageService', error: e);
    }
  }

  double _calculateInternalCost(String actionType, 
      {bool isHeavy = false, bool isYoutube = false, bool isMultimodal = false}) {
    double base = UsageConfig.cuStandard;
    
    if (actionType == 'summary' || actionType == 'note') base = UsageConfig.cuMicro;
    if (actionType == 'exam') base = UsageConfig.cuMacro;
    if (actionType == 'lecture') base = UsageConfig.cuExtreme;
    if (actionType == 'tutor') base = UsageConfig.cuTutor;
    if (actionType == 'tutor_session') base = UsageConfig.cuTutorSession;
    if (actionType == 'mascot') base = UsageConfig.cuNano;

    if (isYoutube) base *= UsageConfig.multiYoutube;
    if (isMultimodal) base *= UsageConfig.multiPdfImage;
    if (isHeavy) base *= UsageConfig.multiHeavy;
    
    return base;
  }

  // --- Legacy Compatibility ---
  Future<bool> canPerformAction(String uid, String action) => canStartStudySession(uid, action);
  Future<void> recordAction(String uid, String action) => recordStudySession(uid, action);
  Future<bool> canGenerateDeck(String uid) => canStartStudySession(uid, 'quiz');
}
