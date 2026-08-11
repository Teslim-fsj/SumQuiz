import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:sumquiz/services/creator_program_service.dart';
import 'package:sumquiz/theme/web_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CreatorReferralRedirect extends StatefulWidget {
  final String referralCode;

  const CreatorReferralRedirect({
    super.key,
    required this.referralCode,
  });

  @override
  State<CreatorReferralRedirect> createState() =>
      _CreatorReferralRedirectState();
}

class _CreatorReferralRedirectState extends State<CreatorReferralRedirect> {
  final _service = CreatorProgramService();

  @override
  void initState() {
    super.initState();
    _handleRedirect();
  }

  Future<void> _handleRedirect() async {
    final code = widget.referralCode.toUpperCase();
    
    // 1. Record the click in Firestore
    await _service.recordClick(code);

    // 2. Save code locally so we can apply it during signup
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_referral_code', code);

    // 3. Redirect to landing page with query param for tracking
    if (mounted) {
      context.go('/landing?ref=$code');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: WebColors.purplePrimary),
              const SizedBox(height: 24),
              Text(
                'Applying referral code...',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
