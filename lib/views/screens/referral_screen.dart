import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/services/auth_service.dart';
import 'package:sumquiz/services/referral_service.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  late Future<String> _referralCodeFuture;

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<AuthService>(context, listen: false);
    final referralService =
        Provider.of<ReferralService>(context, listen: false);

    // Optimize: Use code from User Model if available
    final user = Provider.of<UserModel?>(context, listen: false);
    if (user != null &&
        user.referralCode != null &&
        user.referralCode!.isNotEmpty) {
      _referralCodeFuture = Future.value(user.referralCode);
    } else {
      _referralCodeFuture =
          referralService.generateReferralCode(authService.currentUser!.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final referralService = Provider.of<ReferralService>(context);
    final authService = Provider.of<AuthService>(context);
    final uid = authService.currentUser!.uid;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Refer a Friend',
            style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.colorScheme.primary),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          // Animated Background
          Animate(
            onPlay: (controller) => controller.repeat(reverse: true),
            effects: [
              CustomEffect(
                duration: 6.seconds,
                builder: (context, value, child) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [
                                theme.colorScheme.surface,
                                Color.lerp(theme.colorScheme.surface,
                                    theme.colorScheme.primaryContainer, value)!,
                              ]
                            : [
                                const Color(0xFFF3F4F6),
                                Color.lerp(const Color(0xFFE8EAF6),
                                    const Color(0xFFC5CAE9), value)!,
                              ],
                      ),
                    ),
                    child: child,
                  );
                },
              )
            ],
            child: Container(),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            Icon(Icons.volunteer_activism,
                                    size: 80, color: theme.colorScheme.primary)
                                .animate()
                                .scale()
                                .fadeIn(),
                            const SizedBox(height: 16),
                            Text(
                              'Invite Friends, Get Rewards!',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                              textAlign: TextAlign.center,
                            )
                                .animate()
                                .fadeIn(delay: 100.ms)
                                .slideY(begin: 0.1),
                            const SizedBox(height: 12),
                            Text(
                              'Give 7 days of Pro, Get 7 days of Pro!',
                              style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber[800]),
                              textAlign: TextAlign.center,
                            ).animate().fadeIn(delay: 200.ms),
                            const SizedBox(height: 8),
                            Text(
                              'Share your unique code. When friends sign up, they get 7 free Pro days. You earn 7 days for every 2 friends who join!',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.7)),
                              textAlign: TextAlign.center,
                            ).animate().fadeIn(delay: 300.ms),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildReferralCodeCard(_referralCodeFuture, theme)
                          .animate()
                          .fadeIn(delay: 400.ms)
                          .shimmer(delay: 1000.ms),
                      const SizedBox(height: 40),
                      Text(
                        'Your Progress',
                        style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary),
                      ).animate().fadeIn(delay: 500.ms),
                      const SizedBox(height: 16),
                      _buildStatsGrid(referralService, uid, theme)
                          .animate()
                          .fadeIn(delay: 600.ms),
                      const SizedBox(height: 40),

                      // Redeem Section for existing users
                      Consumer<UserModel?>(
                        builder: (context, user, _) {
                          if (user == null ||
                              (user
                                  .toFirestore()
                                  .containsKey('appliedReferralCode'))) {
                            return const SizedBox.shrink();
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Received a Code?',
                                style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary),
                              ),
                              const SizedBox(height: 16),
                              _buildRedeemCard(
                                  context, referralService, uid, theme),
                              const SizedBox(height: 40),
                            ],
                          );
                        },
                      ),

                      _buildHowItWorks(theme).animate().fadeIn(delay: 700.ms),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassContainer(
      {required Widget child,
      required ThemeData theme,
      EdgeInsets padding = const EdgeInsets.all(24)}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: theme.cardColor.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(24),
            border:
                Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildReferralCodeCard(Future<String> codeFuture, ThemeData theme) {
    return _buildGlassContainer(
      theme: theme,
      child: Column(
        children: [
          Text(
            'YOUR UNIQUE CODE',
            style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2),
          ),
          const SizedBox(height: 16),
          FutureBuilder<String>(
            future: codeFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return CircularProgressIndicator(
                    color: theme.colorScheme.primary);
              }
              if (snapshot.hasError ||
                  !snapshot.hasData ||
                  snapshot.data!.isEmpty) {
                return Text('Could not load code',
                    style: theme.textTheme.bodyMedium);
              }
              final code = snapshot.data!;
              return InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Referral code copied to clipboard!'),
                        backgroundColor: Colors.green),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.2),
                        width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        code,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.copy_all_rounded,
                        color: theme.colorScheme.primary,
                        size: 24,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              icon:
                  Icon(Icons.share_rounded, color: theme.colorScheme.onPrimary),
              label: Text('Share Code',
                  style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimary)),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              onPressed: () async {
                final code = await _referralCodeFuture;
                Share.share(
                    'Join me on SumQuiz and get 7 free Pro days! Use my code: $code\n\nDownload the app here: [App Store Link]',
                    subject: 'Get Free Pro Days on SumQuiz!');
              },
            ),
          ),
          const SizedBox(height: 12),
          // Regenerate Code Button
          TextButton.icon(
            icon: Icon(Icons.refresh,
                size: 18,
                color: theme.colorScheme.primary.withValues(alpha: 0.7)),
            label: Text(
              'Regenerate Code',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary.withValues(alpha: 0.7),
              ),
            ),
            onPressed: () async {
              final authService =
                  Provider.of<AuthService>(context, listen: false);
              final referralService =
                  Provider.of<ReferralService>(context, listen: false);

              try {
                final newCode = await referralService
                    .forceGenerateReferralCode(authService.currentUser!.uid);
                setState(() {
                  _referralCodeFuture = Future.value(newCode);
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('New code generated: $newCode'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to regenerate code: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(
      ReferralService referralService, String uid, ThemeData theme) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 0.8,
      children: [
        _buildStatCard('Pending', referralService.getReferralCount(uid),
            Icons.hourglass_empty_rounded, theme),
        _buildStatCard(
            'Total Friends',
            referralService.getTotalReferralCount(uid),
            Icons.group_add_rounded,
            theme),
        _buildStatCard(
            'Rewards Earned',
            referralService.getReferralRewards(uid),
            Icons.card_giftcard_rounded,
            theme),
      ],
    );
  }

  Widget _buildStatCard(
      String label, Stream<int> stream, IconData icon, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 28, color: Colors.amber[800]),
          const SizedBox(height: 12),
          StreamBuilder<int>(
            stream: stream,
            builder: (context, snapshot) {
              final value = snapshot.data ?? 0;
              return Text(
                value.toString(),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurface),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  final TextEditingController _redeemController = TextEditingController();
  bool _isRedeeming = false;

  @override
  void dispose() {
    _redeemController.dispose();
    super.dispose();
  }

  Future<void> _redeemCode(ReferralService service, String uid) async {
    final code = _redeemController.text.trim();
    if (code.isEmpty) return;

    setState(() => _isRedeeming = true);
    try {
      await service.applyReferralCode(code, uid);
      if (mounted) {
        _redeemController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Success! 7 Days of Pro added!'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isRedeeming = false);
    }
  }

  Widget _buildRedeemCard(BuildContext context, ReferralService service,
      String uid, ThemeData theme) {
    return _buildGlassContainer(
      theme: theme,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          TextField(
            controller: _redeemController,
            decoration: InputDecoration(
              hintText: 'Enter referral code',
              prefixIcon: const Icon(Icons.card_giftcard),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isRedeeming ? null : () => _redeemCode(service, uid),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isRedeeming
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Apply Code'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorks(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How It Works',
          style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 16),
        _buildGlassContainer(
          theme: theme,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildStep(
                  Icons.looks_one_rounded,
                  'Share Your Code',
                  'Send your unique code to friends via text, email, or social media.',
                  theme),
              Divider(color: theme.dividerColor.withValues(alpha: 0.2)),
              _buildStep(
                  Icons.looks_two_rounded,
                  'Friend Signs Up',
                  'Your friend enters your code during signup and instantly receives 7 Pro days.',
                  theme),
              Divider(color: theme.dividerColor.withValues(alpha: 0.2)),
              _buildStep(
                  Icons.looks_3_rounded,
                  'You Get Rewarded',
                  'After 2 referred friends sign up and generate their first quiz, you earn a reward: 7 extra days of Pro subscription!',
                  theme),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep(
      IconData icon, String title, String description, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface)),
                const SizedBox(height: 4),
                Text(description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.7))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
