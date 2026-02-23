import 'package:flutter/material.dart';

class ExtractionProgressDialog extends StatelessWidget {
  final ValueNotifier<String> messageNotifier;
  final VoidCallback? onCancel;

  const ExtractionProgressDialog({
    super.key,
    required this.messageNotifier,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Extracting Content'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          ValueListenableBuilder<String>(
            valueListenable: messageNotifier,
            builder: (context, message, _) {
              return Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              );
            },
          ),
          if (onCancel != null) ...[
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: onCancel,
              icon: const Icon(Icons.close, color: Colors.redAccent),
              label: const Text(
                'Cancel',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
