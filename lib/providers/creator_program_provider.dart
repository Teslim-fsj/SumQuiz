import 'package:flutter/material.dart';
import 'package:sumquiz/models/creator_application.dart';
import 'package:sumquiz/services/creator_program_service.dart';

enum FormStep { personalInfo, creatorInfo, whyJoin }

class CreatorProgramProvider extends ChangeNotifier {
  final CreatorProgramService _service = CreatorProgramService();

  // ─── Form State ───────────────────────────────────────────────────────────────
  FormStep _currentStep = FormStep.personalInfo;
  bool _isSubmitting = false;
  bool _isSubmitted = false;
  String? _errorMessage;
  String? _submittedId;

  // Personal Info
  String fullName = '';
  String email = '';
  String country = '';

  // Creator Info
  String niche = 'education';
  String audienceType = 'mixed';
  int totalFollowers = 0;
  String tiktokHandle = '';
  String instagramHandle = '';
  String youtubeHandle = '';
  String xHandle = '';

  // Why Join
  String whyJoin = '';
  bool agreedToTerms = false;

  // ─── Getters ──────────────────────────────────────────────────────────────────
  FormStep get currentStep => _currentStep;
  int get currentStepIndex => _currentStep.index;
  bool get isSubmitting => _isSubmitting;
  bool get isSubmitted => _isSubmitted;
  String? get errorMessage => _errorMessage;
  String? get submittedId => _submittedId;

  // ─── Navigation ───────────────────────────────────────────────────────────────

  bool nextStep() {
    final valid = _validateCurrentStep();
    if (!valid) return false;

    if (_currentStep.index < FormStep.values.length - 1) {
      _currentStep = FormStep.values[_currentStep.index + 1];
      notifyListeners();
    }
    return true;
  }

  void previousStep() {
    if (_currentStep.index > 0) {
      _currentStep = FormStep.values[_currentStep.index - 1];
      _errorMessage = null;
      notifyListeners();
    }
  }

  void setStep(FormStep step) {
    _currentStep = step;
    notifyListeners();
  }

  // ─── Validation ───────────────────────────────────────────────────────────────

  bool _validateCurrentStep() {
    _errorMessage = null;

    switch (_currentStep) {
      case FormStep.personalInfo:
        if (fullName.trim().length < 2) {
          _errorMessage = 'Please enter your full name.';
          notifyListeners();
          return false;
        }
        if (!_isValidEmail(email)) {
          _errorMessage = 'Please enter a valid email address.';
          notifyListeners();
          return false;
        }
        if (country.isEmpty) {
          _errorMessage = 'Please select your country.';
          notifyListeners();
          return false;
        }
        return true;

      case FormStep.creatorInfo:
        if (totalFollowers <= 0) {
          _errorMessage = 'Please enter your total follower count.';
          notifyListeners();
          return false;
        }
        final hasSocial = tiktokHandle.isNotEmpty ||
            instagramHandle.isNotEmpty ||
            youtubeHandle.isNotEmpty ||
            xHandle.isNotEmpty;
        if (!hasSocial) {
          _errorMessage = 'Please provide at least one social media handle.';
          notifyListeners();
          return false;
        }
        return true;

      case FormStep.whyJoin:
        if (whyJoin.trim().length < 50) {
          _errorMessage =
              'Please write at least 50 characters explaining why you want to join.';
          notifyListeners();
          return false;
        }
        if (!agreedToTerms) {
          _errorMessage = 'Please agree to the Creator Program terms.';
          notifyListeners();
          return false;
        }
        return true;
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  // ─── Submission ───────────────────────────────────────────────────────────────

  Future<bool> submit() async {
    if (!_validateCurrentStep()) return false;

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final application = CreatorApplication(
        id: '',
        fullName: fullName.trim(),
        email: email.trim().toLowerCase(),
        country: country,
        niche: niche,
        audienceType: audienceType,
        totalFollowers: totalFollowers,
        tiktokHandle: tiktokHandle.isEmpty ? null : tiktokHandle.trim(),
        instagramHandle:
            instagramHandle.isEmpty ? null : instagramHandle.trim(),
        youtubeHandle: youtubeHandle.isEmpty ? null : youtubeHandle.trim(),
        xHandle: xHandle.isEmpty ? null : xHandle.trim(),
        whyJoin: whyJoin.trim(),
        appliedAt: DateTime.now(),
      );

      _submittedId = await _service.submitApplication(application);
      _isSubmitted = true;
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  void reset() {
    _currentStep = FormStep.personalInfo;
    _isSubmitting = false;
    _isSubmitted = false;
    _errorMessage = null;
    _submittedId = null;
    fullName = '';
    email = '';
    country = '';
    niche = 'education';
    audienceType = 'mixed';
    totalFollowers = 0;
    tiktokHandle = '';
    instagramHandle = '';
    youtubeHandle = '';
    xHandle = '';
    whyJoin = '';
    agreedToTerms = false;
    notifyListeners();
  }
}
