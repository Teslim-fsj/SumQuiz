import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sumquiz/theme/web_theme.dart';

class PublicScaffoldWeb extends StatelessWidget {
  final Widget child;
  final bool isEducatorRoute;

  const PublicScaffoldWeb({
    super.key,
    required this.child,
    this.isEducatorRoute = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildTopBar(context),
          Expanded(
            child: Material(
              color: Colors.white,
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;
        final horizontalPadding = isMobile ? 16.0 : 40.0;
        return Container(
          color: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Logo
              InkWell(
                onTap: () {
                  if (isEducatorRoute) {
                    context.go('/landing');
                  }
                },
                child: Row(
                  children: [
                    Image.asset('assets/images/sumquiz_logo.png',
                        width: 32,
                        height: 32,
                        errorBuilder: (_, __, ___) => const Icon(Icons.school,
                            color: WebColors.purplePrimary, size: 32)),
                    const SizedBox(width: 12),
                    Text('SumQuiz',
                        style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1F1F1F),
                            letterSpacing: -0.5)),
                  ],
                ),
              ),

              // Center Links — hide on mobile
              if (!isMobile)
                Row(
                  children: [
                    _navLink('Features'),
                    const SizedBox(width: 32),
                    _navLink(isEducatorRoute ? 'Solutions' : 'How it Works'),
                    const SizedBox(width: 32),
                    _navLink('Pricing', onTap: () => context.push('/subscription')),
                    if (isEducatorRoute) ...[
                      const SizedBox(width: 32),
                      _navLink('Resources'),
                    ]
                  ],
                ),

              // Actions
              Row(
                children: [
                  if (!isEducatorRoute && !isMobile) ...[
                    OutlinedButton(
                      onPressed: () => context.go('/Educators'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1F1F1F),
                        side: BorderSide(color: Colors.grey[300]!),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                      ),
                      child: Text('For Teachers',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    const SizedBox(width: 16),
                  ],
                  if (isEducatorRoute && !isMobile) ...[
                    TextButton(
                      onPressed: () => context.go('/auth'),
                      child: Text('Sign In',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                              fontSize: 14)),
                    ),
                    const SizedBox(width: 16),
                  ],
                  ElevatedButton(
                    onPressed: () => context.go('/auth'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: WebColors.purplePrimary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 16 : 24, vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24)),
                    ),
                    child: Text('Get Started',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                  )
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _navLink(String text, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap ?? () {},
      child: Text(text,
          style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500)),
    );
  }
}
