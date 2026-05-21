import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'ai/ai_config.dart';
import 'usage_service.dart';

class ComputeManager {
  static final ComputeManager _instance = ComputeManager._internal();
  factory ComputeManager() => _instance;
  ComputeManager._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final UsageService _usageService = UsageService();

  /// Synchronizes the user's neural capacity with the AI routing config.
  /// This should be called at the start of any major study session.
  Future<void> syncNeuralState(UserModel user) async {
    final double energy = user.computeEnergyLevel;

    NeuralState newState;
    if (energy >= 0.5) {
      newState = NeuralState.highEnergy;
    } else if (energy > 0.1) {
      newState = NeuralState.fatigued;
    } else if (energy > 0.0) {
      newState = NeuralState.exhausted;
    } else {
      newState = NeuralState.depleted;
    }

    AIConfig.currentNeuralState = newState;
    developer.log(
        'Neural State Synced: $newState (Energy: ${energy.toStringAsFixed(2)})',
        name: 'ComputeManager');
  }

  /// Orchestrates an AI action with full compute tracking and abuse protection.
  /// [actionType] - standard, summary, exam, lecture, mascot
  Future<bool> orchestrateAction(
    String uid,
    String actionType, {
    bool isHeavy = false,
    bool isYoutube = false,
    bool isMultimodal = false,
  }) async {
    try {
      // 1. Fetch latest user state
      final userDoc = await _db.collection('users').doc(uid).get();
      if (!userDoc.exists) {
        developer.log(
            'User doc not found for $uid — allowing action (non-blocking)',
            name: 'ComputeManager');
        return true; // Don't hard-block if user doc is missing; let AI service handle auth
      }
      final user = UserModel.fromFirestore(userDoc);

      // 2. Sync routing config
      await syncNeuralState(user);

      // 3. Pre-check capacity & burst — pass isHeavy so check uses same
      //    heavy/light classification as the subsequent record call.
      final canProceed = await _usageService.canStartStudySession(
        uid,
        actionType,
        isHeavy: isHeavy,
        isYoutube: isYoutube,
        isMultimodal: isMultimodal,
      );
      if (!canProceed) return false;

      // 4. Update usage (silent deduction)
      await _usageService.recordStudySession(uid, actionType,
          isHeavy: isHeavy, isYoutube: isYoutube, isMultimodal: isMultimodal);

      return true;
    } catch (e) {
      developer.log(
          'Compute orchestration error — allowing action through (non-blocking)',
          name: 'ComputeManager',
          error: e);
      // On unexpected errors (network, Firestore timeout, etc.) we allow the
      // action through rather than silently blocking the user. Real quota
      // enforcement is also done server-side.
      return true;
    }
  }

  /// Reset daily capacity (Cloud Function shim)
  Future<void> refillCapacity(String uid) async {
    final userDoc = await _db.collection('users').doc(uid).get();
    if (!userDoc.exists) return;
    final user = UserModel.fromFirestore(userDoc);

    // Safety: If user is Pro but tier is unknown or 'free', treat as 'standard_pro'
    String tier = user.tier ?? 'free';
    if (user.isPro && !UsageConfig.heavyQuota.containsKey(tier)) {
      tier = 'standard_pro';
    }

    if (tier == 'free') return;

    double newMax = _getMaxCapacityForTier(tier);

    await _db.collection('users').doc(uid).update({
      'computeUnits': newMax,
      'maxComputeCapacity': newMax,
      'lastCreditRefillDate': FieldValue.serverTimestamp(),
    });
  }

  double _getMaxCapacityForTier(String tier) {
    switch (tier) {
      case 'standard_pro':
        return UsageConfig.capStandardPro;
      case 'power_pro':
        return UsageConfig.capPowerPro;
      case 'creator':
        return UsageConfig.capCreator;
      default:
        return UsageConfig.capFree;
    }
  }
}
