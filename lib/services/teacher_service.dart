import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:sumquiz/models/public_deck.dart';
import 'package:sumquiz/models/teacher_models.dart';

/// Firestore service dedicated to teacher dashboard operations.
class TeacherService {
  final _db = FirebaseFirestore.instance;

  // ─── CONTENT ───────────────────────────────────────────────────────────────

  /// Fetch all published decks (exams + study packs) created by this teacher.
  Future<List<PublicDeck>> getTeacherContent(String uid) async {
    final snap = await _db
        .collection('public_decks')
        .where('creatorId', isEqualTo: uid)
        .orderBy('publishedAt', descending: true)
        .get();
    return snap.docs.map((d) => PublicDeck.fromFirestore(d)).toList();
  }

  /// Delete a piece of content.
  Future<void> deleteContent(String contentId) async {
    await _db.collection('public_decks').doc(contentId).delete();
  }

  /// Duplicate content with a new ID and share code.
  Future<void> duplicateContent(PublicDeck deck, String newId, String newCode) async {
    final data = deck.toFirestore();
    data['id'] = newId;
    data['shareCode'] = newCode;
    data['publishedAt'] = Timestamp.fromDate(DateTime.now());
    data['title'] = '${deck.title} (Copy)';
    await _db.collection('public_decks').doc(newId).set(data);
  }

  /// Update content metadata.
  Future<void> updateContent(String contentId, Map<String, dynamic> updates) async {
    await _db.collection('public_decks').doc(contentId).update(updates);
  }

  // ─── STATS ─────────────────────────────────────────────────────────────────

  /// Aggregate dashboard stats for this teacher.
  Future<TeacherStats> getTeacherStats(String uid) async {
    final content = await getTeacherContent(uid);
    final exams = content.where((c) => c.isExam).length;
    final packs = content.where((c) => !c.isExam).length;

    int totalAttempts = 0;
    double totalScore = 0;
    int scoredAttempts = 0;
    final studentIds = <String>{};
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    final activeStudentIds = <String>{};

    // Limit to most recent 12 decks for stats calculation to prevent hanging on massive accounts
    final activeContent = content.take(12).toList();

    // Parallelize attempt fetching with overall timeout/error handling
    final snapshots = await Future.wait(activeContent.map((deck) => _db
        .collection('attempts')
        .where('contentId', isEqualTo: deck.id)
        .limit(50) // Don't fetch thousands of attempts for summary stats
        .get()));

    for (final snap in snapshots) {
      for (final a in snap.docs) {
        final data = a.data();
        totalAttempts++;
        final sid = data['studentId'] as String? ?? '';
        if (sid.isNotEmpty) studentIds.add(sid);
        
        final score = (data['score'] as num?)?.toDouble();
        if (score != null) {
          totalScore += score;
          scoredAttempts++;
        }
        
        final ts = (data['attemptedAt'] as Timestamp?)?.toDate();
        if (ts != null && ts.isAfter(sevenDaysAgo)) {
          if (sid.isNotEmpty) activeStudentIds.add(sid);
        }
      }
    }

    return TeacherStats(
      totalExams: exams,
      totalStudyPacks: packs,
      totalStudents: studentIds.length,
      activeStudents: activeStudentIds.length,
      averageScore: scoredAttempts > 0 ? totalScore / scoredAttempts : 0.0,
      totalAttempts: totalAttempts,
    );
  }

  // ─── STUDENTS ──────────────────────────────────────────────────────────────

