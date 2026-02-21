import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:developer' as developer;

import '../services/auth_service.dart';
import '../services/referral_service.dart';

class ReferralViewModel extends ChangeNotifier {
  ReferralService _referralService;
  AuthService _authService;

  String? _referralCode;
  String? get referralCode => _referralCode;

  Stream<int> get referralCountStream =>
      _referralService.getReferralCount(_authService.currentUser!.uid);

  ReferralViewModel(this._referralService, this._authService) {
    _init();
  }

  void _init() {
    if (_authService.currentUser != null) {
      _loadReferralCode();
    }
  }

  void update(ReferralService newService, AuthService authService) {
    _referralService = newService;
    _authService = authService;
    _init();
    notifyListeners();
  }

  Future<void> _loadReferralCode() async {
    try {
      _referralCode = await _referralService
          .generateReferralCode(_authService.currentUser!.uid);
    } catch (e, s) {
      developer.log(
        'Error loading referral code',
        name: 'com.example.myapp.ReferralViewModel',
        error: e,
        stackTrace: s,
      );
      _referralCode = 'Error';
    }
    notifyListeners();
  }

  Future<void> applyReferralCode(String code) async {
    try {
      await _referralService.applyReferralCode(
          code, _authService.currentUser!.uid);
    } catch (e) {
      // Log the error and rethrow for UI handling
      developer.log(
        'Error applying referral code: $code',
        name: 'com.example.myapp.ReferralViewModel',
        error: e,
      );
      rethrow;
    }
  }
}
