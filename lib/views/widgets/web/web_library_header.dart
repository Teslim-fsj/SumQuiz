import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WebLibraryHeader extends StatelessWidget {
  final TextEditingController searchController;
  final VoidCallback onImport;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;

  const WebLibraryHeader({
    super.key,
    required this.searchController,
    required this.onImport,
    required this.onNotifications,
    required this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Search Bar
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9).withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(22),
              ),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Search your library...',
                  hintStyle: GoogleFonts.outfit(
                    color: const Color(0xFF64748B),
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B), size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          // Import Button
          ElevatedButton(
            onPressed: onImport,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            ),
            child: Text(
              'Import',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          const SizedBox(width: 16),
          // Notifications
          IconButton(
            onPressed: onNotifications,
            icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF475569)),
            style: IconButton.styleFrom(
              backgroundColor: Colors.transparent,
            ),
          ),
          const SizedBox(width: 8),
          // Profile Avatar
          InkWell(
            onTap: onProfile,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                image: DecorationImage(
                  image: AssetImage('assets/images/web/profile_placeholder.png'), // Will fallback to icon if not found
                  fit: BoxFit.cover,
                ),
              ),
              child: Icon(Icons.person_outline_rounded, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
            ),
          ),
        ],
      ),
    );
  }
}
