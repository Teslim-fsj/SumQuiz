import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/services/time_sync_service.dart';

class UsageConfig {
  // --- TIER PRICING (2026 GLOBAL) ---
  static final Map<String, Map<String, String>> pricing = {
    'free': {'global': '\$0', 'ngn': '₦0', 'inr': '₹0'},
    'standard_pro': {'global': '\$15', 'ngn': '₦6,500', 'inr': '₹550'},
    'power_pro': {'global': '\$30', 'ngn': '₦13,500', 'inr': '₹1,100'},
    'creator': {'global': '\$50', 'ngn': '₦27,500', 'inr': '₹2,250'},
  };

  // --- DAILY QUOTAS (Actions vs Transformations) ---
  static final Map<String, int> heavyQuota = {
    'free': 3,
    'standard_pro': 20,
    'power_pro': 50,
    'creator': 100,
  };

  static final Map<String, int> lightQuota = {
    'free': 50,
    'standard_pro': 500,
    'power_pro': 2000,
    'creator': 5000,
  };

  // Compute Unit (CU) Weights (Internal Economics - Margin Safety)
  static const double cuNano = 0.5; // Mascot state, tiny nudges
  static const double cuMicro = 1.0; // Summaries, Title generation, Context upload
  static const double cuStandard = 5.0; // Quizzes (10q), Flashcards (20c)
  static const double cuMacro = 15.0; // Exams, Long PDFs, YouTube
  static const double cuExtreme =
      30.0; // Live Lecture recordings (Neural Intake)
  static const double cuTutor = 1.0; // AI Tutor Interaction (Voice or Chat turn)
  static const double cuTutorSession = 3.0; // Start a Live Voice Session

  // Adaptive Multipliers
  static const double multiYoutube = 1.5;
  static const double multiPdfImage = 1.3;
  static const double multiHeavy = 1.8;

  // Tier-Based Neural Capacity (CU) - Hidden Buffer
  static const double capFree = 50.0;
  static const double capStandardPro = 500.0;
  static const double capPowerPro = 2000.0;
  static const double capCreator = 5000.0;
}

