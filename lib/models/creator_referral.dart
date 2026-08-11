import 'package:cloud_firestore/cloud_firestore.dart';

class CreatorReferral {
  final String id;
  final String creatorId;
  final String referralCode;
  final String userId;
  final String email;
  final DateTime clickedAt;
  final DateTime registeredAt;
  final DateTime? firstLoginAt;
  final DateTime? firstSummaryAt;
  final DateTime? firstQuizAt;
  final DateTime? firstSubscriptionAt;
  final double revenueGenerated;
  final String status; // 'clicked', 'registered', 'active', 'paid'

  CreatorReferral({
    required this.id,
    required this.creatorId,
    required this.referralCode,
    required this.userId,
    required this.email,
    required this.clickedAt,
    required this.registeredAt,
    this.firstLoginAt,
    this.firstSummaryAt,
    this.firstQuizAt,
    this.firstSubscriptionAt,
    this.revenueGenerated = 0.0,
    required this.status,
  });

  factory CreatorReferral.fromMap(Map<String, dynamic> map, String id) {
    return CreatorReferral(
      id: id,
      creatorId: map['creatorId'] ?? '',
      referralCode: map['referralCode'] ?? '',
      userId: map['userId'] ?? '',
      email: map['email'] ?? '',
      clickedAt: (map['clickedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      registeredAt: (map['registeredAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      firstLoginAt: (map['firstLoginAt'] as Timestamp?)?.toDate(),
      firstSummaryAt: (map['firstSummaryAt'] as Timestamp?)?.toDate(),
      firstQuizAt: (map['firstQuizAt'] as Timestamp?)?.toDate(),
      firstSubscriptionAt: (map['firstSubscriptionAt'] as Timestamp?)?.toDate(),
      revenueGenerated: (map['revenueGenerated'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] ?? 'registered',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'creatorId': creatorId,
      'referralCode': referralCode,
      'userId': userId,
      'email': email,
      'clickedAt': Timestamp.fromDate(clickedAt),
      'registeredAt': Timestamp.fromDate(registeredAt),
      if (firstLoginAt != null) 'firstLoginAt': Timestamp.fromDate(firstLoginAt!),
      if (firstSummaryAt != null) 'firstSummaryAt': Timestamp.fromDate(firstSummaryAt!),
      if (firstQuizAt != null) 'firstQuizAt': Timestamp.fromDate(firstQuizAt!),
      if (firstSubscriptionAt != null) 'firstSubscriptionAt': Timestamp.fromDate(firstSubscriptionAt!),
      'revenueGenerated': revenueGenerated,
      'status': status,
    };
  }
}
