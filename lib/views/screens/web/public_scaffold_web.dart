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
        final isMobile = constraints.maxWidth < 780;
        final horizontalPadding = isMobile ? 16.0 : 40.0;
        return Container(
          color: Colors.white,
          padding:
              EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Logo
              InkWell(
                onTap: () => context.go('/landing'),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/images/sumquiz_logo.png',
                      width: 32,
                      height: 32,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.school_rounded,
                        color: WebColors.purplePrimary,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'SumQuiz',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),

              // Center Links — hide on mobile
              if (!isMobile)
                Row(
                  children: [
                    _navLink(context, 'Students', onTap: () => context.go('/landing')),
                    const SizedBox(width: 28),
                    _navLink(context, 'Teachers', onTap: () => context.go('/educators')),
                    const SizedBox(width: 28),
                    _navLink(context, 'Partnership', onTap: () => context.go('/creator-program')),
                    const SizedBox(width: 28),
                    _navLink(context, 'Pricing', onTap: () => context.push('/settings/subscription')),
                  ],
                ),

              // Actions
              Row(
                children: [
                  TextButton(
                    onPressed: () => context.go('/auth'),
                    child: Text(
                      'Sign In',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF334155),
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => context.go('/auth'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: WebColors.purplePrimary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 16 : 22,
                        vertical: 14,
                      ),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: Text(
                      'Get Started',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _navLink(BuildContext context, String text, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF475569),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
