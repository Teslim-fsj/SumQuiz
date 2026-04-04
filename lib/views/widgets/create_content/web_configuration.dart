import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sumquiz/providers/create_content_provider.dart';

class WebConfiguration extends StatelessWidget {
  final CreateContentProvider provider;
  final VoidCallback onGenerate;

  const WebConfiguration({
    super.key,
    required this.provider,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // LEFT COLUMN: MAIN CONFIG
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(right: 60, bottom: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Text(
                  'Configure Your Study Pack',
                  style: GoogleFonts.outfit(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1A1A1A),
                  ),
                ).animate().fadeIn().slideX(begin: -0.05, end: 0),
                const SizedBox(height: 16),
                Text(
                  'Tailor your learning experience. Our AI will curate content based on your difficulty preference and study archetype.',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF666666),
                    height: 1.5,
                  ),
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 60),

                // 1. DIFFICULTY LEVEL
                _buildSectionHeader('1. DIFFICULTY LEVEL'),
                const SizedBox(height: 24),
                Row(
                  children: [
                    _DifficultyCard(
                      label: 'Easy',
                      icon: Icons.sentiment_satisfied_alt_rounded,
                      isSelected: provider.selectedDifficulty == 'beginner',
                      onTap: () => provider.updateConfig(difficulty: 'beginner'),
                    ),
                    const SizedBox(width: 20),
                    _DifficultyCard(
                      label: 'Medium',
                      icon: Icons.electric_bolt_rounded,
                      isSelected: provider.selectedDifficulty == 'intermediate',
                      onTap: () => provider.updateConfig(difficulty: 'intermediate'),
                    ),
                    const SizedBox(width: 20),
                    _DifficultyCard(
                      label: 'Hard',
                      icon: Icons.trending_up_rounded,
                      isSelected: provider.selectedDifficulty == 'advanced',
                      onTap: () => provider.updateConfig(difficulty: 'advanced'),
                    ),
                  ],
                ),

                const SizedBox(height: 60),

                // 2 & 3: COUNTS
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('2. QUIZ QUESTIONS'),
                          const SizedBox(height: 24),
                          _CountSelector(
                            values: const [5, 15, 20],
                            selectedValue: provider.selectedCount,
                            onChanged: (v) => provider.updateConfig(count: v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 40),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('3. FLASHCARDS'),
                          const SizedBox(height: 24),
                          _CountSelector(
                            values: const [10, 20, 30, 50],
                            selectedValue: 30, // Mocked for now to match UI looks
                            onChanged: (v) {},
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 60),

                // 4. STUDY ARCHETYPE
                _buildSectionHeader('4. STUDY ARCHETYPE'),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _ArchetypeCard(
                        title: 'The Sprinter',
                        description: 'High-intensity, condensed summaries designed for rapid review cycles.',
                        icon: Icons.timer_outlined,
                        isSelected: provider.selectedArchetype == StudyArchetype.sprinter,
                        onTap: () => provider.updateConfig(archetype: StudyArchetype.sprinter),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _ArchetypeCard(
                        title: 'The Architect',
                        description: 'Structural mastery. Focuses on core concepts, hierarchies, and deep mental models.',
                        icon: Icons.architecture_rounded,
                        isSelected: provider.selectedArchetype == StudyArchetype.architect,
                        onTap: () => provider.updateConfig(archetype: StudyArchetype.architect),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // RIGHT COLUMN: SIDEBAR PREVIEW
        Container(
          width: 360,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FF),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: const Color(0xFFE0E6FF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Summary Preview',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 32),
              _PreviewItem(
                icon: Icons.electric_bolt_rounded,
                label: 'DIFFICULTY',
                value: provider.selectedDifficulty.toUpperCase(),
              ),
              _PreviewItem(
                icon: Icons.quiz_rounded,
                label: 'CONTENT',
                value: '${provider.selectedCount} Questions',
              ),
              _PreviewItem(
                icon: Icons.style_rounded,
                label: 'REVIEW',
                value: '30 Flashcards',
              ),
              _PreviewItem(
                icon: Icons.psychology_rounded,
                label: 'ARCHETYPE',
                value: provider.selectedArchetype == StudyArchetype.sprinter ? 'The Sprinter' : 'The Architect',
              ),
              const SizedBox(height: 48),
              
              // AI ESTIMATE
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F4FF),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF3300FF)),
                        const SizedBox(width: 8),
                        Text(
                          'AI ESTIMATE',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF3300FF),
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Estimated study time: 45-60 mins. This pack will focus heavily on conceptual logic and structural definitions.',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF444444),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // IMAGE PROMO
              Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  image: const DecorationImage(
                    image: AssetImage('assets/images/ready_banner.png'), // Need to check if exists or use placeholder
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
              
              // GENERATE BUTTON
               Container(
                width: double.infinity,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3300FF), Color(0xFF7C4DFF)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3300FF).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onGenerate,
                    borderRadius: BorderRadius.circular(32),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Generate Study Pack',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 1,
          width: 60,
          color: const Color(0xFFE0E6FF),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF3300FF),
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

class _DifficultyCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _DifficultyCard({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 140,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF3300FF) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? const Color(0xFF3300FF) : const Color(0xFFE0E6FF),
              width: 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF3300FF).withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ]
                : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 32,
                color: isSelected ? Colors.white : const Color(0xFF1A1A1A),
              ),
              const SizedBox(height: 16),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : const Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountSelector extends StatelessWidget {
  final List<int> values;
  final int selectedValue;
  final Function(int) onChanged;

  const _CountSelector({
    required this.values,
    required this.selectedValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ...values.map((v) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ChoiceChip(
                label: Text('$v'),
                selected: selectedValue == v,
                onSelected: (_) => onChanged(v),
                selectedColor: const Color(0xFFBDC7FF),
                backgroundColor: const Color(0xFFF4F6FF),
                labelStyle: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: selectedValue == v ? const Color(0xFF3300FF) : const Color(0xFF666666),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            )),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.edit_outlined, size: 14),
          label: const Text('Custom'),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF666666),
            textStyle: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold),
            backgroundColor: const Color(0xFFF4F6FF),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}

class _ArchetypeCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ArchetypeCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? const Color(0xFF3300FF) : const Color(0xFFE0E6FF),
            width: 2,
          ),
          boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF3300FF).withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ]
                : [],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F4FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF3300FF), size: 24),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF666666),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFF3300FF) : const Color(0xFFE0E6FF),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Center(
                      child: Icon(Icons.check_rounded, size: 16, color: Color(0xFF3300FF)),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _PreviewItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                )
              ],
            ),
            child: Icon(icon, color: const Color(0xFF3300FF), size: 20),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF999999),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
