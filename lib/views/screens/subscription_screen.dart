import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:go_router/go_router.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/services/web_payment_service.dart';
import 'package:sumquiz/providers/subscription_provider.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  ProductDetails? _selectedProduct;
  List<ProductDetails> _products = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final subscriptionProvider =
        Provider.of<SubscriptionProvider>(context, listen: false);

    if (kIsWeb) {
      // Web Flow still uses WebPaymentService directly or we could move it to provider too
      try {
        final products = await WebPaymentService().getAvailableProducts();
        if (mounted) {
          setState(() {
            _products = products;
            _setDefaultSelection();
          });
        }
      } catch (e) {
        debugPrint('Error loading web products: $e');
      }
    } else {
      // Mobile Flow - use provider
      await subscriptionProvider.loadProducts();
      if (mounted) {
        setState(() {
          _products = subscriptionProvider.products;

          // If still empty on mobile, provide fallback informational products
          if (_products.isEmpty) {
            debugPrint(
                'Using fallback product details as IAP products could not be loaded');
            _products = [
              _FallbackProductDetails(
                id: 'sumquiz_pro_weekly',
                title: 'Weekly Pro',
                description: 'Standard weekly plan',
                price: r'US$2.99',
                rawPrice: 2.99,
              ),
              _FallbackProductDetails(
                id: 'sumquiz_pro_monthly',
                title: 'Monthly Pro',
                description: 'Standard monthly plan',
                price: r'US$9.99',
                rawPrice: 9.99,
              ),
              _FallbackProductDetails(
                id: 'sumquiz_pro_yearly',
                title: 'Annual Pro',
                description: 'Best value annual plan',
                price: r'US$59.99',
                rawPrice: 59.99,
              ),
            ];
          }

          _products.sort((a, b) => a.rawPrice.compareTo(b.rawPrice));
          _setDefaultSelection();
        });
      }
    }
  }

  void _setDefaultSelection() {
    if (_products.isNotEmpty) {
      // First try to find a yearly product
      _selectedProduct = _products.firstWhere(
        (p) => p.id.contains('yearly'),
        orElse: () {
          // Then try to find a monthly product
          return _products.firstWhere(
            (p) => p.id.contains('monthly'),
            orElse: () {
              // Finally, just pick the first available product
              return _products.first;
            },
          );
        },
      );
    }
  }

  Future<void> _refreshProducts() async {
    await _loadProducts();
  }

  Future<void> _buyProduct() async {
    if (_selectedProduct == null) return;

    final subscriptionProvider = context.read<SubscriptionProvider>();

    bool success;

    if (kIsWeb) {
      // Web Payment Flow with Links

      final user = context.read<UserModel?>();
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please log in to make a purchase'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final result = await WebPaymentService().processWebPurchase(
        context: context,
        product: _selectedProduct!,
        user: user,
      );

      if (mounted) {
        if (!result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.errorMessage ?? 'Payment failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
        // If success, the link is opened in a new tab, so we don't need to do anything here.
        // Optionally show a "Confirming..." dialog if we were listening for webhooks.
      }
    } else {
      // Mobile Payment Flow
      success =
          await subscriptionProvider.purchaseProduct(_selectedProduct!.id);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Upgrade Successful!'),
              backgroundColor: Colors.green,
            ),
          );
          // Give user time to see success message
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) context.pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Purchase failed. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subscriptionProvider = context.watch<SubscriptionProvider>();
    final user = context.watch<UserModel?>();

    if (user != null && user.isPro) {
      return _buildAlreadyProView(context, theme);
    }

    final primaryColor = theme.colorScheme.primary;
    final scaffoldBg = theme.scaffoldBackgroundColor;
    final onSurface = theme.colorScheme.onSurface;
    final onSurfaceVariant = theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: subscriptionProvider.isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : Stack(
              children: [
                // Main Content
                SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Image/Icon Section
                      Stack(
                        children: [
                          Container(
                            height: 240,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  theme.colorScheme.primary
                                      .withValues(alpha: 0.1),
                                  scaffoldBg
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            child: Center(
                              child: Icon(Icons.auto_awesome_rounded,
                                  color: primaryColor.withValues(alpha: 0.5),
                                  size: 120),
                            ),
                          ),
                          Positioned(
                            top: 50,
                            left: 20,
                            child: IconButton(
                              icon: Icon(Icons.close,
                                  color: theme.colorScheme.onSurface),
                              onPressed: () => context.pop(),
                            ),
                          ),
                        ],
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SumQuiz Pro',
                              style: theme.textTheme.displaySmall?.copyWith(
                                  color: onSurface,
                                  fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Master your exams with AI-powered study tools',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                  color: onSurfaceVariant, fontSize: 16),
                            ),
                            const SizedBox(height: 32),

                            // Features List
                            _buildFeatureItem(
                                'Unlimited AI Generations',
                                'Generate as many decks as you need',
                                Icons.bolt_rounded,
                                theme),
                            _buildFeatureItem(
                                'Advanced File Analysis',
                                'Support for PDF, Images, and Voice',
                                Icons.description_rounded,
                                theme),
                            _buildFeatureItem(
                                'Spaced Repetition',
                                'Scientifically proven memory retention',
                                Icons.psychology_rounded,
                                theme),
                            _buildFeatureItem(
                                'No Daily Limits',
                                'Study without restrictions',
                                Icons.all_inclusive_rounded,
                                theme),

                            const SizedBox(height: 16),

                            // Plan Selection
                            Text(
                              'Choose your plan',
                              style: theme.textTheme.titleLarge?.copyWith(
                                  color: onSurface,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),

                            // Services (IAPService/WebPaymentService) already filter to allowed plans
                            if (_products.isEmpty &&
                                !subscriptionProvider.isLoading)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32.0),
                                  child: Column(
                                    children: [
                                      Text(
                                        'Unable to load subscription plans. This might be due to a connection issue or Google Play Store availability.',
                                        textAlign: TextAlign.center,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      TextButton.icon(
                                        onPressed: _loadProducts,
                                        icon: const Icon(Icons.refresh),
                                        label:
                                            const Text('Retry Loading Plans'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ..._products.map(
                                (product) => _buildPlanCard(product, theme)),

                            const SizedBox(
                                height: 140), // Spacer for bottom button
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom CTA
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [scaffoldBg.withValues(alpha: 0), scaffoldBg],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.3],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _selectedProduct != null &&
                                    !subscriptionProvider.isLoading
                                ? _buyProduct
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: subscriptionProvider.isLoading
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        color: theme.colorScheme.onPrimary,
                                        strokeWidth: 2))
                                : Text(
                                    'Continue',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildFooterLink('Terms of Service', theme),
                            const SizedBox(width: 16),
                            _buildFooterLink('Privacy Policy', theme),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFeatureItem(
      String title, String subtitle, IconData icon, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(ProductDetails product, ThemeData theme) {
    final primaryColor = theme.colorScheme.primary;
    final cardBg = theme.cardColor;
    final onSurface = theme.colorScheme.onSurface;
    final onSurfaceVariant = theme.colorScheme.onSurfaceVariant;

    final isSelected = _selectedProduct?.id == product.id;
    final isYearly = product.id.contains('yearly');
    final discountText = isYearly ? 'Save 30% compared to monthly' : null;
    final badgeText = isYearly ? 'BEST VALUE' : 'FLEXIBLE';

    return GestureDetector(
      onTap: () => setState(() => _selectedProduct = product),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withValues(alpha: 0.05) : cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : theme.dividerColor.withValues(alpha: 0.1),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isYearly)
                        Icon(Icons.stars_rounded,
                            color: primaryColor, size: 16),
                      if (isYearly) const SizedBox(width: 6),
                      Text(
                        badgeText,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isYearly ? primaryColor : onSurfaceVariant,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isYearly ? 'Yearly Plan' : 'Monthly Plan',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (discountText != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      discountText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  product.price,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: onSurface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  isYearly ? '/year' : '/month',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterLink(String text, ThemeData theme) {
    return InkWell(
      onTap: () {}, // Implement link action
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  Widget _buildAlreadyProView(BuildContext context, ThemeData theme) {
    final subscriptionProvider = context.watch<SubscriptionProvider>();
    final user = context.watch<UserModel?>();

    String statusText = 'Pro Member';
    String? expiryText;
    IconData statusIcon = Icons.check_circle_rounded;
    Color statusColor = theme.colorScheme.primary;

    if (user != null) {
      if (user.isCreatorPro) {
        statusText = 'Creator Pro';
        statusIcon = Icons.workspace_premium;
        statusColor = Colors.purple;
      } else if (user.isTrial) {
        statusText = 'Trial Member';
        statusIcon = Icons.timelapse;
        statusColor = Colors.orange;
        expiryText =
            'Trial ends in ${subscriptionProvider.getFormattedExpiry()}';
      } else if (subscriptionProvider.subscriptionExpiry != null) {
        expiryText = 'Expires in ${subscriptionProvider.getFormattedExpiry()}';
        if (subscriptionProvider.isExpiringSoon()) {
          statusText = 'Pro (Expiring Soon)';
          statusColor = Colors.orange;
        }
      } else {
        expiryText = 'Lifetime access';
      }
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(statusIcon, color: statusColor, size: 64),
            ),
            const SizedBox(height: 24),
            Text(
              statusText,
              style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold),
            ),
            if (expiryText != null) ...[
              const SizedBox(height: 8),
              Text(
                expiryText,
                style: theme.textTheme.bodyLarge
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => context.pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: statusColor,
                foregroundColor: theme.colorScheme.onPrimary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Back to Dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fallback product details for when the store is offline
class _FallbackProductDetails implements ProductDetails {
  @override
  final String id;
  @override
  final String title;
  @override
  final String description;
  @override
  final String price;
  @override
  final double rawPrice;
  @override
  final String currencyCode = 'USD';
  @override
  final String currencySymbol = '\$';

  _FallbackProductDetails({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.rawPrice,
  });
}
