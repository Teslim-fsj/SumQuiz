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
  int _selectedTierIndex = 1; // Default to Standard/Standard
  bool _isCreatorMode = false;
  
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
        'Personal Growth Analytics'
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
        'High-Yield Interactive Quizzes',
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
        'Unrestricted Growth Tools'
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
      'color': Color(0xFF6366F1),
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1F1F1F)),
          onPressed: () => context.pop(),
        ),
        title: Text('Subscription Plans', 
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF1F1F1F))),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
            _buildRoleToggle(),
            const SizedBox(height: 40),
            ...(_isCreatorMode ? _creatorTiers : _studentTiers).asMap().entries.map((entry) {
              return _buildTierCard(entry.value, entry.key);
            }),
            const SizedBox(height: 48),
            _buildCreditInfo(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text(_isCreatorMode ? 'Empower Your Students' : 'Become a Top Performer', 
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w900, color: const Color(0xFF1F1F1F))),
        const SizedBox(height: 8),
        Text(_isCreatorMode 
          ? 'Professional tools for professional educators.' 
          : 'Unlock your full academic revision potential.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildRoleToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleButton('Student', !_isCreatorMode, () => setState(() => _isCreatorMode = false)),
          _toggleButton('Creator', _isCreatorMode, () => setState(() => _isCreatorMode = true)),
        ],
      ),
    );
  }

  Widget _toggleButton(String text, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          boxShadow: active ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))] : [],
        ),
        child: Text(text, 
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold, 
            color: active ? const Color(0xFF1F1F1F) : Colors.grey[600],
            fontSize: 14)),
      ),
    );
  }

  Widget _buildTierCard(Map<String, dynamic> tier, int index) {
    bool isSelected = _selectedTierIndex == index;
    Color tierColor = tier['color'];
    
    return GestureDetector(
      onTap: () => setState(() => _selectedTierIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isSelected ? tierColor.withOpacity(0.02) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? tierColor : const Color(0xFFE2E8F0),
            width: isSelected ? 2.5 : 1.5),
          boxShadow: isSelected ? [BoxShadow(color: tierColor.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))] : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: tierColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Text(tier['label'], style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: tierColor, letterSpacing: 1)),
                ),
                Text(tier['price'], style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF1F1F1F))),
              ],
            ),
            const SizedBox(height: 16),
            Text(tier['title'], style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(tier['description'], style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600])),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.auto_awesome_outlined, color: tierColor, size: 20),
                const SizedBox(width: 8),
                Text(_isCreatorMode 
                  ? '${tier['sessions']} Generations' 
                  : '${tier['sessions']} Study Sessions', 
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: tierColor)),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            ...tier['features'].map<Widget>((f) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: tierColor, size: 18),
                  const SizedBox(width: 12),
                  Text(f, style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[700])),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildCreditInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: WebColors.purplePrimary.withValues(alpha: 0.05), 
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WebColors.purplePrimary.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_outlined, color: WebColors.purplePrimary, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Satisfaction Guarantee', 
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: WebColors.purplePrimary)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Join 50,000+ top students using AI to master their coursework. Cancellable anytime.', 
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[700])),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final user = context.watch<UserModel?>();
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[100]!)),
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: () {
            if (kIsWeb && user != null) {
              final tier = _isCreatorMode ? _creatorTiers[_selectedTierIndex] : _studentTiers[_selectedTierIndex];
              final productId = tier['id'];
              
              final webService = WebPaymentService();
              final product = WebPaymentService.webProducts.firstWhere((p) => p.id == productId);
              
              webService.processWebPurchase(
                context: context,
                product: product,
                user: user,
              );
            } else if (user != null) {
              final tier = _isCreatorMode ? _creatorTiers[_selectedTierIndex] : _studentTiers[_selectedTierIndex];
              context.read<SubscriptionProvider>().purchaseProduct(tier['id']);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1F1F1F),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          child: Text('Get Started Now', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      ),
    );
  }
}