  /// Get all unique students with their performance summary across this teacher's content.
  Future<List<StudentLink>> getStudentList(String uid) async {
    try {
      final content = await getTeacherContent(uid);
      final Map<String, StudentLink> studentMap = {};

      // Limit to most recent 20 decks for student list to prevent hanging
      final activeContent = content.take(20).toList();

      final snapshots = await Future.wait(activeContent.map((deck) => _db
          .collection('attempts')
          .where('contentId', isEqualTo: deck.id)
          .limit(50)
          .get()));

      for (int i = 0; i < activeContent.length; i++) {
        final deck = activeContent[i];
        final snap = snapshots[i];

        for (final doc in snap.docs) {
          final data = doc.data();
          final sid = data['studentId'] as String? ?? doc.id;
          final score = (data['score'] as num?)?.toDouble() ?? 0.0;
          final ts = (data['attemptedAt'] as Timestamp?)?.toDate();

          if (studentMap.containsKey(sid)) {
            final existing = studentMap[sid]!;
            studentMap[sid] = StudentLink(
              studentId: existing.studentId,
              studentName: existing.studentName,
              studentEmail: existing.studentEmail,
              contentId: existing.contentId,
              contentTitle: existing.contentTitle,
              joinedAt: existing.joinedAt,
              lastActiveAt: ts != null &&
                      (existing.lastActiveAt == null ||
                          ts.isAfter(existing.lastActiveAt!))
                  ? ts
                  : existing.lastActiveAt,
              averageScore: (existing.averageScore * existing.totalAttempts + score) /
                  (existing.totalAttempts + 1),
              totalAttempts: existing.totalAttempts + 1,
              completionRate: existing.completionRate,
            );
          } else {
            studentMap[sid] = StudentLink(
              studentId: sid,
              studentName: data['studentName']?.toString() ?? 'Anonymous',
              studentEmail: data['studentEmail']?.toString() ?? '',
              contentId: deck.id,
              contentTitle: deck.title,
              joinedAt: ts ?? DateTime.now(),
              lastActiveAt: ts,
              averageScore: score,
              totalAttempts: 1,
              completionRate: 100.0,
            );
          }
        }
      }

      final list = studentMap.values.toList();
      list.sort((a, b) => (b.lastActiveAt ?? DateTime(0))
          .compareTo(a.lastActiveAt ?? DateTime(0)));
      return list;
    } catch (e) {
      return []; // Return empty instead of hanging
    }
  }

  /// Manually link a student to a piece of content using its share code.
  Future<void> registerStudentWithCode(String uid, String studentEmail, String shareCode) async {
    // 1. Find the content by shareCode
    final deckSnap = await _db
        .collection('public_decks')
        .where('shareCode', isEqualTo: shareCode)
        .limit(1)
        .get();
    
    if (deckSnap.docs.isEmpty) throw Exception('Invalid share code');
    final deckId = deckSnap.docs.first.id;
    final deckTitle = deckSnap.docs.first.data()['title'] ?? 'Content';

    // 2. We mock the "link" by creating a dummy attempt or a proper student_link record if we had one.
    // For this architecture, student list is derived from attempts.
    // We'll create a "placeholder" attempt record to establish the link.
    await _db.collection('attempts').add({
      'contentId': deckId,
      'contentTitle': deckTitle,
      'studentEmail': studentEmail,
      'studentName': studentEmail.split('@').first,
      'studentId': 'manual_${DateTime.now().millisecondsSinceEpoch}',
      'attemptedAt': FieldValue.serverTimestamp(),
      'score': 0.0,
      'isManualLink': true,
    });
  }

  // ─── ANALYTICS ─────────────────────────────────────────────────────────────

