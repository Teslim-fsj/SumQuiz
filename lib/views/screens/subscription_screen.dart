import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/providers/subscription_provider.dart';
import 'package:sumquiz/theme/web_theme.dart';
import 'package:sumquiz/services/web_payment_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isCreatorMode = false;
  final PageController _pageController = PageController(viewportFraction: 0.85, initialPage: 1);
  int _currentPage = 1;

  final List<Map<String, dynamic>> _studentTiers = [
    {
      'id': 'sumquiz_pro_starter',
      'title': 'Starter Academic',
      'price': r'$7.99',
      'sessions': '50',
      'label': 'FOCUS MODE',
      'color': Colors.blue,
      'description': 'Master your current coursework with precision.',
      'features': [
        '50 Study Sessions / mo',
        'Direct PDF & Photo Insights',
        'Smart Revision Summaries',
        'Standard AI Support'
      ]
    },
    {
      'id': 'sumquiz_pro_monthly',
      'title': 'High-Performer Pro',
      'price': r'$14.99',
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: subProvider.isLoading 
        ? const Center(child: CircularProgressIndicator(color: WebColors.purplePrimary))
        : LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 900) {
                return _buildWebLayout();
              } else {
                return _buildMobileLayout();
              }
            },
          ),
      bottomNavigationBar: kIsWeb ? null : _buildMobileBottomNav(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Color(0xFF1F1F1F)),
        onPressed: () => context.pop(),
      ),
      centerTitle: !kIsWeb,
      title: Text(
        kIsWeb ? '' : 'Subscription',
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.bold,
          color: const Color(0xFF1F1F1F),
          fontSize: 20,
        ),
      ),
      actions: kIsWeb ? [
        _buildWebNav(),
        const SizedBox(width: 40),
      ] : null,
    );
  }

  Widget _buildWebNav() {
    return Row(
      children: [
        _navItem('Home'),
        _navItem('Library'),
        _navItem('Plans', isActive: true),
        _navItem('Profile'),
        const SizedBox(width: 20),
        const CircleAvatar(
          radius: 16,
          backgroundColor: Color(0xFFF1F5F9),
          child: Icon(Icons.person_outline, size: 20, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget _navItem(String title, {bool isActive = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: isActive ? WebColors.purplePrimary : const Color(0xFF64748B),
            ),
          ),
          if (isActive)
            Container(
              margin: const EdgeInsets.only(top: 4),
              height: 2,
              width: 20,
              color: WebColors.purplePrimary,
            ),
        ],
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
              color: const Color(0xFF0F172A),
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Become a Top Performer. Unlock your full academic revision potential.',
            style: GoogleFonts.inter(
              fontSize: 18,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 40),
          _buildRoleToggle(),
          const SizedBox(height: 60),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: (_isCreatorMode ? _creatorTiers : _studentTiers).asMap().entries.map((entry) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _buildTierCard(entry.value, entry.key, isWeb: true),
                  ),
                );
              }).toList(),
            ),
          ),
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
                    color: const Color(0xFF0F172A),
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Choose a plan that fits your academic goals and unlock AI-powered tools.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: const Color(0xFF64748B),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _buildRoleToggle(),
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
          const SizedBox(height: 40),
          _buildSecurePaymentSection(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildRoleToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF2F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleButton('Student', !_isCreatorMode, () => setState(() {
            _isCreatorMode = false;
          })),
          _toggleButton('Creator', _isCreatorMode, () => setState(() {
            _isCreatorMode = true;
          })),
        ],
      ),
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
          boxShadow: active ? [
            BoxShadow(
              color: Colors.black.withAlpha(12),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ] : [],
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: active ? WebColors.purplePrimary : const Color(0xFF64748B),
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildTierCard(Map<String, dynamic> tier, int index, {required bool isWeb}) {
    bool isFeatured = tier['label'] == 'MOST CHOSEN';
    Color tierColor = tier['color'];
    final user = context.watch<UserModel?>();
    final subProvider = context.watch<SubscriptionProvider>();

    // Get real price from IAP if on mobile
    String displayPrice = tier['price'];
    if (!isWeb) {
      final iapProduct = subProvider.products.where((p) => p.id == tier['id']).firstOrNull;
      if (iapProduct != null) {
        displayPrice = iapProduct.price;
      }
    }

    bool isCurrentPlan = subProvider.currentProduct == tier['id'] && subProvider.isActive;

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isFeatured ? WebColors.purplePrimary : const Color(0xFFE2E8F0),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: WebColors.purplePrimary,
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
                  color: isFeatured ? const Color(0xFF0F172A) : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    displayPrice,
                    style: GoogleFonts.outfit(
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, left: 4),
                    child: Text(
                      '/mo',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ...tier['features'].map<Widget>((f) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: tierColor.withAlpha(25),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.check, color: tierColor, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        f,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          color: const Color(0xFF475569),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              )).toList(),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isCurrentPlan ? null : () => _handlePurchase(tier, user),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCurrentPlan 
                      ? const Color(0xFF10B981) // Success green
                      : (isFeatured ? WebColors.purplePrimary : (isWeb ? const Color(0xFFDBEAFE) : WebColors.purplePrimary)),
                    foregroundColor: isCurrentPlan 
                      ? Colors.white 
                      : (isFeatured ? Colors.white : (isWeb ? WebColors.purplePrimary : Colors.white)),
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(
                    isCurrentPlan ? 'Current Plan' : (isWeb ? 'Get Started Now' : 'Select Plan'),
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handlePurchase(Map<String, dynamic> tier, UserModel? user) {
    final productId = tier['id'] as String;
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
      context.read<SubscriptionProvider>().purchaseProduct(productId);
    }
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
            color: _currentPage == index ? WebColors.purplePrimary : const Color(0xFFE2E8F0),
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
              const Icon(Icons.verified_user_outlined, color: WebColors.purplePrimary, size: 24),
              const SizedBox(width: 12),
              Text(
                'Satisfaction Guarantee',
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Not seeing the results you expected? We offer a 14-day full refund policy\nfor any student who feels SumQuiz hasn\'t improved their revision efficiency.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 16, color: const Color(0xFF64748B), height: 1.5),
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
            const Icon(Icons.account_balance, color: Color(0xFF94A3B8), size: 32),
            const SizedBox(width: 24),
            const Icon(Icons.contactless_outlined, color: Color(0xFF94A3B8), size: 32),
          ],
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
        selectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 12),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book_outlined), label: 'Study'),
          BottomNavigationBarItem(icon: Icon(Icons.stars_outlined), label: 'Plans'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
        onTap: (index) {
          // Navigation logic
        },
      ),
    );
  }
}
