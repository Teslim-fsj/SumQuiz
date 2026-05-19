import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/providers/subscription_provider.dart';
import 'package:sumquiz/theme/web_theme.dart';
import 'package:sumquiz/services/web_payment_service.dart';
import '../../widgets/sumi_mascot.dart';
import '../../models/sumi_emotion.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final PageController _pageController =
      PageController(viewportFraction: 0.85, initialPage: 1);
  int _currentPage = 1;

  final List<Map<String, dynamic>> _allTiers = [
    {
      'id': 'free_hub',
      'title': 'Free Hub',
      'price': r'$0',
      'label': 'LEARNER',
      'color': Colors.grey,
      'description': 'Essential tools for every learner.',
      'features': [
        '1 Heavy AI Action / day',
        '5 AI-Light Transformations / day',
        'Manual Note Editor',
        'Sumi Text Hints',
        'Streak Tracking'
      ]
    },
    {
      'id': 'sumquiz_pro_monthly',
      'title': 'Student Pro',
      'price': r'$15',
      'label': 'MOST CHOSEN',
      'color': WebColors.purplePrimary,
      'description': 'Become a consistent top-performing student.',
      'features': [
        '10 Heavy AI Actions / day',
        '100 AI-Light Transformations / day',
        'Full Sumi Tutoring (Voice + Text)',
        'ALPS Intelligence Insights',
        'Lecture → Summary/Quiz',
        'PDF & Text Uploads'
      ]
    },
    {
      'id': 'sumquiz_pro_elite',
      'title': 'Power Pro',
      'price': r'$30',
      'label': 'ELITE STUDENT',
      'color': Colors.orange,
      'description': 'Unlock 100% of your revision potential.',
      'features': [
        '30 Heavy AI Actions / day',
        '500 AI-Light Transformations / day',
        'Unlimited Voice Tutoring',
        'ALPS Adaptive Missions',
        'Bulk Session Scheduling'
      ]
    },
    {
      'id': 'sumquiz_pro_creator',
      'title': 'Academic Creator',
      'price': r'$50',
      'label': 'FOR EDUCATORS',
      'color': const Color(0xFF6366F1),
      'description': 'Scale your teaching impact globally.',
      'features': [
        '50 Heavy AI Actions / day',
        '1,000 AI-Light Transformations / day',
        'Teacher/Creator Analytics',
        'Custom Exam Generation',
        'Verified Educator Badge'
      ]
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubscriptionProvider>().loadProducts();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subProvider = context.watch<SubscriptionProvider>();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: theme.colorScheme.onSurface),
        title: Text(
          'Premium Plans',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.primary,
            fontSize: 22,
          ),
        ),
      ),
      body: subProvider.isLoading
          ? Center(
              child:
                  CircularProgressIndicator(color: theme.colorScheme.primary))
          : LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 900) {
                  return _buildWebLayout(theme);
                } else {
                  return _buildMobileLayout(theme);
                }
              },
            ),
    );
  }

  Widget _buildWebLayout(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Text(
            'Elevate Your Learning',
            style: GoogleFonts.outfit(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.onSurface,
              letterSpacing: -1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Become a top performer. Unlock your full academic potential.',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 32),
          _buildActiveSubscriptionBanner(theme),
          const SizedBox(height: 48),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _allTiers.asMap().entries.map((entry) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _buildTierCard(entry.value, entry.key, theme,
                        isWeb: true),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Text(
                  'Unlock Unlimited Revision',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: -0.5,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Choose the plan that matches your goals and supercharge your studies.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildActiveSubscriptionBanner(theme),
          const SizedBox(height: 36),
          SizedBox(
            height: 480,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _allTiers.length,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemBuilder: (context, index) {
                return AnimatedScale(
                  scale: _currentPage == index ? 1.0 : 0.93,
                  duration: const Duration(milliseconds: 250),
                  child: _buildTierCard(_allTiers[index], index, theme,
                      isWeb: false),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          _buildPageIndicator(_allTiers.length, theme),
        ],
      ),
    );
  }

  Widget _buildTierCard(Map<String, dynamic> tier, int index, ThemeData theme,
      {required bool isWeb}) {
    final colorScheme = theme.colorScheme;
    bool isFeatured = tier['label'] == 'MOST CHOSEN';
    Color tierColor = tier['color'] == WebColors.purplePrimary
        ? colorScheme.primary
        : tier['color'];
    final user = context.watch<UserModel?>();
    final subProvider = context.watch<SubscriptionProvider>();

    String displayPrice = tier['price'];
    if (!isWeb) {
      final iapProduct =
          subProvider.products.where((p) => p.id == tier['id']).firstOrNull;
      if (iapProduct != null) {
        displayPrice = iapProduct.price;
      }
    }

    bool isCurrentPlan =
        subProvider.currentProduct == tier['id'] && subProvider.isActive;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isFeatured
              ? colorScheme.primary
              : theme.dividerColor.withValues(alpha: 0.05),
          width: isFeatured ? 2.0 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isFeatured ? 0.03 : 0.01),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tier['title'],
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              if (isFeatured)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'PRO',
                    style: GoogleFonts.outfit(
                      color: colorScheme.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                displayPrice,
                style: GoogleFonts.outfit(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 4),
                child: Text(
                  '/month',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: tier['features'].length,
              itemBuilder: (context, idx) {
                final feature = tier['features'][idx];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_rounded,
                          color: tierColor, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          feature,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed:
                  isCurrentPlan ? null : () => _handlePurchase(tier, user),
              style: ElevatedButton.styleFrom(
                backgroundColor: isCurrentPlan
                    ? Colors.green
                    : (isFeatured
                        ? colorScheme.primary
                        : theme.scaffoldBackgroundColor),
                foregroundColor: isCurrentPlan
                    ? Colors.white
                    : (isFeatured ? Colors.white : colorScheme.primary),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: isFeatured
                      ? BorderSide.none
                      : BorderSide(
                          color: colorScheme.primary.withValues(alpha: 0.2)),
                ),
              ),
              child: Text(
                isCurrentPlan
                    ? 'Current Plan'
                    : (isWeb ? 'Get Started' : 'Select Plan'),
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSubscriptionBanner(ThemeData theme) {
    final user = context.watch<UserModel?>();
    if (user != null && user.isPro) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.stars_rounded,
                color: theme.colorScheme.primary, size: 24),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                'You are currently subscribed to SumQuiz Pro! Thank you!',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Future<void> _handlePurchase(
      Map<String, dynamic> tier, UserModel? user) async {
    final productId = tier['id'] as String;
    bool success = false;

    if (kIsWeb && user != null) {
      final webService = WebPaymentService();
      final product = WebPaymentService.webProducts.firstWhere(
        (p) => p.id == productId,
        orElse: () => WebPaymentService.webProducts.first,
      );
      webService.processWebPurchase(
        context: context,
        product: product,
        user: user,
      );
    } else if (user != null) {
      success =
          await context.read<SubscriptionProvider>().purchaseProduct(productId);
      if (success && mounted) {
        _showAppreciationDialog();
      }
    }
  }

  void _showAppreciationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const SumiMascot(state: SumiState.streakBoost, size: 40),
            const SizedBox(width: 10),
            Text('Thank You!',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Your subscription has been activated. Welcome to the Pro family! '
          'We truly appreciate your support. You now have access to all premium features.',
          style: GoogleFonts.inter(fontSize: 16),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Let\'s Go!'),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator(int count, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 6,
          width: _currentPage == index ? 20 : 6,
          decoration: BoxDecoration(
            color: _currentPage == index
                ? theme.colorScheme.primary
                : theme.dividerColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
