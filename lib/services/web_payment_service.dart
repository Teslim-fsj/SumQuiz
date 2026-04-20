import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:url_launcher/url_launcher.dart';

class WebPaymentResult {
  final bool success;
  final String? errorMessage;
  final String? checkoutUrl;

  WebPaymentResult(
      {required this.success, this.errorMessage, this.checkoutUrl});
}

class WebPaymentConstants {
  static const Map<String, String> paymentLinks = {
    'sumquiz_pro_starter': 'https://flutterwave.com/pay/k1ijhcevlnoy',
    'sumquiz_pro_monthly': 'https://flutterwave.com/pay/utemnb0kmwqy',
    'sumquiz_pro_elite': 'https://flutterwave.com/pay/pwd53ngb4wll',
    'sumquiz_pro_creator': 'https://flutterwave.com/pay/hsa40yzdwv7l',
  };
}

class WebPaymentService {
  static const String appName = "SumQuiz AI";
  static const String currency = "USD";

  /// Centralized Product Definitions for Web (Aligned with 2026 Credit Economy)
  static final List<ProductDetails> webProducts = [
    ProductDetails(
      id: 'sumquiz_pro_starter',
      title: 'Starter Academic',
      description: '50 Study Sessions + PDF Insights',
      price: r'$7.99',
      rawPrice: 7.99,
      currencyCode: 'USD',
    ),
    ProductDetails(
      id: 'sumquiz_pro_monthly',
      title: 'High-Performer Pro',
      description: '160 Study Sessions + YouTube Analysis',
      price: r'$14.99',
      rawPrice: 14.99,
      currencyCode: 'USD',
    ),
    ProductDetails(
      id: 'sumquiz_pro_elite',
      title: 'Dean\'s List Elite',
      description: '400 Study Sessions + Exam Generation',
      price: r'$29.99',
      rawPrice: 29.99,
      currencyCode: 'USD',
    ),
    ProductDetails(
      id: 'sumquiz_pro_creator',
      title: 'Master Educator',
      description: '1,000+ Generations + Advanced Analytics',
      price: r'$49.99',
      rawPrice: 49.99,
      currencyCode: 'USD',
    ),
  ];

  Future<List<ProductDetails>> getAvailableProducts(bool isCreator) async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (isCreator) {
      return webProducts.where((p) => p.id == 'sumquiz_pro_creator').toList();
    }
    return webProducts.where((p) => p.id != 'sumquiz_pro_creator').toList();
  }

  Future<WebPaymentResult> processWebPurchase({
    required BuildContext context,
    required ProductDetails product,
    required UserModel user,
  }) async {
    // TODO: Implement server-side payment processing via Cloud Functions
    // For now, using manual Flutterwave payment links
    final paymentLink = WebPaymentConstants.paymentLinks[product.id];
    if (paymentLink != null) {
      final uri = Uri.parse(paymentLink);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return WebPaymentResult(success: true, checkoutUrl: paymentLink);
      }
    }

    return WebPaymentResult(
      success: false,
      errorMessage: 'Could not launch payment link. Please contact support.',
    );
  }

  /// Listen for premium status change (used for the "Processing payment..." screen)
  Stream<bool> watchPremiumStatus(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return false;
      // Use UserModel's computed isPro getter which checks
      // isCreatorPro and subscriptionExpiry correctly
      final user = UserModel.fromFirestore(doc);
      return user.isPro;
    });
  }
}
