import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sumquiz/theme/web_theme.dart';

class GetMobileAppDialog extends StatelessWidget {
  final String title;
  final String description;

  const GetMobileAppDialog({
    super.key,
    this.title = 'Get SumQuiz on Mobile',
    this.description =
        'To access all features, including Pro subscriptions and offline study, please download the SumQuiz mobile app.',
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 450,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: WebColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.phone_android_rounded,
                  color: WebColors.primary, size: 40),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: WebColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: WebColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => launchUrl(Uri.parse(
                  'https://play.google.com/store/apps/details?id=com.sumquiz.app')),
              style: ElevatedButton.styleFrom(
                backgroundColor: WebColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.download_rounded),
                  SizedBox(width: 12),
                  Text(
                    'Download on Play Store',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Later',
                style: TextStyle(
                  color: WebColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
