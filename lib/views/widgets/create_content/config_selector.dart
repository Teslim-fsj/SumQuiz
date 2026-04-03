import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ConfigSelector extends StatelessWidget {
  final String selectedDifficulty;
  final int selectedCount;
  final ValueChanged<String> onDifficultyChanged;
  final ValueChanged<int> onCountChanged;

  final List<String> selectedQuestionTypes;
  final ValueChanged<String> onToggleType;

  const ConfigSelector({
    super.key,
    required this.selectedDifficulty,
    required this.selectedCount,
    required this.selectedQuestionTypes,
    required this.onDifficultyChanged,
    required this.onCountChanged,
    required this.onToggleType,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Difficulty Level'),
        const SizedBox(height: 12),
        _buildDifficultyOptions(context),
        const SizedBox(height: 28),
        _buildSectionTitle(context, 'Number of Items'),
        const SizedBox(height: 12),
        _buildCountOptions(context),
        const SizedBox(height: 28),
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
        fontWeight: FontWeight.w800,
        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildDifficultyOptions(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final options = [
      ('easy', 'Easy', Icons.sentiment_satisfied_alt_rounded),
      ('intermediate', 'Medium', Icons.sentiment_neutral_rounded),
      ('advanced', 'Hard', Icons.sentiment_very_satisfied_rounded),
    ];

    return Row(
      children: options.map((opt) {
        final isSelected = selectedDifficulty == opt.$1;
        return Expanded(
          child: GestureDetector(
            onTap: () => onDifficultyChanged(opt.$1),
            child: Container(
              margin: EdgeInsets.only(right: opt.$1 == 'advanced' ? 0 : 8),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isSelected ? colorScheme.primary : theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.1),
                  width: 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : null,
              ),
              child: Column(
                children: [
                  Icon(
                    opt.$3,
                    color: isSelected ? Colors.white : colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    opt.$2,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCountOptions(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final counts = [10, 15, 20, 25];

    return Row(
      children: counts.map((count) {
        final isSelected = selectedCount == count;
        return Expanded(
          child: GestureDetector(
            onTap: () => onCountChanged(count),
            child: Container(
              margin: EdgeInsets.only(right: count == 25 ? 0 : 8),
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? colorScheme.secondary : theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? colorScheme.secondary : colorScheme.onSurface.withValues(alpha: 0.1),
                  width: 1.5,
                ),
              ),
              child: Text(
                count.toString(),
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : colorScheme.onSurface,
                ),
              ),
            ),
          ),
        );
      }).toList(),
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
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? colorScheme.tertiary : theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? colorScheme.tertiary : colorScheme.onSurface.withValues(alpha: 0.1),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  type.$2,
                  color: isSelected ? Colors.white : colorScheme.onSurfaceVariant,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  type.$1,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
