import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
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
  bool _isCreatorMode = false;
  bool _isYearly = true;
  final PageController _pageController =
      PageController(viewportFraction: 0.85, initialPage: 1);
  int _currentPage = 1;

  final List<Map<String, dynamic>> _boostPacks = [
    {
      'id': 'boost_standard',
      'title': 'Cognitive Surge',
      'credits': '50',
      'price': r'$4.99',
      'icon': Icons.auto_awesome,
      'color': Colors.cyan,
    },
    {
      'id': 'boost_macro',
      'title': 'Synaptic Overload',
      'credits': '120',
      'price': r'$9.99',
      'icon': Icons.rocket_launch,
      'color': Colors.deepPurple,
    },
  ];

  final List<Map<String, dynamic>> _studentTiers = [
    {
      'id': 'free_hub',
      'title': 'Free Neural Hub',
      'price': r'$0',
      'sessions': '20',
      'label': 'LEARNER',
      'color': Colors.grey,
      'description': 'Essential tools for every learner.',
      'features': [
        '20 Lifetime Neural Credits',
        'Basic AI Summaries',
        'Local Flashcards',
        'Neural Hub Access'
      ]
    },
    {
      'id': 'sumquiz_pro_monthly',
      'title': 'High-Performer Pro',
      'price': r'$14.99',
      'yearlyPrice': r'$139.99',
      'sessions': '160',
      'label': 'MOST CHOSEN',
      'color': WebColors.purplePrimary,
      'description': 'Become a consistent top-performing student.',
      'features': [
        '160 Study Sessions / mo',
        'Full YouTube Lecture Analysis',
        'Interactive Quizzes',
        'Priority Neural Processing'
      ]
    },
    {
      'id': 'sumquiz_pro_elite',
      'title': 'Dean\'s List Elite',
      'price': r'$29.99',
      'yearlyPrice': r'$279.99',
      'sessions': '400',
      'label': 'ELITE STUDENT',
      'color': Colors.orange,
      'description': 'Unlock 100% of your revision potential.',
      'features': [
        '400 Study Sessions / mo',
        'Official Exam Paper Generation',
        'Advanced Retention Flashcards',
        'Unrestricted Growth Tools',
        'Dedicated Academic Support'
      ]
    },
  ];

  final List<Map<String, dynamic>> _creatorTiers = [
    {
      'id': 'sumquiz_pro_creator',
      'title': 'Master Educator',
      'price': r'$49.99',
      'sessions': '1,000+',
      'label': 'FOR CREATORS',
      'color': const Color(0xFF6366F1),
      'description': 'Scale your teaching impact globally.',
      'features': [
        '1,000+ Generations / mo',
        'Commercial Distribution Rights',
        'Student Engagement Analytics',
        'Verified Educator Badge'
      ]
    },
  ];

  @override
  void initState() {
    super.initState();
    // Load products on initialization
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
    final subProvider = context.watch<SubscriptionProvider>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(),
      body: subProvider.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: WebColors.purplePrimary))
          : LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 900) {
                  return _buildWebLayout();
                } else {
                  return _buildMobileLayout();
                }
              },
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Theme.of(context).textTheme.bodyLarge?.color),
        onPressed: () => context.pop(),
      ),
      centerTitle: !kIsWeb,
      title: Text(
        kIsWeb ? '' : 'Subscription',
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).textTheme.bodyLarge?.color,
          fontSize: 20,
        ),
      ),
    );
  }

  Widget _buildWebLayout() {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 40),
          Text(
            'Subscription Plans',
            style: GoogleFonts.outfit(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).textTheme.displayLarge?.color,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Become a Top Performer. Unlock your full academic revision potential.',
            style: GoogleFonts.inter(
              fontSize: 18,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
          const SizedBox(height: 20),
          _buildActiveSubscriptionBanner(),
          const SizedBox(height: 20),
          _buildToggles(),
          const SizedBox(height: 60),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: (_isCreatorMode ? _creatorTiers : _studentTiers)
                  .asMap()
                  .entries
                  .map((entry) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _buildTierCard(entry.value, entry.key, isWeb: true),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 100),
          _buildBoostSection(isWeb: true),
          const SizedBox(height: 80),
          _buildSatisfactionSection(),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    final tiers = _isCreatorMode ? _creatorTiers : _studentTiers;
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Text(
                  'Elevate Your Learning',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).textTheme.displayLarge?.color,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Choose a plan that fits your academic goals and unlock AI-powered tools.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildActiveSubscriptionBanner(),
          const SizedBox(height: 16),
          _buildToggles(),
          const SizedBox(height: 40),
          SizedBox(
            height: 520,
            child: PageView.builder(
              controller: _pageController,
              itemCount: tiers.length,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemBuilder: (context, index) {
                return AnimatedScale(
                  scale: _currentPage == index ? 1.0 : 0.9,
                  duration: const Duration(milliseconds: 300),
                  child: _buildTierCard(tiers[index], index, isWeb: false),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          _buildPageIndicator(tiers.length),
          const SizedBox(height: 60),
          _buildBoostSection(isWeb: false),
          const SizedBox(height: 60),
          const SizedBox(height: 40),
          _buildSecurePaymentSection(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildToggles() {
    return Column(
      children: [
        _buildRoleToggle(),
        const SizedBox(height: 16),
        _buildBillingToggle(),
      ],
    );
  }

  Widget _buildRoleToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleButton(
              'Student',
              !_isCreatorMode,
              () => setState(() {
                    _isCreatorMode = false;
                  })),
          _toggleButton(
              'Creator',
              _isCreatorMode,
              () => setState(() {
                    _isCreatorMode = true;
                  })),
        ],
      ),
    );
  }

  Widget _buildBillingToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Monthly',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: _isYearly ? FontWeight.w500 : FontWeight.bold,
            color: _isYearly ? Theme.of(context).textTheme.bodySmall?.color : Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Switch(
          value: _isYearly,
          onChanged: (val) => setState(() => _isYearly = val),
          activeColor: WebColors.purplePrimary,
        ),
        const SizedBox(width: 12),
        Row(
          children: [
            Text(
              'Yearly',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: _isYearly ? FontWeight.bold : FontWeight.w500,
                color: _isYearly ? Theme.of(context).colorScheme.primary : Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Save 20%',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _toggleButton(String text, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.black.withAlpha(12),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: active ? Theme.of(context).colorScheme.primary : Theme.of(context).textTheme.bodySmall?.color,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildTierCard(Map<String, dynamic> tier, int index,
      {required bool isWeb}) {
    bool isFeatured = tier['label'] == 'MOST CHOSEN';
    Color tierColor = tier['color'] == WebColors.purplePrimary ? Theme.of(context).colorScheme.primary : tier['color'];
    final user = context.watch<UserModel?>();
    final subProvider = context.watch<SubscriptionProvider>();

    // Get real price from IAP if on mobile
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
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isFeatured ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor,
          width: isFeatured ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(7),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (isFeatured)
            Positioned(
              top: -44,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'MOST CHOSEN',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tier['title'],
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isFeatured
                      ? Theme.of(context).textTheme.displayLarge?.color
                      : Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _isYearly && tier['yearlyPrice'] != null 
                        ? tier['yearlyPrice'] 
                        : displayPrice,
                    style: GoogleFonts.outfit(
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).textTheme.displayLarge?.color,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, left: 4),
                    child: Text(
                      _isYearly && tier['yearlyPrice'] != null ? '/yr' : '/mo',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ...tier['features']
                  .map<Widget>((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: tierColor.withAlpha(25),
                                shape: BoxShape.circle,
                              ),
                              child:
                                  Icon(Icons.check, color: tierColor, size: 16),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                f,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  color: Theme.of(context).textTheme.bodyMedium?.color,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      isCurrentPlan ? null : () => _handlePurchase(tier, user),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCurrentPlan
                        ? const Color(0xFF10B981) // Success green
                        : (isFeatured
                            ? WebColors.purplePrimary
                            : (isWeb
                                ? const Color(0xFFDBEAFE)
                                : WebColors.purplePrimary)),
                    foregroundColor: isCurrentPlan
                        ? Colors.white
                        : (isFeatured
                            ? Colors.white
                            : (isWeb ? WebColors.purplePrimary : Colors.white)),
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(
                    isCurrentPlan
                        ? 'Current Plan'
                        : (isWeb ? 'Get Started Now' : 'Select Plan'),
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSubscriptionBanner() {
    final user = context.watch<UserModel?>();
    if (user != null && user.isPro) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: BoxDecoration(
          color: WebColors.purplePrimary.withAlpha(25),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: WebColors.purplePrimary.withAlpha(50)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.stars_rounded,
                color: WebColors.purplePrimary, size: 28),
            const SizedBox(width: 16),
            Flexible(
              child: Text(
                'You are currently subscribed to SumQuiz Pro! Thank you for your support.',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: WebColors.purplePrimary,
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
      // Assuming processWebPurchase handles its own flow and success callbacks,
      // but if we want to show a success dialog, we might need to wait for it.
      // For now, web purchase redirects to Stripe checkout usually.
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
              backgroundColor: WebColors.purplePrimary,
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

  Widget _buildPageIndicator(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 8,
          width: _currentPage == index ? 24 : 8,
          decoration: BoxDecoration(
            color: _currentPage == index
                ? WebColors.purplePrimary
                : const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Widget _buildSatisfactionSection() {
    return Container(
      width: 1000,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9).withAlpha(127),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified_user_outlined,
                  color: WebColors.purplePrimary, size: 24),
              const SizedBox(width: 12),
              Text(
                'Satisfaction Guarantee',
                style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Not seeing the results you expected? We offer a 14-day full refund policy\nfor any student who feels SumQuiz hasn\'t improved their revision efficiency.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 16, color: const Color(0xFF64748B), height: 1.5),
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _paymentLogo('VISA'),
              _paymentLogo('MASTERCARD'),
              _paymentLogo('STRIPE'),
              _paymentLogo('APPLE PAY'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _paymentLogo(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: const Color(0xFF94A3B8),
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _buildSecurePaymentSection() {
    return Column(
      children: [
        Text(
          'SECURE PAYMENT PROCESSING',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF94A3B8),
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.credit_card, color: Color(0xFF94A3B8), size: 32),
            const SizedBox(width: 24),
            const Icon(Icons.account_balance,
                color: Color(0xFF94A3B8), size: 32),
            const SizedBox(width: 24),
            const Icon(Icons.contactless_outlined,
                color: Color(0xFF94A3B8), size: 32),
          ],
        ),
      ],
    );
  }

  Widget _buildBoostSection({required bool isWeb}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              Text(
                'Neural Energy Boosters',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.displayLarge?.color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Low on energy? Refill your neural capacity instantly.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Container(
          height: 180,
          padding: EdgeInsets.symmetric(horizontal: isWeb ? 40 : 12),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _boostPacks.length,
            shrinkWrap: true,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final pack = _boostPacks[index];
              return Container(
                width: isWeb ? 300 : 260,
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Theme.of(context).dividerColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(5),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: pack['color'].withAlpha(25),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(pack['icon'], color: pack['color'], size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            pack['title'],
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            '+${pack['credits']} Credits',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF10B981),
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF1F5F9),
                              foregroundColor: const Color(0xFF0F172A),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text('Buy ${pack['price']}'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMobileBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: BottomNavigationBar(
        currentIndex: 2, // Plans
        type: BottomNavigationBarType.fixed,
        selectedItemColor: WebColors.purplePrimary,
        unselectedItemColor: const Color(0xFF94A3B8),
        selectedLabelStyle:
            GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle:
            GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 12),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.menu_book_outlined), label: 'Study'),
          BottomNavigationBarItem(
              icon: Icon(Icons.stars_outlined), label: 'Plans'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
        onTap: (index) {
          // Navigation logic
        },
      ),
    );
  }
}
