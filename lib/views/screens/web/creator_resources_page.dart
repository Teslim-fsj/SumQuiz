import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sumquiz/models/creator_resource.dart';
import 'package:sumquiz/services/creator_program_service.dart';
import 'package:sumquiz/theme/web_theme.dart';

class CreatorResourcesPage extends StatefulWidget {
  const CreatorResourcesPage({super.key});

  @override
  State<CreatorResourcesPage> createState() => _CreatorResourcesPageState();
}

class _CreatorResourcesPageState extends State<CreatorResourcesPage>
    with SingleTickerProviderStateMixin {
  final _service = CreatorProgramService();
  late TabController _tabController;
  ResourceCategory _selectedCategory = ResourceCategory.brandAssets;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {
        _selectedCategory = ResourceCategory.values[_tabController.index];
      });
    });
    
    // Seed defaults if empty
    _service.seedResourcesIfEmpty();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Text(
          'Creator Resources',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: const Color(0xFF0F172A),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/creator-dashboard');
            }
          },
        ),
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 900;
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 40,
            vertical: 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Everything you need to succeed',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Download logos, use our proven content templates, and get ideas for your next video.',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 32),
              _buildTabs(),
              const SizedBox(height: 24),
              Expanded(
                child: StreamBuilder<List<CreatorResource>>(
                  stream: _service.getResourcesStream(
                      category: _selectedCategory.key),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: WebColors.purplePrimary),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    final resources = snapshot.data ?? [];
                    if (resources.isEmpty) {
                      return Center(
                        child: Text(
                          'No resources available in this category yet.',
                          style: GoogleFonts.inter(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      );
                    }
                    
                    if (isMobile) {
                      return ListView.builder(
                        itemCount: resources.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildResourceCard(resources[index]),
                          );
                        },
                      );
                    }

                    return GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 24,
                        mainAxisSpacing: 24,
                        childAspectRatio: 1.1,
                      ),
                      itemCount: resources.length,
                      itemBuilder: (context, index) {
                        return _buildResourceCard(resources[index]);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildTabs() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: WebColors.purplePrimary,
        unselectedLabelColor: Colors.grey[600],
        indicatorColor: WebColors.purplePrimary,
        labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold),
        unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500),
        isScrollable: true,
        tabs: ResourceCategory.values
            .map((c) => Tab(text: c.label))
            .toList(),
      ),
    );
  }

  Widget _buildResourceCard(CreatorResource resource) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (resource.emoji != null)
                Text(resource.emoji!, style: const TextStyle(fontSize: 24)),
              if (resource.emoji != null) const SizedBox(width: 12),
              Expanded(
                child: Text(
                  resource.title,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: resource.tags
                .map((tag) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '#$tag',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Text(
              resource.description,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final url = resource.externalUrl ?? resource.downloadUrl;
                if (url != null) {
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                }
              },
              icon: Icon(
                resource.downloadUrl != null
                    ? Icons.download_rounded
                    : Icons.open_in_new_rounded,
                size: 18,
              ),
              label: Text(resource.downloadUrl != null ? 'Download' : 'Open'),
              style: OutlinedButton.styleFrom(
                foregroundColor: WebColors.purplePrimary,
                side: const BorderSide(color: WebColors.purplePrimary),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
