import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:sumquiz/models/creator_application.dart';
import 'package:sumquiz/models/creator_profile.dart';
import 'package:sumquiz/models/creator_resource.dart';
import 'package:sumquiz/models/creator_referral.dart';
import 'package:sumquiz/models/creator_payout.dart';
import 'package:sumquiz/models/creator_achievement.dart';

/// Service for all Creator Growth Program Firestore operations.
class CreatorProgramService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  // ─── Collection References ──────────────────────────────────────────────────

  CollectionReference get _applications =>
      _firestore.collection('creator_applications');

  CollectionReference get _profiles =>
      _firestore.collection('creator_profiles');

  CollectionReference get _clicks =>
      _firestore.collection('creator_referral_clicks');

  CollectionReference get _resources =>
      _firestore.collection('creator_resources');

  CollectionReference get _referrals =>
      _firestore.collection('creator_referrals');

  CollectionReference get _payouts =>
      _firestore.collection('creator_payouts');

  CollectionReference get _achievements =>
      _firestore.collection('creator_achievements');

  // ─── Applications ────────────────────────────────────────────────────────────

  /// Submit a new creator application.
  Future<String> submitApplication(CreatorApplication application) async {
    try {
      // Check for duplicate email
      final existing = await _applications
          .where('email', isEqualTo: application.email)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        throw Exception('An application with this email already exists.');
      }

      final docRef = await _applications.add(application.toMap());
      developer.log('Creator application submitted: ${docRef.id}',
          name: 'CreatorProgramService');
      return docRef.id;
    } catch (e) {
      developer.log('Error submitting creator application',
          name: 'CreatorProgramService', error: e);
      rethrow;
    }
  }

  /// Stream all applications (for admin), optionally filtered by status.
  Stream<List<CreatorApplication>> getApplicationsStream({
    ApplicationStatus? status,
  }) {
    Query query = _applications.orderBy('appliedAt', descending: true);
    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }
    return query.snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => CreatorApplication.fromMap(
                    doc.data() as Map<String, dynamic>,
                    doc.id,
                  ))
              .toList(),
        );
  }

  /// Get a single application by ID.
  Future<CreatorApplication?> getApplication(String id) async {
    final doc = await _applications.doc(id).get();
    if (!doc.exists) return null;
    return CreatorApplication.fromMap(
        doc.data() as Map<String, dynamic>, doc.id);
  }

  /// Approve an application and create a creator profile.
  Future<void> approveApplication(
    String applicationId, {
    String? reviewerEmail,
  }) async {
    final appDoc = await _applications.doc(applicationId).get();
    if (!appDoc.exists) throw Exception('Application not found');

    final app = CreatorApplication.fromMap(
        appDoc.data() as Map<String, dynamic>, appDoc.id);

    // Generate SUMI-prefixed referral code
    final namePart = app.fullName
        .replaceAll(' ', '')
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z]'), '');
    final suffix = namePart.length >= 4
        ? namePart.substring(0, 4)
        : namePart.padRight(4, 'X');
    final referralCode = 'SUMI$suffix';

    // Ensure uniqueness
    final existing =
        await _profiles.where('referralCode', isEqualTo: referralCode).get();
    final finalCode = existing.docs.isEmpty
        ? referralCode
        : 'SUMI${_uuid.v4().substring(0, 4).toUpperCase()}';

    const baseUrl = 'https://sumquiz.app/c';
    final referralLink = '$baseUrl/$finalCode';

    // Batch: update application + create profile
    final batch = _firestore.batch();

    batch.update(_applications.doc(applicationId), {
      'status': ApplicationStatus.approved.name,
      'reviewedAt': FieldValue.serverTimestamp(),
      if (reviewerEmail != null) 'reviewedBy': reviewerEmail,
    });

    final profileRef = _profiles.doc(applicationId);
    final profile = CreatorProfile(
      creatorId: applicationId,
      applicationId: applicationId,
      fullName: app.fullName,
      email: app.email,
      niche: app.niche,
      referralCode: finalCode,
      referralLink: referralLink,
      joinedAt: DateTime.now(),
      status: 'active',
    );
    batch.set(profileRef, profile.toMap());

    // Queue an approval email via "mail" collection (Firebase Email Extension)
    final mailRef = _firestore.collection('mail').doc();
    batch.set(mailRef, {
      'to': app.email,
      'message': {
        'subject': '🎉 You\'re Approved! Welcome to the SumQuiz Creator Program',
        'text':
            'Hi ${app.fullName},\n\nCongratulations! Your application to the SumQuiz Creator Program has been approved.\n\nYour referral code: $finalCode\nYour referral link: $referralLink\n\nLogin at https://sumquiz.app to access your creator dashboard.\n\nTeam SumQuiz',
        'html':
            '<h2>🎉 Welcome to SumQuiz Creator Program!</h2><p>Hi ${app.fullName},</p><p>Your application has been <strong>approved</strong>.</p><p><strong>Referral Code:</strong> $finalCode</p><p><strong>Referral Link:</strong> <a href="$referralLink">$referralLink</a></p>',
      },
    });

    await batch.commit();
    developer.log('Application approved: $applicationId code=$finalCode',
        name: 'CreatorProgramService');
  }

  /// Reject an application.
  Future<void> rejectApplication(
    String applicationId, {
    String? reviewerEmail,
  }) async {
    await _applications.doc(applicationId).update({
      'status': ApplicationStatus.rejected.name,
      'reviewedAt': FieldValue.serverTimestamp(),
      if (reviewerEmail != null) 'reviewedBy': reviewerEmail,
    });
    developer.log('Application rejected: $applicationId',
        name: 'CreatorProgramService');
  }

  // ─── Creator Profiles (Suspend/Reactivate) ───────────────────────────────────

  /// Stream a creator profile by application/creator ID.
  Stream<CreatorProfile?> getCreatorProfileStream(String creatorId) {
    return _profiles.doc(creatorId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return CreatorProfile.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    });
  }

  /// Get all active/suspended creator profiles (for admin leaderboard).
  Stream<List<CreatorProfile>> getAllCreatorProfilesStream() {
    return _profiles
        .orderBy('totalSignups', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) =>
                CreatorProfile.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  /// Suspend a creator's profile
  Future<void> suspendCreator(String creatorId) async {
    await _profiles.doc(creatorId).update({
      'status': 'suspended',
      'isActive': false,
    });
    developer.log('Creator suspended: $creatorId', name: 'CreatorProgramService');
  }

  /// Reactivate a creator's profile
  Future<void> reactivateCreator(String creatorId) async {
    await _profiles.doc(creatorId).update({
      'status': 'active',
      'isActive': true,
    });
    developer.log('Creator reactivated: $creatorId', name: 'CreatorProgramService');
  }

  // ─── Referral Click Attribution ─────────────────────────────────────────────

  /// Record a click on a referral link.
  Future<void> recordClick(String referralCode) async {
    try {
      await _clicks.add({
        'referralCode': referralCode,
        'clickedAt': FieldValue.serverTimestamp(),
      });

      // Increment totalClicks on the profile with this code
      final profileQuery = await _profiles
          .where('referralCode', isEqualTo: referralCode)
          .limit(1)
          .get();

      if (profileQuery.docs.isNotEmpty) {
        await profileQuery.docs.first.reference.update({
          'totalClicks': FieldValue.increment(1),
        });
      }
    } catch (e) {
      developer.log('Error recording referral click',
          name: 'CreatorProgramService', error: e);
    }
  }

  // ─── Complete Attribution Pipeline (Feature 1) ────────────────────────────────

  /// Attribute registration/signup to creator
  Future<void> trackSignup(String userId, String email, String referralCode) async {
    try {
      final profileQuery = await _profiles
          .where('referralCode', isEqualTo: referralCode)
          .limit(1)
          .get();

      if (profileQuery.docs.isEmpty) return;

      final creatorDoc = profileQuery.docs.first;
      final creatorId = creatorDoc.id;

      // Check if registration is already tracked (Idempotency)
      final existing = await _referrals.doc(userId).get();
      if (existing.exists) return;

      final referral = CreatorReferral(
        id: userId,
        creatorId: creatorId,
        referralCode: referralCode,
        userId: userId,
        email: email,
        clickedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        registeredAt: DateTime.now(),
        status: 'registered',
      );

      // Save referral attribution & increment creator signups
      final batch = _firestore.batch();
      batch.set(_referrals.doc(userId), referral.toMap());
      batch.update(creatorDoc.reference, {
        'totalSignups': FieldValue.increment(1),
      });

      await batch.commit();

      // Trigger achievement check
      await checkAndUnlockAchievements(creatorId);
    } catch (e) {
      developer.log('Error tracking creator referral signup: $e', name: 'CreatorProgramService');
    }
  }

  /// Attribute first login
  Future<void> trackLogin(String userId) async {
    try {
      final doc = await _referrals.doc(userId).get();
      if (!doc.exists) return;

      final data = doc.data() as Map<String, dynamic>;
      if (data['firstLoginAt'] != null) return; // already tracked

      await _referrals.doc(userId).update({
        'firstLoginAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });
    } catch (e) {
      developer.log('Error tracking creator login: $e', name: 'CreatorProgramService');
    }
  }

  /// Attribute first AI summary
  Future<void> trackSummary(String userId) async {
    try {
      final doc = await _referrals.doc(userId).get();
      if (!doc.exists) return;

      final data = doc.data() as Map<String, dynamic>;
      if (data['firstSummaryAt'] != null) return; // already tracked

      await _referrals.doc(userId).update({
        'firstSummaryAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });
    } catch (e) {
      developer.log('Error tracking creator summary: $e', name: 'CreatorProgramService');
    }
  }

  /// Attribute first quiz generated
  Future<void> trackQuiz(String userId) async {
    try {
      final doc = await _referrals.doc(userId).get();
      if (!doc.exists) return;

      final data = doc.data() as Map<String, dynamic>;
      if (data['firstQuizAt'] != null) return; // already tracked

      await _referrals.doc(userId).update({
        'firstQuizAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });
    } catch (e) {
      developer.log('Error tracking creator quiz: $e', name: 'CreatorProgramService');
    }
  }

  /// Attribute subscription purchase and update revenue
  Future<void> trackSubscription(String userId, double price) async {
    try {
      final doc = await _referrals.doc(userId).get();
      if (!doc.exists) return;

      final referral = CreatorReferral.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      final creatorId = referral.creatorId;

      final creatorDoc = await _profiles.doc(creatorId).get();
      if (!creatorDoc.exists) return;

      final creatorProfile = CreatorProfile.fromMap(
          creatorDoc.data() as Map<String, dynamic>, creatorDoc.id);

      final batch = _firestore.batch();

      // Check if this is the first subscription for this referred user
      final isFirstSub = referral.firstSubscriptionAt == null;
      final newStatus = 'paid';

      batch.update(_referrals.doc(userId), {
        if (isFirstSub) 'firstSubscriptionAt': FieldValue.serverTimestamp(),
        'revenueGenerated': FieldValue.increment(price),
        'status': newStatus,
      });

      // Calculate commission (e.g. 20%)
      final commissionAmount = price * (creatorProfile.commissionPercentage / 100.0);

      batch.update(_profiles.doc(creatorId), {
        if (isFirstSub) 'totalPaid': FieldValue.increment(1),
        'revenueGenerated': FieldValue.increment(price),
        'pendingEarnings': FieldValue.increment(commissionAmount),
      });

      await batch.commit();

      // Trigger achievement check
      await checkAndUnlockAchievements(creatorId);
    } catch (e) {
      developer.log('Error tracking creator subscription: $e', name: 'CreatorProgramService');
    }
  }

  // ─── Payout Tracking (Feature 5) ──────────────────────────────────────────────

  /// Get payout history for a creator
  Stream<List<CreatorPayout>> getPayoutsStream(String creatorId) {
    return _payouts
        .where('creatorId', isEqualTo: creatorId)
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => CreatorPayout.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  /// Request a payout (creator initiates)
  Future<void> requestPayout(String creatorId, double amount) async {
    final profileDoc = await _profiles.doc(creatorId).get();
    if (!profileDoc.exists) throw Exception('Creator profile not found');

    final profile = CreatorProfile.fromMap(
        profileDoc.data() as Map<String, dynamic>, profileDoc.id);

    if (profile.pendingEarnings < amount) {
      throw Exception('Insufficient pending earnings');
    }

    final batch = _firestore.batch();
    
    // Create payout record
    final payoutRef = _payouts.doc();
    final payout = CreatorPayout(
      id: payoutRef.id,
      creatorId: creatorId,
      amount: amount,
      status: 'pending',
      requestedAt: DateTime.now(),
    );

    batch.set(payoutRef, payout.toMap());

    // Deduct from pending earnings
    batch.update(_profiles.doc(creatorId), {
      'pendingEarnings': FieldValue.increment(-amount),
    });

    await batch.commit();
  }

  /// Process payout (admin marks as paid/completed)
  Future<void> completePayout(String payoutId, String details) async {
    final doc = await _payouts.doc(payoutId).get();
    if (!doc.exists) throw Exception('Payout not found');

    final payout = CreatorPayout.fromMap(doc.data() as Map<String, dynamic>, doc.id);

    final batch = _firestore.batch();
    
    batch.update(_payouts.doc(payoutId), {
      'status': 'paid',
      'paidAt': FieldValue.serverTimestamp(),
      'paymentMethodDetails': details,
    });

    batch.update(_profiles.doc(payout.creatorId), {
      'paidEarnings': FieldValue.increment(payout.amount),
    });

    await batch.commit();
  }

  // ─── Achievements System (Feature 7) ──────────────────────────────────────────

  /// Stream achievements for a creator
  Stream<List<CreatorAchievement>> getAchievementsStream(String creatorId) {
    return _achievements
        .where('creatorId', isEqualTo: creatorId)
        .orderBy('unlockedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => CreatorAchievement.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  /// Automatically checks stats and unlocks new achievements
  Future<void> checkAndUnlockAchievements(String creatorId) async {
    try {
      final doc = await _profiles.doc(creatorId).get();
      if (!doc.exists) return;

      final profile = CreatorProfile.fromMap(
          doc.data() as Map<String, dynamic>, doc.id);

      final unlockedSnap = await _achievements
          .where('creatorId', isEqualTo: creatorId)
          .get();
      final unlockedIds = unlockedSnap.docs
          .map((d) => d['achievementId'] as String)
          .toSet();

      final List<Map<String, dynamic>> milestones = [
        {
          'id': 'first_referral',
          'title': 'First Referral',
          'description': 'You referred your first user link click!',
          'emoji': '🔗',
          'check': profile.totalClicks >= 1,
        },
        {
          'id': 'first_signup',
          'title': 'First Signup',
          'description': 'Your first referred student signed up!',
          'emoji': '🎓',
          'check': profile.totalSignups >= 1,
        },
        {
          'id': 'signups_10',
          'title': 'Rising Star',
          'description': 'Attained 10 registered student signups.',
          'emoji': '⭐',
          'check': profile.totalSignups >= 10,
        },
        {
          'id': 'signups_50',
          'title': 'Campus Leader',
          'description': 'Attained 50 registered student signups.',
          'emoji': '🔥',
          'check': profile.totalSignups >= 50,
        },
        {
          'id': 'signups_100',
          'title': 'SumQuiz Champion',
          'description': 'Attained 100 registered student signups.',
          'emoji': '🏆',
          'check': profile.totalSignups >= 100,
        },
        {
          'id': 'first_paid',
          'title': 'Premium Catalyst',
          'description': 'Your first referred user upgraded to Pro!',
          'emoji': '💎',
          'check': profile.totalPaid >= 1,
        },
        {
          'id': 'rev_10k',
          'title': 'Bronze Earner',
          'description': r'Generated $10 (or local equivalent ₦10,000) in program revenue.',
          'emoji': '🥉',
          'check': profile.revenueGenerated >= 10.0,
        },
        {
          'id': 'rev_50k',
          'title': 'Silver Earner',
          'description': r'Generated $50 (or local equivalent ₦50,000) in program revenue.',
          'emoji': '🥈',
          'check': profile.revenueGenerated >= 50.0,
        },
        {
          'id': 'rev_100k',
          'title': 'Gold Earner',
          'description': r'Generated $100 (or local equivalent ₦100,000) in program revenue.',
          'emoji': '🥇',
          'check': profile.revenueGenerated >= 100.0,
        },
      ];

      for (final m in milestones) {
        if (m['check'] == true && !unlockedIds.contains(m['id'])) {
          await _achievements.add({
            'creatorId': creatorId,
            'achievementId': m['id'],
            'title': m['title'],
            'description': m['description'],
            'emoji': m['emoji'],
            'unlockedAt': FieldValue.serverTimestamp(),
          });
          developer.log('Unlocked achievement ${m['id']} for creator $creatorId', name: 'CreatorProgramService');
        }
      }
    } catch (e) {
      developer.log('Error checking achievements: $e', name: 'CreatorProgramService');
    }
  }

  // ─── Resource Library (Bookmarks & Download Tracking) ────────────────────────

  /// Stream resources, optionally filtered by category.
  Stream<List<CreatorResource>> getResourcesStream({String? category}) {
    Query query = _resources.orderBy('order');
    if (category != null) {
      query = query.where('category', isEqualTo: category);
    }
    return query.snapshots().map((snap) => snap.docs
        .map((d) =>
            CreatorResource.fromMap(d.data() as Map<String, dynamic>, d.id))
        .toList());
  }

  /// Toggle bookmarks on a resource
  Future<void> toggleBookmarkResource(String resourceId, String creatorId) async {
    final docRef = _resources.doc(resourceId);
    final doc = await docRef.get();
    if (!doc.exists) return;

    final data = doc.data() as Map<String, dynamic>;
    final List<dynamic> bookmarks = data['bookmarkedBy'] ?? [];

    if (bookmarks.contains(creatorId)) {
      await docRef.update({
        'bookmarkedBy': FieldValue.arrayRemove([creatorId]),
      });
    } else {
      await docRef.update({
        'bookmarkedBy': FieldValue.arrayUnion([creatorId]),
      });
    }
  }

  /// Track download
  Future<void> trackDownload(String resourceId) async {
    await _resources.doc(resourceId).update({
      'downloadCount': FieldValue.increment(1),
    });
  }

  /// Seed default resources if collection is empty.
  Future<void> seedResourcesIfEmpty() async {
    final existing = await _resources.limit(1).get();
    if (existing.docs.isNotEmpty) return;

    final now = DateTime.now();
    final defaults = [
      // Brand Kit / Mascot
      {
        'category': 'brand-assets',
        'title': 'Official Logos and Brand Guidelines',
        'description': 'High-resolution primary and secondary SumQuiz logos (PNG/SVG) and color guides.',
        'externalUrl': 'https://sumquiz.app/brand/logos',
        'tags': ['brand-kit', 'logos'],
        'order': 1,
        'emoji': '🎨',
        'createdAt': Timestamp.fromDate(now),
        'downloadCount': 0,
        'bookmarkedBy': [],
      },
      {
        'category': 'brand-assets',
        'title': 'Sumi Mascot Asset Pack',
        'description': 'Official Sumi Mascot assets in multiple poses (happy, thinking, celebrating).',
        'externalUrl': 'https://sumquiz.app/brand/sumi',
        'tags': ['mascot', 'sumi'],
        'order': 2,
        'emoji': '👾',
        'createdAt': Timestamp.fromDate(now),
        'downloadCount': 0,
        'bookmarkedBy': [],
      },
      // Canva / Video Templates
      {
        'category': 'video-ideas',
        'title': 'TikTok study challenge hooks & templates',
        'description': 'A collection of the top-performing TikTok/Reels outline scripts and screen configurations.',
        'tags': ['canva-templates', 'video-templates'],
        'order': 3,
        'emoji': '🎬',
        'createdAt': Timestamp.fromDate(now),
        'downloadCount': 0,
        'bookmarkedBy': [],
      },
      // Social / Captions / Hooks
      {
        'category': 'content-templates',
        'title': '50 Viral Hooks & Copy-Paste Captions',
        'description': 'Grab attention instantly with study hacks, active recall tricks, and exam prep captions.',
        'tags': ['captions', 'hooks', 'content-ideas'],
        'order': 4,
        'emoji': '✍️',
        'createdAt': Timestamp.fromDate(now),
        'downloadCount': 0,
        'bookmarkedBy': [],
      },
    ];

    final batch = _firestore.batch();
    for (final resource in defaults) {
      batch.set(_resources.doc(), resource);
    }
    await batch.commit();
    developer.log('Seeded ${defaults.length} default creator resources',
        name: 'CreatorProgramService');
  }

  // ─── Statistics ───────────────────────────────────────────────────────────────

  /// Get aggregate statistics for admin dashboard.
  Future<Map<String, int>> getApplicationStats() async {
    final all = await _applications.get();
    int pending = 0, approved = 0, rejected = 0;
    for (final doc in all.docs) {
      final status = (doc.data() as Map<String, dynamic>)['status'] ?? 'pending';
      if (status == 'approved') {
        approved++;
      } else if (status == 'rejected') {
        rejected++;
      } else {
        pending++;
      }
    }
    return {
      'total': all.docs.length,
      'pending': pending,
      'approved': approved,
      'rejected': rejected,
    };
  }

  /// Retrieve referred users stream for dashboard recent activity
  Stream<List<CreatorReferral>> getReferredUsersStream(String creatorId) {
    return _referrals
        .where('creatorId', isEqualTo: creatorId)
        .orderBy('registeredAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => CreatorReferral.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList());
  }
}
