import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:collection/collection.dart';

import '../models/spaced_repetition.dart';
import '../models/local_flashcard.dart';
import 'dart:developer' as developer;

class SpacedRepetitionService {
  final Box<SpacedRepetitionItem> _box;
  static const int freeSrsCardsMax = 50;

  SpacedRepetitionService(this._box);

  Future<void> scheduleReview(String flashcardId, String userId) async {
    // Check SRS card limit for FREE tier users
    final isPro = await _isUserPro(userId);
    if (!isPro) {
      final currentCardCount = await _getCurrentSrsCardCount(userId);
      if (currentCardCount >= freeSrsCardsMax) {
        throw Exception(
            'SRS card limit reached. Upgrade to Pro for unlimited cards.');
      }
    }

    final now = DateTime.now().toUtc();
    final newItem = SpacedRepetitionItem(
      id: flashcardId, // Use flashcardId as the key
      userId: userId,
      contentId: flashcardId,
      contentType: 'flashcards',
      nextReviewDate: now,
      lastReviewed: now,
      createdAt: now,
      updatedAt: now,
    );
    // Store using flashcardId so we can easily retrieve it later
    await _box.put(flashcardId, newItem);

    // Update SRS card count for FREE tier users
    if (!isPro) {
      try {
        final userDoc =
            FirebaseFirestore.instance.collection('users').doc(userId);
        await userDoc.update({
          'srsCardCount': FieldValue.increment(1),
        });
      } catch (e, s) {
        // Log error but don't fail the operation
        developer.log('Error updating SRS card count',
            name: 'SpacedRepetitionService', error: e, stackTrace: s);
      }
    }
  }

