import 'package:cloud_firestore/cloud_firestore.dart';

class CreatorProfile {
  final String creatorId;
  final String applicationId;
  final String fullName;
  final String email;
  final String niche;
  final String referralCode;
  final String referralLink;
  final int totalClicks;
  final int totalSignups;
  final int totalActive;
  final int totalPaid;
  final DateTime joinedAt;
  final bool isActive;
  final String? photoUrl;
  
  // Upgraded Fields
  final double revenueGenerated;
  final double pendingEarnings;
  final double paidEarnings;
  final double commissionPercentage;
  final String status; // 'active', 'suspended'

  const CreatorProfile({
    required this.creatorId,
    required this.applicationId,
    required this.fullName,
    required this.email,
    required this.niche,
    required this.referralCode,
    required this.referralLink,
    this.totalClicks = 0,
    this.totalSignups = 0,
    this.totalActive = 0,
    this.totalPaid = 0,
    required this.joinedAt,
    this.isActive = true,
    this.photoUrl,
    this.revenueGenerated = 0.0,
    this.pendingEarnings = 0.0,
    this.paidEarnings = 0.0,
    this.commissionPercentage = 20.0,
    this.status = 'active',
  });

  factory CreatorProfile.fromMap(Map<String, dynamic> map, String id) {
    return CreatorProfile(
      creatorId: id,
      applicationId: map['applicationId'] ?? '',
      fullName: map['fullName'] ?? '',
      email: map['email'] ?? '',
      niche: map['niche'] ?? '',
      referralCode: map['referralCode'] ?? '',
      referralLink: map['referralLink'] ?? '',
      totalClicks: (map['totalClicks'] as num?)?.toInt() ?? 0,
      totalSignups: (map['totalSignups'] as num?)?.toInt() ?? 0,
      totalActive: (map['totalActive'] as num?)?.toInt() ?? 0,
      totalPaid: (map['totalPaid'] as num?)?.toInt() ?? 0,
      joinedAt: (map['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: map['isActive'] ?? true,
      photoUrl: map['photoUrl'],
      revenueGenerated: (map['revenueGenerated'] as num?)?.toDouble() ?? 0.0,
      pendingEarnings: (map['pendingEarnings'] as num?)?.toDouble() ?? 0.0,
      paidEarnings: (map['paidEarnings'] as num?)?.toDouble() ?? 0.0,
      commissionPercentage: (map['commissionPercentage'] as num?)?.toDouble() ?? 20.0,
      status: map['status'] ?? 'active',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'applicationId': applicationId,
      'fullName': fullName,
      'email': email,
      'niche': niche,
      'referralCode': referralCode,
      'referralLink': referralLink,
      'totalClicks': totalClicks,
      'totalSignups': totalSignups,
      'totalActive': totalActive,
      'totalPaid': totalPaid,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'isActive': isActive,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'revenueGenerated': revenueGenerated,
      'pendingEarnings': pendingEarnings,
      'paidEarnings': paidEarnings,
      'commissionPercentage': commissionPercentage,
      'status': status,
    };
  }

  double get conversionRate {
    if (totalClicks == 0) return 0;
    return (totalSignups / totalClicks) * 100;
  }

  String get conversionRateFormatted =>
      '${conversionRate.toStringAsFixed(1)}%';
}
