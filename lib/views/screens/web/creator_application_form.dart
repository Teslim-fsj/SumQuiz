import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sumquiz/theme/web_theme.dart';
import 'package:sumquiz/providers/creator_program_provider.dart';

class CreatorApplicationForm extends StatefulWidget {
  const CreatorApplicationForm({super.key});

  @override
  State<CreatorApplicationForm> createState() =>
      _CreatorApplicationFormState();
}

class _CreatorApplicationFormState extends State<CreatorApplicationForm> {
  final _pageController = PageController();

  // Controllers
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _followersCtrl = TextEditingController();
  final _tiktokCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  final _youtubeCtrl = TextEditingController();
  final _xCtrl = TextEditingController();
  final _whyJoinCtrl = TextEditingController();

  @override
  void dispose() {
    _pageController.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _followersCtrl.dispose();
    _tiktokCtrl.dispose();
    _instagramCtrl.dispose();
    _youtubeCtrl.dispose();
    _xCtrl.dispose();
    _whyJoinCtrl.dispose();
    super.dispose();
  }

  void _syncToProvider(CreatorProgramProvider provider) {
    provider.fullName = _nameCtrl.text;
    provider.email = _emailCtrl.text;
    provider.tiktokHandle = _tiktokCtrl.text;
    provider.instagramHandle = _instagramCtrl.text;
    provider.youtubeHandle = _youtubeCtrl.text;
    provider.xHandle = _xCtrl.text;
    provider.whyJoin = _whyJoinCtrl.text;
    provider.totalFollowers =
        int.tryParse(_followersCtrl.text.replaceAll(',', '')) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CreatorProgramProvider(),
      child: Consumer<CreatorProgramProvider>(
        builder: (context, provider, _) {
          if (provider.isSubmitted) {
            return _buildSuccessScreen();
          }

          return LayoutBuilder(builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 700;
            return SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 16 : 32,
                      vertical: 32,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Back link
                        InkWell(
                          onTap: () => context.go('/creator-program'),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.arrow_back_rounded,
                                    size: 18,
                                    color: WebColors.purplePrimary),
                                const SizedBox(width: 8),
                                Text(
                                  'Back to Creator Program',
                                  style: GoogleFonts.inter(
                                    color: WebColors.purplePrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Header
                        Text(
                          'Apply to SumQuiz\nCreator Program',
                          style: GoogleFonts.outfit(
                            fontSize: isMobile ? 28 : 36,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
                            letterSpacing: -0.5,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Takes less than 5 minutes. We review within 48 hours.',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Step indicators
                        _buildStepIndicator(provider.currentStepIndex),
                        const SizedBox(height: 32),
                        // Form pages
                        SizedBox(
                          height: 500,
                          child: PageView(
                            controller: _pageController,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              _buildStep1(provider),
                              _buildStep2(provider),
                              _buildStep3(provider),
                            ],
                          ),
                        ),
                        // Error message
                        if (provider.errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded,
                                    color: Colors.red, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    provider.errorMessage!,
                                    style: GoogleFonts.inter(
                                        color: Colors.red.shade700,
                                        fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        // Navigation Buttons
                        Row(
                          children: [
                            if (provider.currentStepIndex > 0)
                              OutlinedButton(
                                onPressed: () {
                                  provider.previousStep();
                                  _pageController.animateToPage(
                                    provider.currentStepIndex,
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeInOut,
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.grey[700],
                                  side: BorderSide(color: Colors.grey[300]!),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 16),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                ),
                                child: Text('Back',
                                    style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600)),
                              ),
                            if (provider.currentStepIndex > 0)
                              const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: provider.isSubmitting
                                    ? null
                                    : () async {
                                        _syncToProvider(provider);
                                        if (provider.currentStepIndex < 2) {
                                          final ok = provider.nextStep();
                                          if (ok) {
                                            _pageController.animateToPage(
                                              provider.currentStepIndex,
                                              duration: const Duration(
                                                  milliseconds: 250),
                                              curve: Curves.easeInOut,
                                            );
                                          }
                                        } else {
                                          await provider.submit();
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: WebColors.purplePrimary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 16),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                ),
                                child: provider.isSubmitting
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        provider.currentStepIndex < 2
                                            ? 'Continue'
                                            : 'Submit Application',
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          });
        },
      ),
    );
  }

  Widget _buildStepIndicator(int currentStep) {
    final steps = ['Personal Info', 'Creator Info', 'Why Join'];
    return Row(
      children: steps.asMap().entries.map((entry) {
        final i = entry.key;
        final label = entry.value;
        final isDone = i < currentStep;
        final isActive = i == currentStep;

        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: isDone
                                ? WebColors.purplePrimary
                                : isActive
                                    ? WebColors.purplePrimary
                                    : Colors.grey[200],
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: isDone
                                ? const Icon(Icons.check_rounded,
                                    color: Colors.white, size: 14)
                                : Text(
                                    '${i + 1}',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isActive
                                          ? Colors.white
                                          : Colors.grey[500],
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isActive
                                ? const Color(0xFF0F172A)
                                : Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      height: 3,
                      decoration: BoxDecoration(
                        color: isDone || isActive
                            ? WebColors.purplePrimary
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
              if (i < steps.length - 1) const SizedBox(width: 8),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStep1(CreatorProgramProvider provider) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel('Personal Information'),
          const SizedBox(height: 16),
          _buildField(
            label: 'Full Name',
            controller: _nameCtrl,
            hint: 'Jane Smith',
            onChanged: (v) => provider.fullName = v,
          ),
          const SizedBox(height: 16),
          _buildField(
            label: 'Email Address',
            controller: _emailCtrl,
            hint: 'jane@example.com',
            keyboardType: TextInputType.emailAddress,
            onChanged: (v) => provider.email = v,
          ),
          const SizedBox(height: 16),
          _buildDropdown(
            label: 'Country',
            value: provider.country.isEmpty ? null : provider.country,
            items: _countries,
            hint: 'Select your country',
            onChanged: (v) => setState(() => provider.country = v ?? ''),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2(CreatorProgramProvider provider) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel('Creator Information'),
          const SizedBox(height: 16),
          _buildDropdown(
            label: 'Content Niche',
            value: provider.niche,
            items: const {
              'education': 'Education',
              'productivity': 'Productivity',
              'studentInfluencer': 'Student Influencer',
              'studyTips': 'Study Tips',
              'examPrep': 'Exam Prep',
              'other': 'Other',
            },
            onChanged: (v) => setState(() => provider.niche = v ?? 'other'),
          ),
          const SizedBox(height: 16),
          _buildDropdown(
            label: 'Primary Audience Platform',
            value: provider.audienceType,
            items: const {
              'tiktok-first': 'TikTok First',
              'youtube-first': 'YouTube First',
              'instagram-first': 'Instagram First',
              'mixed': 'Mixed / Multiple Platforms',
            },
            onChanged: (v) =>
                setState(() => provider.audienceType = v ?? 'mixed'),
          ),
          const SizedBox(height: 16),
          _buildField(
            label: 'Total Followers (across all platforms)',
            controller: _followersCtrl,
            hint: 'e.g. 15000',
            keyboardType: TextInputType.number,
            onChanged: (v) =>
                provider.totalFollowers = int.tryParse(v) ?? 0,
          ),
          const SizedBox(height: 16),
          _buildSectionLabel('Social Media Handles (at least one)'),
          const SizedBox(height: 12),
          _buildField(
              label: 'TikTok',
              controller: _tiktokCtrl,
              hint: '@yourusername',
              prefix: '🎵  ',
              onChanged: (v) => provider.tiktokHandle = v),
          const SizedBox(height: 12),
          _buildField(
              label: 'Instagram',
              controller: _instagramCtrl,
              hint: '@yourusername',
              prefix: '📸  ',
              onChanged: (v) => provider.instagramHandle = v),
          const SizedBox(height: 12),
          _buildField(
              label: 'YouTube',
              controller: _youtubeCtrl,
              hint: 'Channel URL or @handle',
              prefix: '▶️  ',
              onChanged: (v) => provider.youtubeHandle = v),
          const SizedBox(height: 12),
          _buildField(
              label: 'X (Twitter)',
              controller: _xCtrl,
              hint: '@yourusername',
              prefix: '𝕏  ',
              onChanged: (v) => provider.xHandle = v),
        ],
      ),
    );
  }

  Widget _buildStep3(CreatorProgramProvider provider) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel('Why Do You Want to Join?'),
          const SizedBox(height: 8),
          Text(
            'Tell us about your content, your audience, and why you\'d be a great SumQuiz creator.',
            style: GoogleFonts.inter(
                fontSize: 13, color: Colors.grey[600], height: 1.5),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _whyJoinCtrl,
            maxLines: 7,
            maxLength: 1000,
            onChanged: (v) => provider.whyJoin = v,
            style: GoogleFonts.inter(fontSize: 14),
            decoration: InputDecoration(
              hintText:
                  'E.g. "I create study tip content for university students on TikTok. My audience is mostly pre-med and engineering students who struggle with note-taking and exam prep. SumQuiz would be a perfect fit because..."',
              hintStyle: GoogleFonts.inter(
                  color: Colors.grey[400], fontSize: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                    color: WebColors.purplePrimary, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 16),
          // Terms agreement
          InkWell(
            onTap: () => setState(
                () => provider.agreedToTerms = !provider.agreedToTerms),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: provider.agreedToTerms,
                  onChanged: (v) =>
                      setState(() => provider.agreedToTerms = v ?? false),
                  activeColor: WebColors.purplePrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'I agree to the SumQuiz Creator Program terms and understand that my application will be reviewed within 48 hours.',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.grey[700],
                          height: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessScreen() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F3FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: WebColors.purplePrimary,
                  size: 48,
                ),
              ).animate().scale(duration: 250.ms, curve: Curves.easeOut),
              const SizedBox(height: 24),
              Text(
                'Application Submitted! 🎉',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                ),
              ).animate().fadeIn(delay: 100.ms, duration: 250.ms),
              const SizedBox(height: 12),
              Text(
                'Thank you for applying to the SumQuiz Creator Program. We\'ll review your application and get back to you within 48 hours.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ).animate().fadeIn(delay: 200.ms, duration: 250.ms),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => context.go('/landing'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: WebColors.purplePrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: Text('Go to SumQuiz',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ).animate().fadeIn(delay: 250.ms, duration: 250.ms),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Colors.grey[500],
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    String? prefix,
    required Function(String) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: onChanged,
          style: GoogleFonts.inter(fontSize: 14),
          decoration: InputDecoration(
            hintText: prefix != null ? '$prefix$hint' : hint,
            hintStyle: GoogleFonts.inter(
                color: Colors.grey[400], fontSize: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                  color: WebColors.purplePrimary, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required Map<String, String> items,
    String? hint,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: value,
          onChanged: onChanged,
          hint: hint != null
              ? Text(hint,
                  style: GoogleFonts.inter(
                      color: Colors.grey[400], fontSize: 14))
              : null,
          style: GoogleFonts.inter(
              fontSize: 14, color: const Color(0xFF0F172A)),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                  color: WebColors.purplePrimary, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          items: items.entries
              .map((e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value),
                  ))
              .toList(),
        ),
      ],
    );
  }

  static const Map<String, String> _countries = {
    'NG': 'Nigeria',
    'GH': 'Ghana',
    'KE': 'Kenya',
    'ZA': 'South Africa',
    'US': 'United States',
    'GB': 'United Kingdom',
    'CA': 'Canada',
    'AU': 'Australia',
    'IN': 'India',
    'PH': 'Philippines',
    'PK': 'Pakistan',
    'BD': 'Bangladesh',
    'EG': 'Egypt',
    'ET': 'Ethiopia',
    'TZ': 'Tanzania',
    'UG': 'Uganda',
    'RW': 'Rwanda',
    'CM': 'Cameroon',
    'SN': 'Senegal',
    'CI': 'Ivory Coast',
    'ZM': 'Zambia',
    'MW': 'Malawi',
    'MZ': 'Mozambique',
    'LS': 'Lesotho',
    'BW': 'Botswana',
    'ZW': 'Zimbabwe',
    'DE': 'Germany',
    'FR': 'France',
    'NL': 'Netherlands',
    'SE': 'Sweden',
    'NO': 'Norway',
    'DK': 'Denmark',
    'FI': 'Finland',
    'IT': 'Italy',
    'ES': 'Spain',
    'PT': 'Portugal',
    'PL': 'Poland',
    'UA': 'Ukraine',
    'BR': 'Brazil',
    'MX': 'Mexico',
    'AR': 'Argentina',
    'CO': 'Colombia',
    'MY': 'Malaysia',
    'SG': 'Singapore',
    'ID': 'Indonesia',
    'TH': 'Thailand',
    'VN': 'Vietnam',
    'TR': 'Turkey',
    'AE': 'UAE',
    'SA': 'Saudi Arabia',
    'other': 'Other',
  };
}
