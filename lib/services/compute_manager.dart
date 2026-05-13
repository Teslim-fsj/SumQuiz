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
    developer.log('Neural State Synced: $newState (Energy: ${energy.toStringAsFixed(2)})', name: 'ComputeManager');
  }

  /// Orchestrates an AI action with full compute tracking and abuse protection.
  /// [actionType] - standard, summary, exam, lecture, mascot
  Future<bool> orchestrateAction(String uid, String actionType, {
    bool isHeavy = false,
    bool isYoutube = false,
    bool isMultimodal = false,
  }) async {
    try {
      // 1. Fetch latest user state
      final userDoc = await _db.collection('users').doc(uid).get();
      if (!userDoc.exists) return false;
      final user = UserModel.fromFirestore(userDoc);

      // 2. Sync routing config
      await syncNeuralState(user);

      // 3. Pre-check capacity & burst
      final canProceed = await _usageService.canStartStudySession(uid, actionType);
      if (!canProceed) return false;

      // 4. Update usage (Silent deduction)
      await _usageService.recordStudySession(
        uid, 
        actionType, 
        isHeavy: isHeavy, 
        isYoutube: isYoutube, 
        isMultimodal: isMultimodal
      );

      return true;
    } catch (e) {
      developer.log('Compute orchestration failed', name: 'ComputeManager', error: e);
      return false;
    }
  }

  /// Reset daily capacity (Cloud Function shim)
  Future<void> refillCapacity(String uid) async {
    final userDoc = await _db.collection('users').doc(uid).get();
    if (!userDoc.exists) return;
    final user = UserModel.fromFirestore(userDoc);
    
    // Free tier uses Lifetime credits - do not refill daily
    if (user.tier == 'free') return;

    double newMax = _getMaxCapacityForTier(user.tier ?? 'free');
    
    await _db.collection('users').doc(uid).update({
      'computeUnits': newMax,
      'maxComputeCapacity': newMax,
      'lastCreditRefillDate': FieldValue.serverTimestamp(),
    });
  }

  double _getMaxCapacityForTier(String tier) {
    switch (tier) {
      case 'standard_pro': return UsageConfig.capStandardPro;
      case 'power_pro': return UsageConfig.capPowerPro;
      case 'creator': return UsageConfig.capCreator;
      default: return UsageConfig.capFree;
    }
  }
}
