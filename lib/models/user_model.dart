import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/time_sync_service.dart';

enum UserRole {
  student,
  creator,
}

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final DateTime? subscriptionExpiry;

  // Progress Tracking Fields
  final double currentMomentum;
  final int dailyGoal;
  final int itemsCompletedToday;
  final int dailyDecksGenerated;
  final int totalDecksGenerated;
  final int totalUploads;
  final int examsGenerated;
  final DateTime? lastDeckGenerationDate;
  final DateTime? updatedAt;
  final double momentumDecayRate; // Default 0.05 (5% daily)
  final int missionCompletionStreak; // Consecutive missions done
  final int difficultyPreference; // Inferred (1-5) based on history
  final String preferredStudyTime; // "HH:mm" format, default "09:00"

  // Freemium Usage Tracking
  final int folderCount;
  final int srsCardCount;
  final UserRole role;

  // Trial & Creator Logic (stored fields)
  final bool _isTrialUser; // Private - use isTrial getter
  final bool isCreatorPro;
  final bool hasLinkedCard;
  final bool hasUsedTrial;
  final String? currentProduct; // Selected subscription product ID

  // Referral Fields
  final String? referralCode;
  final String? appliedReferralCode;
  final String? referredBy;
  final DateTime? referralAppliedAt;
  final int totalReferrals;
  final int referrals; // Pending referral count
  final int referralRewards;

  // Purchase Verification
  final DateTime? lastVerified;
  final String? purchaseToken;

  // Invisible Compute Economy (Neural Capacity)
  final double computeUnits;
  final double maxComputeCapacity;
  final String? computeSessionId;
  final String? tier; // free, starter_pro, standard_pro, power_pro, creator

  final int dailyHeavyActions;
  final int dailyLightActions;

  final Map<String, dynamic> creatorProfile;
  final bool isEmailVerified;
  final bool isTrialActive;
  final DateTime? trialStartDate;
  final DateTime? lastCreditRefillDate;


  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.role = UserRole.student,
    this.subscriptionExpiry,
    this.currentMomentum = 0.0,
    this.momentumDecayRate = 0.05,
    this.missionCompletionStreak = 0,
    this.difficultyPreference = 3,
    this.preferredStudyTime = "09:00",
    this.dailyGoal = 5,
    this.itemsCompletedToday = 0,
    this.folderCount = 0,
    this.srsCardCount = 0,
    this.dailyDecksGenerated = 0,
    this.totalDecksGenerated = 0,
    this.totalUploads = 0,
    this.examsGenerated = 0,
    this.lastDeckGenerationDate,
    this.updatedAt,
    bool isTrial = false,
    this.isCreatorPro = false,
    this.hasLinkedCard = false,
    this.hasUsedTrial = false,
    this.currentProduct,
    this.referralCode,
    this.appliedReferralCode,
    this.referredBy,
    this.referralAppliedAt,
    this.totalReferrals = 0,
    this.referrals = 0,
    this.referralRewards = 0,
    this.lastVerified,
    this.purchaseToken,
    this.creatorProfile = const {},
    this.photoUrl,
    this.isEmailVerified = false,
    this.computeUnits = 20.0, // Default for 🆓 FREE TIER (Neural Capacity)
    this.maxComputeCapacity = 20.0,
    this.computeSessionId,
    this.dailyHeavyActions = 0,
    this.dailyLightActions = 0,
    this.isTrialActive = false,
    this.trialStartDate,
    this.lastCreditRefillDate,
    this.tier = 'free', // Default tier
  }) : _isTrialUser = isTrial;

  // Legacy compatibility getters (mapped to Compute Units)
  int get credits => computeUnits.floor();
  int get lifetimeCreditsEarned => (credits + totalDecksGenerated * 5); // Approximate

  // Compute Energy States (Invisible UX Logic)
  double get computeEnergyLevel => (computeUnits / maxComputeCapacity).clamp(0.0, 1.0);
  
  bool get isHighEnergy => computeEnergyLevel >= 0.5;
  bool get isFatigued => computeEnergyLevel > 0.1 && computeEnergyLevel < 0.5;
  bool get isExhausted => computeEnergyLevel > 0.0 && computeEnergyLevel <= 0.1;
  bool get isDepleted => computeEnergyLevel <= 0.0;

  String get neuralStateLabel {
    if (isHighEnergy) return 'High Momentum';
    if (isFatigued) return 'Steady Flow';
    if (isExhausted) return 'Cognitive Load High';
    return 'Recharging';
  }

  String? get photoURL => photoUrl;

  /// Returns true if user has active Pro access
  /// Priority: Creator Pro > Active Subscription
  bool get isPro {
    // 1. Manual Tier Override (Firestore selection)
    if (tier != null && tier != 'free') return true;

    // 2. Creator Bonus (permanent Pro access)
    if (isCreatorPro) return true;

    // 3. Active Subscription (includes trial and paid)
    if (subscriptionExpiry != null) {
      return subscriptionExpiry!.isAfter(TimeSyncService.now);
    }

    // 4. Not Pro
    return false;
  }

  /// Returns true if user is on trial (has trial flag AND active subscription)
  bool get isTrial {
    // Must have trial flag set
    if (!_isTrialUser) return false;

    // Must have active subscription
    if (subscriptionExpiry == null) return false;

    // Subscription must not be expired
    return subscriptionExpiry!.isAfter(TimeSyncService.now);
  }

  /// Returns a human-readable name for the user's current plan
  String get planName {
    if (tier != null && tier != 'free') {
      // Capitalize first letter of tier
      return tier![0].toUpperCase() + tier!.substring(1);
    }
    if (isCreatorPro) return 'Creator Pro';
    if (isPro) return 'Pro Member';
    return role == UserRole.creator ? 'Free Educator' : 'Free Scholar';
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      subscriptionExpiry: (data['subscriptionExpiry'] as Timestamp?)?.toDate(),
      currentMomentum: (data['currentMomentum'] as num?)?.toDouble() ?? 0.0,
      momentumDecayRate:
          (data['momentumDecayRate'] as num?)?.toDouble() ?? 0.05,
      missionCompletionStreak: data['missionCompletionStreak'] ?? 0,
      difficultyPreference: data['difficultyPreference'] ?? 3,
      preferredStudyTime: data['preferredStudyTime'] ?? "09:00",
      dailyGoal: data['dailyGoal'] ?? 5,
      itemsCompletedToday: data['itemsCompletedToday'] ?? 0,
      folderCount: data['folderCount'] ?? 0,
      srsCardCount: data['srsCardCount'] ?? 0,
      dailyDecksGenerated: data['dailyDecksGenerated'] ?? 0,
      dailyHeavyActions: data['dailyHeavyActions'] ?? 0,
      dailyLightActions: data['dailyLightActions'] ?? 0,
      totalDecksGenerated: data['totalDecksGenerated'] ?? 0,
      totalUploads: data['totalUploads'] ?? 0,
      examsGenerated: data['examsGenerated'] ?? 0,
      lastDeckGenerationDate:
          (data['lastDeckGenerationDate'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      role: UserRole.values.firstWhere(
        (e) => e.name == (data['role'] ?? 'student'),
        orElse: () => UserRole.student,
      ),
      isTrial: data['isTrial'] ?? false,
      isCreatorPro: data['isCreatorPro'] ?? false,
      hasLinkedCard: data['hasLinkedCard'] ?? false,
      hasUsedTrial: data['hasUsedTrial'] ?? false,
      currentProduct: data['currentProduct'],
      referralCode: data['referralCode'],
      appliedReferralCode: data['appliedReferralCode'],
      referredBy: data['referredBy'],
      referralAppliedAt: (data['referralAppliedAt'] as Timestamp?)?.toDate(),
      totalReferrals: data['totalReferrals'] ?? 0,
      referrals: data['referrals'] ?? 0,
      referralRewards: data['referralRewards'] ?? 0,
      lastVerified: (data['lastVerified'] as Timestamp?)?.toDate(),
      purchaseToken: data['purchaseToken'],
      creatorProfile: data['creatorProfile'] ?? {},
      photoUrl: data['photoUrl'] ?? data['photoURL'],
      isEmailVerified: data['isEmailVerified'] ?? false,
      computeUnits: (data['computeUnits'] as num?)?.toDouble() ?? (data['credits'] as num?)?.toDouble() ?? 20.0,
      maxComputeCapacity: (data['maxComputeCapacity'] as num?)?.toDouble() ?? 20.0,
      computeSessionId: data['computeSessionId'],
      isTrialActive: data['isTrialActive'] ?? false,
      trialStartDate: (data['trialStartDate'] as Timestamp?)?.toDate(),
      lastCreditRefillDate:
          (data['lastCreditRefillDate'] as Timestamp?)?.toDate(),
      tier: data['tier'] ?? 'free',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'role': role.name,
      if (subscriptionExpiry != null)
        'subscriptionExpiry': Timestamp.fromDate(subscriptionExpiry!),
      'currentMomentum': currentMomentum,
      'momentumDecayRate': momentumDecayRate,
      'missionCompletionStreak': missionCompletionStreak,
      'difficultyPreference': difficultyPreference,
      'preferredStudyTime': preferredStudyTime,
      'dailyGoal': dailyGoal,
      'itemsCompletedToday': itemsCompletedToday,
      'folderCount': folderCount,
      'srsCardCount': srsCardCount,
      'dailyDecksGenerated': dailyDecksGenerated,
      'dailyHeavyActions': dailyHeavyActions,
      'dailyLightActions': dailyLightActions,
      'totalDecksGenerated': totalDecksGenerated,
      'totalUploads': totalUploads,
      'examsGenerated': examsGenerated,
      if (lastDeckGenerationDate != null)
        'lastDeckGenerationDate': Timestamp.fromDate(lastDeckGenerationDate!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      'isTrial': _isTrialUser,
      'isCreatorPro': isCreatorPro,
      'hasLinkedCard': hasLinkedCard,
      'hasUsedTrial': hasUsedTrial,
      'currentProduct': currentProduct,
      if (referralCode != null) 'referralCode': referralCode,
      if (appliedReferralCode != null)
        'appliedReferralCode': appliedReferralCode,
      if (referredBy != null) 'referredBy': referredBy,
      if (referralAppliedAt != null)
        'referralAppliedAt': Timestamp.fromDate(referralAppliedAt!),
      'totalReferrals': totalReferrals,
      'referrals': referrals,
      'referralRewards': referralRewards,
      if (lastVerified != null)
        'lastVerified': Timestamp.fromDate(lastVerified!),
      if (purchaseToken != null) 'purchaseToken': purchaseToken,
      'creatorProfile': creatorProfile,
      'photoUrl': photoUrl,
      'isEmailVerified': isEmailVerified,
      'computeUnits': computeUnits,
      'maxComputeCapacity': maxComputeCapacity,
      if (computeSessionId != null) 'computeSessionId': computeSessionId,
      'isTrialActive': isTrialActive,
      if (trialStartDate != null)
        'trialStartDate': Timestamp.fromDate(trialStartDate!),
      if (lastCreditRefillDate != null)
        'lastCreditRefillDate': Timestamp.fromDate(lastCreditRefillDate!),
      'tier': tier,
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    DateTime? subscriptionExpiry,
    double? currentMomentum,
    double? momentumDecayRate,
    int? missionCompletionStreak,
    int? difficultyPreference,
    String? preferredStudyTime,
    int? dailyGoal,
    int? itemsCompletedToday,
    int? folderCount,
    int? srsCardCount,
    int? dailyDecksGenerated,
    int? dailyHeavyActions,
    int? dailyLightActions,
    int? totalDecksGenerated,
    int? totalUploads,
    int? examsGenerated,
    DateTime? lastDeckGenerationDate,
    DateTime? updatedAt,
    UserRole? role,
    bool? isTrial,
    bool? isCreatorPro,
    bool? hasLinkedCard,
    bool? hasUsedTrial,
    String? currentProduct,
    String? referralCode,
    String? appliedReferralCode,
    String? referredBy,
    DateTime? referralAppliedAt,
    int? totalReferrals,
    int? referrals,
    int? referralRewards,
    DateTime? lastVerified,
    String? purchaseToken,
    Map<String, dynamic>? creatorProfile,
    String? photoUrl,
    bool? isEmailVerified,
    double? computeUnits,
    double? maxComputeCapacity,
    String? computeSessionId,
    bool? isTrialActive,
    DateTime? trialStartDate,
    DateTime? lastCreditRefillDate,
    String? tier,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      subscriptionExpiry: subscriptionExpiry ?? this.subscriptionExpiry,
      currentMomentum: currentMomentum ?? this.currentMomentum,
      momentumDecayRate: momentumDecayRate ?? this.momentumDecayRate,
      missionCompletionStreak:
          missionCompletionStreak ?? this.missionCompletionStreak,
      difficultyPreference: difficultyPreference ?? this.difficultyPreference,
      preferredStudyTime: preferredStudyTime ?? this.preferredStudyTime,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      itemsCompletedToday: itemsCompletedToday ?? this.itemsCompletedToday,
      folderCount: folderCount ?? this.folderCount,
      srsCardCount: srsCardCount ?? this.srsCardCount,
      dailyDecksGenerated: dailyDecksGenerated ?? this.dailyDecksGenerated,
      dailyHeavyActions: dailyHeavyActions ?? this.dailyHeavyActions,
      dailyLightActions: dailyLightActions ?? this.dailyLightActions,
      totalDecksGenerated: totalDecksGenerated ?? this.totalDecksGenerated,
      totalUploads: totalUploads ?? this.totalUploads,
      examsGenerated: examsGenerated ?? this.examsGenerated,
      lastDeckGenerationDate:
          lastDeckGenerationDate ?? this.lastDeckGenerationDate,
      updatedAt: updatedAt ?? this.updatedAt,
      isTrial: isTrial ?? _isTrialUser,
      isCreatorPro: isCreatorPro ?? this.isCreatorPro,
      hasLinkedCard: hasLinkedCard ?? this.hasLinkedCard,
      hasUsedTrial: hasUsedTrial ?? this.hasUsedTrial,
      currentProduct: currentProduct ?? this.currentProduct,
      referralCode: referralCode ?? this.referralCode,
      appliedReferralCode: appliedReferralCode ?? this.appliedReferralCode,
      referredBy: referredBy ?? this.referredBy,
      referralAppliedAt: referralAppliedAt ?? this.referralAppliedAt,
      totalReferrals: totalReferrals ?? this.totalReferrals,
      referrals: referrals ?? this.referrals,
      referralRewards: referralRewards ?? this.referralRewards,
      lastVerified: lastVerified ?? this.lastVerified,
      purchaseToken: purchaseToken ?? this.purchaseToken,
      creatorProfile: creatorProfile ?? this.creatorProfile,
      photoUrl: photoUrl ?? this.photoUrl,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      computeUnits: computeUnits ?? this.computeUnits,
      maxComputeCapacity: maxComputeCapacity ?? this.maxComputeCapacity,
      computeSessionId: computeSessionId ?? this.computeSessionId,
      isTrialActive: isTrialActive ?? this.isTrialActive,
      trialStartDate: trialStartDate ?? this.trialStartDate,
      lastCreditRefillDate: lastCreditRefillDate ?? this.lastCreditRefillDate,
      tier: tier ?? this.tier,
    );
  }
}
