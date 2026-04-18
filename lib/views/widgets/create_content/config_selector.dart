import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sumquiz/providers/create_content_provider.dart';

class ConfigSelector extends StatelessWidget {
  final String selectedDifficulty;
  final int selectedQuizCount;
  final int selectedFlashcardCount;
  final ValueChanged<String> onDifficultyChanged;
  final ValueChanged<int> onQuizCountChanged;
  final ValueChanged<int> onFlashcardCountChanged;

  final List<String> selectedQuestionTypes;
  final ValueChanged<String> onToggleType;

  final StudyArchetype selectedArchetype;
  final ValueChanged<StudyArchetype> onArchetypeChanged;

  const ConfigSelector({
    super.key,
    required this.selectedDifficulty,
    required this.selectedQuizCount,
    required this.selectedFlashcardCount,
    required this.selectedQuestionTypes,
    required this.onDifficultyChanged,
    required this.onQuizCountChanged,
    required this.onFlashcardCountChanged,
    required this.onToggleType,
    required this.selectedArchetype,
    required this.onArchetypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Complexity Level'),
        const SizedBox(height: 12),
        _buildDifficultyOptions(context),
        const SizedBox(height: 24),
        
        _buildSectionTitle(context, 'Volume of Materials'),
        const SizedBox(height: 12),
        _buildCountRow(context),
        const SizedBox(height: 24),

        _buildSectionTitle(context, 'Study Archetype'),
        const SizedBox(height: 12),
        _buildArchetypeOptions(context),
        const SizedBox(height: 24),

        _buildSectionTitle(context, 'Quiz Format'),
        const SizedBox(height: 12),
        _buildQuizTypeOptions(context),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.outfit(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildDifficultyOptions(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final options = [
      ('beginner', 'Easy', Icons.sentiment_satisfied_alt_rounded),
      ('intermediate', 'Medium', Icons.sentiment_neutral_rounded),
      ('advanced', 'Hard', Icons.sentiment_very_satisfied_rounded),
    ];

    return Row(
      children: options.map((opt) {
        final isSelected = selectedDifficulty == opt.$1;
        return Expanded(
          child: GestureDetector(
            onTap: () => onDifficultyChanged(opt.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: opt.$1 == 'advanced' ? 0 : 8),
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: isSelected ? colorScheme.primary : theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.1),
                  width: 1.5,
                ),
                boxShadow: isSelected
                    ? [BoxShadow(color: colorScheme.primary.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))]
                    : null,
              ),
              child: Column(
                children: [
                  Icon(opt.$3, color: isSelected ? Colors.white : colorScheme.onSurfaceVariant, size: 22),
                  const SizedBox(height: 8),
                  Text(opt.$2, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800, color: isSelected ? Colors.white : colorScheme.onSurface)),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCountRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('QUIZ ITEMS', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              _buildCompactCountSelector(context, const [5, 10, 15, 20], selectedQuizCount, onQuizCountChanged, 'Quiz Items'),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('FLASHCARDS', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              _buildCompactCountSelector(context, const [10, 20, 30, 50], selectedFlashcardCount, onFlashcardCountChanged, 'Flashcards'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactCountSelector(BuildContext context, List<int> values, int selected, ValueChanged<int> onChanged, String title) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark ? Colors.white10 : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: values.contains(selected) ? selected : null,
          hint: Text('$selected', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
          items: [
            ...values.map((v) => DropdownMenuItem(value: v, child: Text('$v', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)))),
            DropdownMenuItem(
              value: -1,
              child: Row(
                children: [
                  const Icon(Icons.edit_note_rounded, size: 18),
                  const SizedBox(width: 8),
                  Text('Custom', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
          onChanged: (v) {
            if (v == -1) {
              _showCustomCountDialog(context, title, selected, onChanged);
            } else if (v != null) {
              onChanged(v);
            }
          },
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down_rounded),
        ),
      ),
    );
  }

  void _showCustomCountDialog(BuildContext context, String title, int current, ValueChanged<int> onChanged) {
    final controller = TextEditingController(text: current.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Custom $title'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter number',
            suffixText: 'items',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final val = int.tryParse(controller.text);
              if (val != null && val > 0 && val <= 100) {
                onChanged(val);
                Navigator.pop(context);
              }
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }

  Widget _buildArchetypeOptions(BuildContext context) {
    return Column(
      children: [
        _ArchetypeMobileCard(
          title: 'The Sprinter',
          description: 'High-intensity, condensed summaries for rapid review.',
          icon: Icons.timer_outlined,
          isSelected: selectedArchetype == StudyArchetype.sprinter,
          onTap: () => onArchetypeChanged(StudyArchetype.sprinter),
        ),
        const SizedBox(height: 12),
        _ArchetypeMobileCard(
          title: 'The Architect',
          description: 'Focuses on core concepts and mental models.',
          icon: Icons.architecture_rounded,
          isSelected: selectedArchetype == StudyArchetype.architect,
          onTap: () => onArchetypeChanged(StudyArchetype.architect),
        ),
      ],
    );
  }

  Widget _buildQuizTypeOptions(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final types = [
      ('Multiple Choice', Icons.list_rounded),
      ('True or False', Icons.check_circle_outline_rounded),
      ('Short Answer', Icons.short_text_rounded),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: types.map((type) {
        final isSelected = selectedQuestionTypes.contains(type.$1);
        return GestureDetector(
          onTap: () => onToggleType(type.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? colorScheme.secondary : theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isSelected ? colorScheme.secondary : colorScheme.onSurface.withOpacity(0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(type.$2, color: isSelected ? Colors.white : colorScheme.onSurfaceVariant, size: 16),
                const SizedBox(width: 8),
                Text(type.$1, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : colorScheme.onSurface)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ArchetypeMobileCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ArchetypeMobileCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? colorScheme.primary : const Color(0xFFE5E7EB), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: isSelected ? colorScheme.primary : const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: isSelected ? Colors.white : colorScheme.primary, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold)),
                  Text(description, style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey[600])),
                ],
              ),
            ),
            if (isSelected) const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
          ],
        ),
      ),
    );
  }
}
