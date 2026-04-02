import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../models/user_model.dart';
import '../services/iap_service.dart';
import '../services/time_sync_service.dart';

class SubscriptionProvider with ChangeNotifier {
  IAPService? _iapService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserModel? _currentUser;
  StreamSubscription<DocumentSnapshot>? _userSubscription;

  SubscriptionProvider(this._iapService) {
    _initialize();
  }

  /// Update the service reference (called by ProxyProvider)
  void update(IAPService? iapService) {
    if (iapService != null && iapService != _iapService) {
      _iapService = iapService;
      notifyListeners();
    }
  }

  // Subscription state
  bool _isLoading = false;
  bool _isSubscribed = false;
  DateTime? _subscriptionExpiry;
  String? _currentProduct;
  bool _isTrial = false;

  // Products state
  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;

  // Track if we are already listening to auth changes
  bool _isAuthListening = false;

  // Getters
  bool get isLoading => _isLoading;
  bool get isSubscribed => _isSubscribed;
  DateTime? get subscriptionExpiry => _subscriptionExpiry;
  String? get currentProduct => _currentProduct;
  bool get isTrial => _isTrial;
  bool get isActive =>
      _isSubscribed &&
      (_subscriptionExpiry == null ||
          _subscriptionExpiry!.isAfter(TimeSyncService.now));

  // Initialize and listen to user changes
  void _initialize() {
    if (_isAuthListening) return;
    _isAuthListening = true;

    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _listenToUser(user.uid);
      } else {
        _clearState();
      }
    });
  }

  // Listen to user document changes
  void _listenToUser(String uid) {
    _userSubscription?.cancel();
    _userSubscription =
        _firestore.collection('users').doc(uid).snapshots().listen((snapshot) {
      if (snapshot.exists) {
        _currentUser = UserModel.fromFirestore(snapshot);
        _updateSubscriptionState();
      } else {
        _clearState();
      }
    });
  }

  // Update subscription state from user model
  void _updateSubscriptionState() {
    if (_currentUser == null) {
      _clearState();
      return;
    }

    _isSubscribed = _currentUser!.isPro;
    _subscriptionExpiry = _currentUser!.subscriptionExpiry;
    _currentProduct = _currentUser!.currentProduct;
    _isTrial = _currentUser!.isTrial;

    notifyListeners();
  }

  // Clear subscription state
  void _clearState() {
    _isSubscribed = false;
    _subscriptionExpiry = null;
    _currentProduct = null;
    _isTrial = false;
    _currentUser = null;
    notifyListeners();
  }

  /// Fetch available products from the store
  Future<void> loadProducts() async {
    if (_iapService == null) return;

    _setLoading(true);
    try {
      _products = await _iapService!.getAvailableProducts();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading products in provider: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Purchase a product
  Future<bool> purchaseProduct(String productId) async {
    if (_isLoading || _iapService == null) return false;

    _setLoading(true);

    try {
      final success = await _iapService!.purchaseProduct(productId);

      if (success) {
        // Wait a bit for the purchase to be processed and reflected in Firestore
        await Future.delayed(const Duration(seconds: 3));

        // Force refresh user data
        await _refreshUserData();
      }

      return success;
    } catch (e) {
      debugPrint('Purchase error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Start a real Google Play free-trial subscription.
  // Google Play will show its billing sheet and require the user to add a
  // payment method before granting the 3-day trial.
  // Firestore is updated asynchronously via the purchase stream listener —
  // the UI should react to the UserModel stream rather than poll here.
  Future<bool> startTrialPurchase() async {
    if (_isLoading || _iapService == null) return false;

    _setLoading(true);
    try {
      final initiated = await _iapService!.startTrialPurchase();
      // Note: Firestore will be updated by _handleSuccessfulPurchase once
      // Google Play confirms the purchase. We do NOT await it here.
      return initiated;
    } catch (e) {
      debugPrint('Trial purchase error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Restore purchases
  Future<void> restorePurchases() async {
    if (_isLoading || _iapService == null) return;

    _setLoading(true);

    try {
      await _iapService!.restorePurchases();
      await Future.delayed(const Duration(seconds: 2));
      await _refreshUserData();
    } catch (e) {
      debugPrint('Restore error: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Refresh user data from Firestore
  Future<void> _refreshUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        _currentUser = UserModel.fromFirestore(doc);
        _updateSubscriptionState();
      }
    }
  }

  // Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Check if user can access a Pro feature
  bool canAccessProFeature() {
    return isActive;
  }

  // Check if user is approaching expiration (within 3 days)
  bool isExpiringSoon() {
    if (_subscriptionExpiry == null) return false;

    final now = TimeSyncService.now;
    final difference = _subscriptionExpiry!.difference(now);

    return difference.inDays <= 3 && difference.inDays >= 0;
  }

  // Get formatted expiry date
  String? getFormattedExpiry() {
    if (_subscriptionExpiry == null) return null;

    final now = TimeSyncService.now;
    final difference = _subscriptionExpiry!.difference(now);

    if (difference.inDays > 0) {
      return '${difference.inDays} days';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours';
    } else {
      return 'Less than 1 hour';
    }
  }

  // Dispose resources
  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }
}
