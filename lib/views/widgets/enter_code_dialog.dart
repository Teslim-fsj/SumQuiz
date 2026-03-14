import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:sumquiz/services/firestore_service.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class EnterCodeDialog extends StatefulWidget {
  const EnterCodeDialog({super.key});

  @override
  State<EnterCodeDialog> createState() => _EnterCodeDialogState();
}

class _EnterCodeDialogState extends State<EnterCodeDialog> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  String? _extractCodeFromLink(String data) {
    if (data.length == 6) return data.toUpperCase();

    // Handle sumquiz.app/s/CODE or https://sumquiz.app/s/CODE
    final uri = Uri.tryParse(data);
    if (uri != null &&
        (uri.host == 'sumquiz.app' || data.contains('sumquiz.app/s/'))) {
      final pathSegments = uri.pathSegments;
      if (pathSegments.length >= 2 &&
          pathSegments[pathSegments.length - 2] == 's') {
        return pathSegments.last.toUpperCase();
      }
      // Fallback for simple formats
      final parts = data.split('/s/');
      if (parts.length > 1) {
        final codeCandidate = parts.last.split('?').first;
        if (codeCandidate.length == 6) return codeCandidate.toUpperCase();
      }
    }
    return null;
  }

  Future<void> _redeemCode([String? providedCode]) async {
    final code = (providedCode ?? _codeController.text).trim().toUpperCase();

    if (code.isEmpty) {
      if (providedCode == null) {
        setState(() => _errorMessage = 'Please enter a code');
      }
      return;
    }

    if (code.length != 6) {
      setState(() => _errorMessage = 'Code must be 6 characters');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final deck = await FirestoreService().fetchPublicDeckByCode(code);

      if (deck == null) {
        setState(() {
          _errorMessage = 'Invalid code. Please check and try again.';
          _isLoading = false;
        });
        return;
      }

      // Navigate to public deck screen to import
      if (mounted) {
        Navigator.of(context).pop(); // Close dialog
        context.push('/deck?id=${deck.id}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _showScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Scan Exam Paper',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            const Text('Frame the QR code on the paper'),
            const SizedBox(height: 24),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: MobileScanner(
                  onDetect: (capture) {
                    final List<Barcode> barcodes = capture.barcodes;
                    for (final barcode in barcodes) {
                      final data = barcode.rawValue;
                      if (data != null) {
                        final extracted = _extractCodeFromLink(data);
                        if (extracted != null) {
                          Navigator.pop(context); // Close scanner
                          _redeemCode(extracted);
                          return;
                        }
                      }
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.qr_code_scanner,
              size: 64,
              color: theme.colorScheme.primary,
            ).animate().scale(duration: 300.ms),
            const SizedBox(height: 16),
            Text(
              'Enter Share Code',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Import a deck shared by a creator',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Code Input
            TextField(
              controller: _codeController,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                letterSpacing: 8,
                fontWeight: FontWeight.bold,
              ),
              maxLength: 6,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'ABC123',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 2,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outline,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 2,
                  ),
                ),
                errorText: _errorMessage,
                counterText: '',
              ),
              onChanged: (value) {
                if (_errorMessage != null) {
                  setState(() => _errorMessage = null);
                }
              },
              onSubmitted: (_) => _redeemCode(),
            ),

            const SizedBox(height: 24),

            // Scan QR Button
            OutlinedButton.icon(
              onPressed: _showScanner,
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Scan QR Code'),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Redeem Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _redeemCode,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Import Deck'),
              ),
            ),

            const SizedBox(height: 8),

            // Cancel Button
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
