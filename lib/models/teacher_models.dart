import 'package:cloud_firestore/cloud_firestore.dart';

/// Aggregate stats for the teacher dashboard overview
class TeacherStats {
  final int totalExams;
  final int totalStudyPacks;
  final int totalStudents;
  final int activeStudents; // active in last 7 days
  final double averageScore;
  final int totalAttempts;

  const TeacherStats({
    this.totalExams = 0,
    this.totalStudyPacks = 0,
    this.totalStudents = 0,
    this.activeStudents = 0,
    this.averageScore = 0.0,
    this.totalAttempts = 0,
  });
}

/// A student linked to one of the teacher's content items
class StudentLink {
  final String studentId;
  final String studentName;
  final String studentEmail;
  final String contentId;
  final String contentTitle;
  final DateTime joinedAt;
  final DateTime? lastActiveAt;
  final double averageScore;
  final int totalAttempts;
  final double completionRate;

  const StudentLink({
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.contentId,
    required this.contentTitle,
    required this.joinedAt,
    this.lastActiveAt,
    this.averageScore = 0.0,
    this.totalAttempts = 0,
    this.completionRate = 0.0,
  });

  factory StudentLink.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return StudentLink(
      studentId: d['studentId'] ?? doc.id,
      studentName: d['studentName'] ?? 'Anonymous',
      studentEmail: d['studentEmail'] ?? '',
      contentId: d['contentId'] ?? '',
      contentTitle: d['contentTitle'] ?? '',
      joinedAt: (d['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastActiveAt: (d['lastActiveAt'] as Timestamp?)?.toDate(),
      averageScore: (d['averageScore'] as num?)?.toDouble() ?? 0.0,
      totalAttempts: (d['totalAttempts'] as int?) ?? 0,
      completionRate: (d['completionRate'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Per-content engagement analytics
class ContentAnalytics {
  final String contentId;
  final String contentTitle;
  final int numberOfAttempts;
  final double averageScore;
  final double completionRate;
  final double engagementRate;
  final List<QuestionInsight> hardQuestions;

  const ContentAnalytics({
    required this.contentId,
    required this.contentTitle,
    this.numberOfAttempts = 0,
    this.averageScore = 0.0,
    this.completionRate = 0.0,
    this.engagementRate = 0.0,
    this.hardQuestions = const [],
  });
}

/// Insight about a difficult question
class QuestionInsight {
  final int questionIndex;
  final String questionText;
  final double failureRate;
  final String suggestion;

  const QuestionInsight({
    required this.questionIndex,
    required this.questionText,
    required this.failureRate,
    this.suggestion = '',
  });
}

/// A single event in the activity feed
class ActivityItem {
  final String type; // 'attempt' | 'creation' | 'alert'
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final String? contentId;

  const ActivityItem({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    this.contentId,
  });
}

/// Attempt record submitted by a student
class StudentAttempt {
  final String attemptId;
  final String studentId;
  final String studentName;
  final String contentId;
  final double score;
  final int totalQuestions;
  final int correctAnswers;
  final Map<String, dynamic> answers; // questionIndex -> studentAnswer
  final DateTime attemptedAt;
  final int timeTakenSeconds;

  const StudentAttempt({
    required this.attemptId,
    required this.studentId,
    required this.studentName,
    required this.contentId,
    required this.score,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.answers,
    required this.attemptedAt,
    this.timeTakenSeconds = 0,
  });

  factory StudentAttempt.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return StudentAttempt(
      attemptId: doc.id,
      studentId: d['studentId'] ?? '',
      studentName: d['studentName'] ?? 'Anonymous',
      contentId: d['contentId'] ?? '',
      score: (d['score'] as num?)?.toDouble() ?? 0.0,
      totalQuestions: (d['totalQuestions'] as int?) ?? 0,
      correctAnswers: (d['correctAnswers'] as int?) ?? 0,
      answers: Map<String, dynamic>.from(d['answers'] ?? {}),
      attemptedAt: (d['attemptedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      timeTakenSeconds: (d['timeTakenSeconds'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'studentId': studentId,
        'studentName': studentName,
        'contentId': contentId,
        'score': score,
        'totalQuestions': totalQuestions,
        'correctAnswers': correctAnswers,
        'answers': answers,
        'attemptedAt': Timestamp.fromDate(attemptedAt),
        'timeTakenSeconds': timeTakenSeconds,
      };
}
