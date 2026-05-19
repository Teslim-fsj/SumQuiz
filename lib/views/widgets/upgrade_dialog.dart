import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/sumi_emotion.dart';
import '../../widgets/sumi_mascot.dart';

/// Premium Sumi-branded upgrade dialog.
///
/// Use the [UpgradeDialog.show] static helper whenever possible.
/// For legacy `showDialog` call sites, passing `const UpgradeDialog(featureName: '...')`
/// as the builder return still works perfectly.
class UpgradeDialog extends StatelessWidget {
  final String? featureName;

  const UpgradeDialog({super.key, this.featureName});

  // ── Static convenience ────────────────────────────────────────────────────

  /// Show the dialog from anywhere in the app.
  static Future<void> show(BuildContext context, {String? featureName}) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => UpgradeDialog(featureName: featureName),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final features = [
      _Feat(Icons.all_inclusive_rounded, 'Unlimited AI Tutoring', 'Voice + text, no daily cap'),
      _Feat(Icons.bolt_rounded, '10× More AI Actions / day', 'Quizzes, summaries, flashcards'),
      _Feat(Icons.upload_file_rounded, 'PDF & Image Uploads', 'Ground Sumi in your materials'),
      _Feat(Icons.insights_rounded, 'ALPS Intelligence', 'Personalised performance insights'),
      _Feat(Icons.mic_rounded, 'Live Lecture Notes', 'Instant transcription + summary'),
    ];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Mascot ───────────────────────────────────────────────────
              SumiMascot(
                state: SumiState.streakBoost,
                size: 88,
                dialogue: null,
              ).animate()
                .scale(begin: const Offset(0.6, 0.6), curve: Curves.easeOutBack, duration: 500.ms),

              const SizedBox(height: 16),

              // ── Headline ─────────────────────────────────────────────────
              Text(
                "You've Hit Your Daily Limit",
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: cs.onSurface,
                  height: 1.2,
                ),
              ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.08, end: 0),

              const SizedBox(height: 8),

              Text(
                featureName != null
                    ? 'Upgrade to keep using $featureName and unlock everything Sumi can do.'
                    : 'Upgrade to Student Pro and unlock everything Sumi can do for you.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: cs.onSurfaceVariant,
                  height: 1.5,
                ),
              ).animate().fadeIn(delay: 120.ms),

              const SizedBox(height: 20),

              // ── Feature list ─────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
                ),
                child: Column(
                  children: features.asMap().entries.map((e) {
                    return _featureRow(e.value, cs, theme, e.key)
                        .animate()
                        .fadeIn(delay: (160 + e.key * 50).ms)
                        .slideX(begin: -0.04, end: 0);
                  }).toList(),
                ),
              ),

              const SizedBox(height: 20),

              // ── Pricing pill ─────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.stars_rounded, color: cs.primary, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Student Pro · from ',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: cs.onPrimaryContainer, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '\$15/mo',
                      style: GoogleFonts.outfit(
                          fontSize: 14, color: cs.primary, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 420.ms),

              const SizedBox(height: 20),

              // ── CTA ──────────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.push('/subscription');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text(
                    'Unlock Full Access',
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ).animate().fadeIn(delay: 460.ms).slideY(begin: 0.08, end: 0),

              const SizedBox(height: 8),

              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Continue with free plan',
                  style: GoogleFonts.inter(color: cs.onSurfaceVariant, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featureRow(_Feat feat, ColorScheme cs, ThemeData theme, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(feat.icon, color: cs.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(feat.title,
                    style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurface)),
                Text(feat.subtitle,
                    style: GoogleFonts.inter(
                        fontSize: 11, color: cs.onSurfaceVariant, height: 1.3)),
              ],
            ),
          ),
          Icon(Icons.check_circle_rounded, color: cs.primary, size: 18),
        ],
      ),
    );
  }
}

class _Feat {
  final IconData icon;
  final String title;
  final String subtitle;
  const _Feat(this.icon, this.title, this.subtitle);
}
