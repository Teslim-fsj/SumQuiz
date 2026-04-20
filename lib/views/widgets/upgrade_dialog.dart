import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class UpgradeDialog extends StatelessWidget {
  final String featureName;

  const UpgradeDialog({super.key, required this.featureName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: theme.colorScheme.surface,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium_outlined,
              color: theme.colorScheme.primary, size: 48),
          const SizedBox(height: 16),
          Text(
            'Limitless Potential',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      content: Text(
        'You are currently missing 70% of the revision potential for this session. Become a consistent top-performing student today.',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyLarge,
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.push('/subscription');
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Unlock Full Access', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Maybe Later', style: TextStyle(color: Colors.grey[600])),
          ),
        ),
      ],
    );
  }
}