  /// Get analytics for a specific content item.
  Future<ContentAnalytics> getContentAnalytics(PublicDeck deck) async {
    final attemptsSnap = await _db
        .collection('attempts')
        .where('contentId', isEqualTo: deck.id)
        .get();

    if (attemptsSnap.docs.isEmpty) {
      return ContentAnalytics(
        contentId: deck.id,
        contentTitle: deck.title,
      );
    }

    double totalScore = 0;
    int totalCorrect = 0;
    int totalQuestions = 0;
    final Map<int, int> failedCounts = {};

    for (final doc in attemptsSnap.docs) {
      final data = doc.data();
      totalScore += (data['score'] as num?)?.toDouble() ?? 0.0;
      totalCorrect += (data['correctAnswers'] as int?) ?? 0;
      totalQuestions += (data['totalQuestions'] as int?) ?? 0;

      // Tally failed questions
      final answers = data['answers'] as Map<String, dynamic>? ?? {};
      answers.forEach((key, value) {
        if (value is Map && value['correct'] == false) {
          final idx = int.tryParse(key) ?? -1;
          if (idx >= 0) failedCounts[idx] = (failedCounts[idx] ?? 0) + 1;
        }
      });
    }

    final count = attemptsSnap.docs.length;
    final avgScore = totalScore / count;

    // Build question insights for top 5 hardest
    final questions = (deck.quizData['questions'] as List<dynamic>?) ?? [];
    final insights = failedCounts.entries
        .where((e) => e.key < questions.length)
        .map((e) => QuestionInsight(
              questionIndex: e.key,
              questionText: questions[e.key]['question']?.toString() ??
                  'Question ${e.key + 1}',
              failureRate: e.value / count * 100,
            ))
        .toList()
      ..sort((a, b) => b.failureRate.compareTo(a.failureRate));

    return ContentAnalytics(
      contentId: deck.id,
      contentTitle: deck.title,
      numberOfAttempts: count,
      averageScore: avgScore,
      completionRate:
          totalQuestions > 0 ? totalCorrect / totalQuestions * 100 : 0,
      engagementRate: count > 0 ? 100.0 : 0.0,
      hardQuestions: insights.take(5).toList(),
    );
  }

  // ─── ACTIVITY ──────────────────────────────────────────────────────────────

  /// Get recent activity items for the activity feed.
  Future<List<ActivityItem>> getRecentActivity(String uid) async {
    final content = await getTeacherContent(uid);
    final items = <ActivityItem>[];

    // Recently created content (first 3)
    for (final deck in content.take(3)) {
      items.add(ActivityItem(
        type: 'creation',
        title: 'Published: ${deck.title}',
        subtitle: deck.isExam ? 'Exam paper' : 'Study pack',
        timestamp: deck.publishedAt,
        contentId: deck.id,
      ));
    }

    // Recent student attempts across last 5 items
    final activeDecks = content.take(5).toList();
    for (final deck in activeDecks) {
      final attempts = await _db
          .collection('attempts')
          .where('contentId', isEqualTo: deck.id)
          .orderBy('attemptedAt', descending: true)
          .limit(3)
          .get();

      for (final doc in attempts.docs) {
        final data = doc.data();
        final score = (data['score'] as num?)?.toDouble() ?? 0.0;
        items.add(ActivityItem(
          type: 'attempt',
          title: '${data['studentName'] ?? 'A student'} attempted ${deck.title}',
          subtitle: 'Score: ${score.toStringAsFixed(0)}%',
          timestamp:
              (data['attemptedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          contentId: deck.id,
        ));
      }
    }

    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return items.take(12).toList();
  }

  /// Get attempt counts over the last 30 days for trend analysis.
  Future<Map<String, int>> getCompletionTrends(String uid) async {
    final content = await getTeacherContent(uid);
    final contentIds = content.map((c) => c.id).toList();
    if (contentIds.isEmpty) return {};

    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final Map<String, int> trends = {};

    // Initialize map with last 30 days
    for (int i = 0; i < 30; i++) {
       final date = DateTime.now().subtract(Duration(days: i));
       final dayStr = DateFormat('yyyy-MM-dd').format(date);
       trends[dayStr] = 0;
    }

    for (final id in contentIds) {
      final snap = await _db
          .collection('attempts')
          .where('contentId', isEqualTo: id)
          .where('attemptedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
          .get();
      
      for (final doc in snap.docs) {
        final ts = (doc.data()['attemptedAt'] as Timestamp?)?.toDate();
        if (ts != null) {
          final dayStr = DateFormat('yyyy-MM-dd').format(ts);
          if (trends.containsKey(dayStr)) {
            trends[dayStr] = trends[dayStr]! + 1;
          }
        }
      }
    }
    return trends;
  }
}
