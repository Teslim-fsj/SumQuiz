import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';

class ProgressService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<int> getSummariesCount(String userId) async {
    try {
      final snapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('summaries')
          .get();
      return snapshot.docs.length;
    } catch (e) {
      // Log error and return 0 as fallback
      debugPrint('Error getting summaries count: $e');
      return 0;
    }
  }

  /// Check if user has Pro access
  Future<bool> isUserPro(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
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

  Future<int> getQuizzesCount(String userId) async {
    try {
      final snapshot =
          await _db.collection('users').doc(userId).collection('quizzes').get();
      return snapshot.docs.length;
    } catch (e) {
      // Log error and return 0 as fallback
      debugPrint('Error getting quizzes count: $e');
      return 0;
    }
  }

  Future<int> getFlashcardsCount(String userId) async {
    try {
      final snapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('flashcards')
          .get();
      return snapshot.docs.length;
    } catch (e) {
      // Log error and return 0 as fallback
      debugPrint('Error getting flashcards count: $e');
      return 0;
    }
  }

  Future<Map<String, double>> getAccuracyStats(String userId) async {
    try {
      final quizzesSnapshot =
          await _db.collection('users').doc(userId).collection('quizzes').get();

      if (quizzesSnapshot.docs.isEmpty) {
        return {'average': 0.0, 'highest': 0.0, 'lowest': 0.0};
      }

      double totalAccuracy = 0.0;
      double highest = 0.0;
      double lowest = 1.0;
      int quizCount = 0;

      for (var doc in quizzesSnapshot.docs) {
        final data = doc.data();
        if (data.containsKey('accuracy') && data['accuracy'] != null) {
          double acc = (data['accuracy'] as num).toDouble();
          totalAccuracy += acc;
          if (acc > highest) highest = acc;
          if (acc < lowest) lowest = acc;
          quizCount++;
        }
      }

      if (quizCount == 0) {
        return {'average': 0.0, 'highest': 0.0, 'lowest': 0.0};
      }

      return {
        'average': totalAccuracy / quizCount,
        'highest': highest,
        'lowest': lowest,
      };
    } catch (e) {
      debugPrint('Error getting accuracy stats: $e');
      return {'average': 0.0, 'highest': 0.0, 'lowest': 0.0};
    }
  }

  Future<double> getAverageAccuracy(String userId) async {
    final stats = await getAccuracyStats(userId);
    return stats['average'] ?? 0.0;
  }

  Future<int> getTotalTimeSpent(String userId) async {
    try {
      // Get all quizzes for the user
      final quizzesSnapshot =
          await _db.collection('users').doc(userId).collection('quizzes').get();

      int totalTime = 0;

      for (var doc in quizzesSnapshot.docs) {
        final data = doc.data();
        if (data.containsKey('time_spent') && data['time_spent'] != null) {
          totalTime += (data['time_spent'] as num).toInt();
        }
      }

      return totalTime;
    } catch (e) {
      debugPrint('Error getting total time spent: $e');
      return 0;
    }
  }

  Future<List<FlSpot>> getWeeklyActivity(String userId) async {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final activity = <double>[0, 0, 0, 0, 0, 0, 0];

    // Calculate the start of the week (7 days ago)
    final startOfWeek = startOfToday.subtract(const Duration(days: 6));

    final summaries = await _db
        .collection('users')
        .doc(userId)
        .collection('summaries')
        .where('created_at', isGreaterThanOrEqualTo: startOfWeek)
        .get();

    final quizzes = await _db
        .collection('users')
        .doc(userId)
        .collection('quizzes')
        .where('created_at', isGreaterThanOrEqualTo: startOfWeek)
        .get();

    final flashcards = await _db
        .collection('users')
        .doc(userId)
        .collection('flashcards')
        .where('created_at', isGreaterThanOrEqualTo: startOfWeek)
        .get();

    void incrementActivity(DateTime createdAt) {
      final daysDifference = startOfToday
          .difference(DateTime(createdAt.year, createdAt.month, createdAt.day))
          .inDays;

      // Only count activities within the last 7 days
      if (daysDifference >= 0 && daysDifference < 7) {
        activity[daysDifference]++;
      }
    }

    for (var doc in summaries.docs) {
      final createdAt = (doc.data()['created_at'] as Timestamp).toDate();
      incrementActivity(createdAt);
    }

    for (var doc in quizzes.docs) {
      final createdAt = (doc.data()['created_at'] as Timestamp).toDate();
      incrementActivity(createdAt);
    }

    for (var doc in flashcards.docs) {
      final createdAt = (doc.data()['created_at'] as Timestamp).toDate();
      incrementActivity(createdAt);
    }

    return List.generate(
        7, (index) => FlSpot(index.toDouble(), activity[index]));
  }

  Future<void> logAccuracy(String userId, double accuracy) async {
    try {
      await _db.collection('users').doc(userId).update({
        'itemsCompletedToday': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('Error logging accuracy: $e');
    }
  }

  /// Logs a complete study session to Firestore for cross-platform analytics
  Future<void> logStudySession({
    required String userId,
    required double accuracy,
    required int durationSeconds,
    String? setId,
  }) async {
    try {
      final now = DateTime.now();
      
      // 1. Update user aggregate stats
      await _db.collection('users').doc(userId).update({
        'totalStudyTime': FieldValue.increment(durationSeconds),
        'itemsCompleted': FieldValue.increment(1),
        'lastActive': Timestamp.fromDate(now),
      });

      // 2. Log specific session entry for detailed analytics
      await _db.collection('users').doc(userId).collection('quizzes').add({
        'accuracy': accuracy,
        'time_spent': durationSeconds,
        'created_at': Timestamp.fromDate(now),
        'setId': setId ?? 'mission',
        'platform': 'web',
      });
      
      debugPrint('Study session logged successfully for web user: $userId');
    } catch (e) {
      debugPrint('Error logging study session for web: $e');
    }
  }
}