class UsageService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Check if user can proceed with a study session (Checks Quota + CU)
  Future<bool> canStartStudySession(
    String uid,
    String actionType, {
    bool isHeavy = false,
    bool isYoutube = false,
    bool isMultimodal = false,
  }) async {
    try {
      final userDoc = await _db.collection('users').doc(uid).get();
      if (!userDoc.exists) return false;
      final user = UserModel.fromFirestore(userDoc);

      // Safety: If user is Pro but tier is unknown or 'free', treat as 'standard_pro'
      String tier = user.tier ?? 'free';
      if (user.isPro &&
          (tier == 'free' || !UsageConfig.heavyQuota.containsKey(tier))) {
        tier = 'standard_pro';
        developer.log(
            'UsageService: Auto-promoting active Pro user to standard_pro for quota check (tier: ${user.tier}).',
            name: 'UsageService');
      }

      final now = TimeSyncService.now;
      final lastAction = user.lastDeckGenerationDate;

      // Daily Reset Logic (Client-side trigger)
      bool isNewDay = lastAction == null ||
          now.day != lastAction.day ||
          now.month != lastAction.month ||
          now.year != lastAction.year;

      int currentHeavy = isNewDay ? 0 : user.dailyHeavyActions;
      int currentLight = isNewDay ? 0 : user.dailyLightActions;

      // Determine if this is a "Heavy Action" or "Light Transformation"
      final bool effectivelyHeavy = isHeavy ||
          isYoutube ||
          isMultimodal ||
          ['lecture', 'exam'].contains(actionType);

      // 1. Quota Check (Visible Limits)
      if (!user.isPro) {
        if (effectivelyHeavy) {
          final int limit = UsageConfig.heavyQuota[tier] ?? 3;
          if (currentHeavy >= limit) {
            developer.log('Heavy quota exceeded for $tier user: $uid',
                name: 'UsageService');
            return false;
          }
        } else {
          final int limit = UsageConfig.lightQuota[tier] ?? 50;
          if (currentLight >= limit) {
            developer.log('Light quota exceeded for $tier user: $uid',
                name: 'UsageService');
            return false;
          }
        }
      }

      // 2. Hidden Compute Check (Margin Safety)
      double approximateCost = _calculateInternalCost(actionType,
          isHeavy: effectivelyHeavy,
          isYoutube: isYoutube,
          isMultimodal: isMultimodal);

      double computeUnits = user.computeUnits;
      if (user.isPro && computeUnits < approximateCost) {
        double tierCap = UsageConfig.capStandardPro;
        if (tier == 'power_pro') tierCap = UsageConfig.capPowerPro;
        if (tier == 'creator') tierCap = UsageConfig.capCreator;

        computeUnits = tierCap;
        developer.log(
            'UsageService: Auto-refilling active Pro user compute units to tier cap: $tierCap.',
            name: 'UsageService');
        _db.collection('users').doc(uid).update({'computeUnits': tierCap});
      }

      if (computeUnits < approximateCost) {
        developer.log('Neural capacity depleted (Hidden CU) for user: $uid',
            name: 'UsageService');
        return false;
      }

      // 3. Burst Control (Abuse protection only for heavy deck generation)
      if (await _isBursting(uid, user, actionType)) {
        return false;
      }

      return true;
    } catch (e) {
      developer.log('Session check error', name: 'UsageService', error: e);
      return false;
    }
  }

  /// Internal adaptive throttling check (Burst protection for heavy generations only)
  Future<bool> _isBursting(
      String uid, UserModel user, String actionType) async {
    // Conversational, tutoring, mascot, or lightweight actions never burst-throttle
    if (!['quiz', 'exam', 'generate', 'lecture'].contains(actionType)) {
      return false;
    }

    final now = TimeSyncService.now;
    final lastAction = user.lastDeckGenerationDate;
    if (lastAction == null) return false;

    final diff = now.difference(lastAction);

    // Safety thresholds for bulk generation
    if (user.tier == 'free' && diff.inSeconds < 15) return true;
    if (user.isPro && diff.inSeconds < 3) return true;

    return false;
  }

  /// Record a Study Session (Deduct Quota + CU invisibly)
  Future<void> recordStudySession(String uid, String actionType,
      {bool isHeavy = false,
      bool isYoutube = false,
      bool isMultimodal = false}) async {
    try {
      final bool effectivelyHeavy = isHeavy ||
          isYoutube ||
          isMultimodal ||
          ['lecture', 'exam'].contains(actionType);

      double cost = _calculateInternalCost(actionType,
          isHeavy: effectivelyHeavy,
          isYoutube: isYoutube,
          isMultimodal: isMultimodal);

      await _db.runTransaction((transaction) async {
        final userRef = _db.collection('users').doc(uid);
        final userDoc = await transaction.get(userRef);
        if (!userDoc.exists) return;

        final user = UserModel.fromFirestore(userDoc);
        final now = TimeSyncService.now;
        final lastAction = user.lastDeckGenerationDate;

        // Safety tier promote
        String tier = user.tier ?? 'free';
        if (user.isPro &&
            (tier == 'free' || !UsageConfig.heavyQuota.containsKey(tier))) {
          tier = 'standard_pro';
        }

        // Reset if new day
        bool isNewDay = lastAction == null ||
            now.day != lastAction.day ||
            now.month != lastAction.month ||
            now.year != lastAction.year;

        int newHeavy = isNewDay ? 0 : user.dailyHeavyActions;
        int newLight = isNewDay ? 0 : user.dailyLightActions;

        double computeUnits = user.computeUnits;
        if (user.isPro && computeUnits < cost) {
          double tierCap = UsageConfig.capStandardPro;
          if (tier == 'power_pro') tierCap = UsageConfig.capPowerPro;
          if (tier == 'creator') tierCap = UsageConfig.capCreator;
          computeUnits = tierCap;
        }

        final bool isDeckGen =
            ['quiz', 'exam', 'generate', 'lecture'].contains(actionType);

        transaction.update(userRef, {
          'computeUnits': (computeUnits - cost).clamp(0.0, 10000.0),
          if (effectivelyHeavy)
            'dailyHeavyActions': newHeavy + 1
          else
            'dailyLightActions': newLight + 1,
          if (isDeckGen) 'totalDecksGenerated': user.totalDecksGenerated + 1,
          if (isDeckGen) 'lastDeckGenerationDate': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      developer.log(
          'Recorded action: $actionType (Heavy: $effectivelyHeavy, CU: $cost)',
          name: 'UsageService');
    } catch (e) {
      developer.log('Error recording usage', name: 'UsageService', error: e);
    }
  }

  double _calculateInternalCost(String actionType,
      {bool isHeavy = false,
      bool isYoutube = false,
      bool isMultimodal = false}) {
    double base = UsageConfig.cuStandard;

    if (actionType == 'summary' || actionType == 'note') {
      base = UsageConfig.cuMicro;
    }
    if (actionType == 'generate' || actionType == 'quiz') {
      base = UsageConfig.cuMacro;
    }
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
  Future<bool> canPerformAction(String uid, String action) =>
      canStartStudySession(uid, action);
  Future<void> recordAction(String uid, String action) =>
      recordStudySession(uid, action);
  Future<bool> canGenerateDeck(String uid) => canStartStudySession(uid, 'quiz');
}

