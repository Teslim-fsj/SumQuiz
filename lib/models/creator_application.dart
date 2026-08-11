import 'package:cloud_firestore/cloud_firestore.dart';

enum ApplicationStatus { pending, approved, rejected }

enum CreatorNiche {
  education,
  productivity,
  studentInfluencer,
  studyTips,
  examPrep,
  other,
}

extension CreatorNicheExtension on CreatorNiche {
  String get label {
    switch (this) {
      case CreatorNiche.education:
        return 'Education';
      case CreatorNiche.productivity:
        return 'Productivity';
      case CreatorNiche.studentInfluencer:
        return 'Student Influencer';
      case CreatorNiche.studyTips:
        return 'Study Tips';
      case CreatorNiche.examPrep:
        return 'Exam Prep';
      case CreatorNiche.other:
        return 'Other';
    }
  }
}

class CreatorApplication {
  final String id;
  final String fullName;
  final String email;
  final String country;
  final String niche;
  final String audienceType;
  final int totalFollowers;
  final String? tiktokHandle;
  final String? instagramHandle;
  final String? youtubeHandle;
  final String? xHandle;
  final String whyJoin;
  final ApplicationStatus status;
  final DateTime appliedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? userId;

  const CreatorApplication({
    required this.id,
    required this.fullName,
    required this.email,
    required this.country,
    required this.niche,
    required this.audienceType,
    required this.totalFollowers,
    this.tiktokHandle,
    this.instagramHandle,
    this.youtubeHandle,
    this.xHandle,
    required this.whyJoin,
    this.status = ApplicationStatus.pending,
    required this.appliedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.userId,
  });

  factory CreatorApplication.fromMap(Map<String, dynamic> map, String id) {
    return CreatorApplication(
      id: id,
      fullName: map['fullName'] ?? '',
      email: map['email'] ?? '',
      country: map['country'] ?? '',
      niche: map['niche'] ?? 'other',
      audienceType: map['audienceType'] ?? 'mixed',
      totalFollowers: (map['totalFollowers'] as num?)?.toInt() ?? 0,
      tiktokHandle: map['tiktokHandle'],
      instagramHandle: map['instagramHandle'],
      youtubeHandle: map['youtubeHandle'],
      xHandle: map['xHandle'],
      whyJoin: map['whyJoin'] ?? '',
      status: ApplicationStatus.values.firstWhere(
        (e) => e.name == (map['status'] ?? 'pending'),
        orElse: () => ApplicationStatus.pending,
      ),
      appliedAt: (map['appliedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reviewedAt: (map['reviewedAt'] as Timestamp?)?.toDate(),
      reviewedBy: map['reviewedBy'],
      userId: map['userId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'email': email,
      'country': country,
      'niche': niche,
      'audienceType': audienceType,
      'totalFollowers': totalFollowers,
      if (tiktokHandle != null) 'tiktokHandle': tiktokHandle,
      if (instagramHandle != null) 'instagramHandle': instagramHandle,
      if (youtubeHandle != null) 'youtubeHandle': youtubeHandle,
      if (xHandle != null) 'xHandle': xHandle,
      'whyJoin': whyJoin,
      'status': status.name,
      'appliedAt': Timestamp.fromDate(appliedAt),
      if (reviewedAt != null) 'reviewedAt': Timestamp.fromDate(reviewedAt!),
      if (reviewedBy != null) 'reviewedBy': reviewedBy,
      if (userId != null) 'userId': userId,
    };
  }

  CreatorApplication copyWith({
    String? fullName,
    String? email,
    String? country,
    String? niche,
    String? audienceType,
    int? totalFollowers,
    String? tiktokHandle,
    String? instagramHandle,
    String? youtubeHandle,
    String? xHandle,
    String? whyJoin,
    ApplicationStatus? status,
    DateTime? appliedAt,
    DateTime? reviewedAt,
    String? reviewedBy,
    String? userId,
  }) {
    return CreatorApplication(
      id: id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      country: country ?? this.country,
      niche: niche ?? this.niche,
      audienceType: audienceType ?? this.audienceType,
      totalFollowers: totalFollowers ?? this.totalFollowers,
      tiktokHandle: tiktokHandle ?? this.tiktokHandle,
      instagramHandle: instagramHandle ?? this.instagramHandle,
      youtubeHandle: youtubeHandle ?? this.youtubeHandle,
      xHandle: xHandle ?? this.xHandle,
      whyJoin: whyJoin ?? this.whyJoin,
      status: status ?? this.status,
      appliedAt: appliedAt ?? this.appliedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      userId: userId ?? this.userId,
    );
  }

  String get formattedFollowers {
    if (totalFollowers >= 1000000) {
      return '${(totalFollowers / 1000000).toStringAsFixed(1)}M';
    } else if (totalFollowers >= 1000) {
      return '${(totalFollowers / 1000).toStringAsFixed(1)}K';
    }
    return totalFollowers.toString();
  }
}
