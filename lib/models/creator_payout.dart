import 'package:cloud_firestore/cloud_firestore.dart';

class CreatorPayout {
  final String id;
  final String creatorId;
  final double amount;
  final String status; // 'pending', 'paid', 'failed'
  final DateTime requestedAt;
  final DateTime? paidAt;
  final String? paymentMethodDetails;

  CreatorPayout({
    required this.id,
    required this.creatorId,
    required this.amount,
    required this.status,
    required this.requestedAt,
    this.paidAt,
    this.paymentMethodDetails,
  });

  factory CreatorPayout.fromMap(Map<String, dynamic> map, String id) {
    return CreatorPayout(
      id: id,
      creatorId: map['creatorId'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] ?? 'pending',
      requestedAt: (map['requestedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      paidAt: (map['paidAt'] as Timestamp?)?.toDate(),
      paymentMethodDetails: map['paymentMethodDetails'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'creatorId': creatorId,
      'amount': amount,
      'status': status,
      'requestedAt': Timestamp.fromDate(requestedAt),
      if (paidAt != null) 'paidAt': Timestamp.fromDate(paidAt!),
      if (paymentMethodDetails != null) 'paymentMethodDetails': paymentMethodDetails,
    };
  }
}