  /// Check if user has Pro access
  Future<bool> _isUserPro(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (!doc.exists) return false;

      final data = doc.data();
      if (data == null) return false;

      // Check for 'subscriptionExpiry' field
      if (data.containsKey('subscriptionExpiry')) {
        // Lifetime access is handled by a null expiry date
        if (data['subscriptionExpiry'] == null) return true;

        final expiryDate = (data['subscriptionExpiry'] as Timestamp).toDate();
        return expiryDate.isAfter(DateTime.now());
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Get current SRS card count for user
  Future<int> _getCurrentSrsCardCount(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (!doc.exists) return 0;

      final data = doc.data();
      if (data == null) return 0;

      return data['srsCardCount'] as int? ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Updates the SRS item using the SM-2 algorithm.
  /// [quality] should be 0-5:
  /// 5: perfect response
  /// 4: correct response after a hesitation
  /// 3: correct response recalled with serious difficulty
  /// 2: incorrect response; where the correct one seemed easy to recall
  /// 1: incorrect response; the correct one remembered
  /// 0: complete blackout.
  Future<void> updateReview(String itemId, bool answeredCorrectly, {int? quality}) async {
    var item = _box.get(itemId);
    item ??= _box.values.firstWhereOrNull((i) => i.contentId == itemId);
    if (item == null) return;

    final now = DateTime.now().toUtc();
    int repetitionCount;
    double easeFactor;
    int interval;
    int correctStreak;

    // Determine quality score (q)
    int q = quality ?? (answeredCorrectly ? 4 : 1);
    q = q.clamp(0, 5);

    if (q >= 3) {
      // Correct response
      correctStreak = item.correctStreak + 1;
      repetitionCount = item.repetitionCount + 1;
      
      // SM-2 Ease Factor calculation: EF' = EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
      // Using actual q value ensures easeFactor changes (increment of 0 for q=4)
      double efChange = 0.1 - (5 - q) * (0.08 + (5 - q) * 0.02);
      easeFactor = (item.easeFactor + efChange).clamp(1.3, 5.0).toDouble();

      if (repetitionCount == 1) {
        interval = 1;
      } else if (repetitionCount == 2) {
        interval = 6;
      } else {
        // Apply interval multiplier
        double multiplier = easeFactor;
        // Ease calculation for "Hard" (q=3) should grow slower than "Good" (q=4)
        if (q == 3) multiplier = 1.2; 
        
        interval = (item.interval * multiplier).round();
      }
    } else {
      // Incorrect response
      correctStreak = 0;
      repetitionCount = 0;
      interval = 1;
      easeFactor = item.easeFactor;
    }

    final updatedItem = SpacedRepetitionItem(
      id: item.id,
      userId: item.userId,
      contentId: item.contentId,
      contentType: item.contentType,
      nextReviewDate: now.add(Duration(days: interval)),
      lastReviewed: now,
      createdAt: item.createdAt,
      updatedAt: now,
      interval: interval,
      easeFactor: easeFactor,
      repetitionCount: repetitionCount,
      correctStreak: correctStreak,
    );

    await _box.put(item.id, updatedItem);
  }

  Future<List<String>> getDueFlashcardIds(String userId) async {
    final now = DateTime.now().toUtc();
    final dueItems = _box.values
        .where((item) =>
            item.userId == userId &&
            item.contentType == 'flashcards' &&
            (item.nextReviewDate.isBefore(now) || 
            item.nextReviewDate.isAtSameMomentAs(now)))
        .toList();
    dueItems.sort((a, b) => a.nextReviewDate.compareTo(b.nextReviewDate)); // Most overdue first
    return dueItems.map((item) => item.contentId).toList();
  }

  /// Get items that were recently failed (quality < 3) or have very low ease factor.
  Future<List<String>> getRecentlyFailedIds(String userId, {int limit = 10}) async {
    final failedItems = _box.values
        .where((item) =>
            item.userId == userId &&
            item.contentType == 'flashcards' &&
            (item.correctStreak == 0 || item.easeFactor < 1.7))
        .toList();
    failedItems.sort((a, b) => a.easeFactor.compareTo(b.easeFactor)); // Hardest first
    return failedItems.take(limit).map((item) => item.contentId).toList();
  }

  /// Check if a specific item is already tracked in SRS
  bool isItemTracked(String contentId) {
    return _box.containsKey(contentId);
  }

  /// Get all flashcards currently tracked in SRS
  Future<List<String>> getAllTrackedIds(String userId) async {
    return _box.values
        .where((item) => item.userId == userId && item.contentType == 'flashcards')
        .map((item) => item.contentId)
        .toList();
  }

  /// Alias for getDueFlashcardIds used by web frontend
  Future<List<String>> getDueItems(String userId) => getDueFlashcardIds(userId);

  /// Update progress for a specific flashcard from the web frontend
  Future<void> updateFlashcardProgress(
      String userId, String setId, String flashcardId, bool knewIt) {
    return updateReview(flashcardId, knewIt);
  }

  /// Demotes a specific flashcard because it was failed in a quiz.
  /// Sets quality to 1 (Incorrect, but remembered correct answer)
  Future<void> demoteFlashcard(String flashcardId) async {
    return updateReview(flashcardId, false, quality: 1);
  }

  /// Attempts to find a flashcard that matches the quiz question text and demotes it.
  Future<bool> demoteFlashcardByText(String userId, List<LocalFlashcard> flashcards, String questionText) async {
    // Basic text matching (case-insensitive, first 30 chars)
    final normalizedSearch = questionText.toLowerCase().trim();
    
    final matchingCard = flashcards.firstWhereOrNull((f) {
      final fText = f.question.toLowerCase().trim();
      return fText.contains(normalizedSearch) || normalizedSearch.contains(fText.substring(0, (fText.length < 20 ? fText.length : 20)));
    });

    if (matchingCard != null) {
      await demoteFlashcard(matchingCard.id);
      developer.log('Demoted matching flashcard: ${matchingCard.id}', name: 'SRS');
      return true;
    }
    return false;
  }

  /// Demotes a random "at risk" or tracked card from a specific list of flashcards.
  Future<void> demoteRandomFromList(String userId, List<LocalFlashcard> flashcards) async {
    if (flashcards.isEmpty) return;
    
    // Filter cards that are actually tracked in SRS
    final trackedInSet = flashcards.where((f) => isItemTracked(f.id)).toList();
    if (trackedInSet.isEmpty) return;

    // Pick a random card
    final randomCard = (trackedInSet..shuffle()).first;
    await demoteFlashcard(randomCard.id);
    developer.log('Demoted random flashcard as penalty: ${randomCard.id}', name: 'SRS');
  }

  Future<List<LocalFlashcard>> getDueFlashcards(
      String userId, List<LocalFlashcard> allFlashcards) async {
    final dueItemIds = await getDueFlashcardIds(userId);
    final dueItemIdsSet = dueItemIds.toSet();

    return allFlashcards
        .where((flashcard) => dueItemIdsSet.contains(flashcard.id))
        .toList();
  }

  Future<Map<String, dynamic>> getStatistics(String userId) async {
    final now = DateTime.now().toUtc();
    final startOfToday = DateTime.utc(now.year, now.month, now.day);
    final endOfWeek = startOfToday.add(const Duration(days: 7));

    final userItems =
        _box.values.where((item) => item.userId == userId).toList();

    final dueForReviewCount =
        userItems.where((item) => item.nextReviewDate.isBefore(now)).length;

    final upcomingReviews = userItems
        .where((item) =>
            item.nextReviewDate.isAfter(startOfToday) &&
            item.nextReviewDate.isBefore(endOfWeek))
        .groupListsBy((item) => DateTime.utc(item.nextReviewDate.year,
            item.nextReviewDate.month, item.nextReviewDate.day))
        .entries
        .map((entry) => MapEntry(entry.key, entry.value.length))
        .sortedBy<DateTime>((entry) => entry.key)
        .toList();

    return {
      'dueForReviewCount': dueForReviewCount,
      'upcomingReviews': upcomingReviews,
    };
  }

  /// Get the date of the very next review due (after now)
  DateTime? getNextReviewDate(String userId) {
    final now = DateTime.now().toUtc();
    final userItems =
        _box.values.where((item) => item.userId == userId).toList();

    if (userItems.isEmpty) return null;

    final futureReviews = userItems
        .where((item) => item.nextReviewDate.isAfter(now))
        .map((item) => item.nextReviewDate)
        .toList();

    if (futureReviews.isEmpty) return null;

    return futureReviews.reduce((a, b) => a.isBefore(b) ? a : b);
  }

  /// Calculate mastery score (0-100) based on SRS proficiency
  double getMasteryScore(String userId) {
    final userItems =
        _box.values.where((item) => item.userId == userId).toList();
    if (userItems.isEmpty) return 0.0;

    // Weight correct streak and ease factor
    double totalMastery = 0.0;
    for (var item in userItems) {
      double itemMastery = (item.correctStreak * 10) + (item.easeFactor * 10);
      if (itemMastery > 100) itemMastery = 100;
      totalMastery += itemMastery;
    }

    return totalMastery / userItems.length;
  }
}
