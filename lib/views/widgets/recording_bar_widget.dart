import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/note_provider.dart';
import '../../models/user_model.dart';
import '../../widgets/pro_gate.dart';
import 'upgrade_dialog.dart';

class RecordingBarWidget extends StatelessWidget {
  const RecordingBarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final noteProvider = context.watch<NoteProvider>();
    final user = Provider.of<UserModel?>(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: ProGate(
          requiresPro: true,
          featureName: 'Lecture Recording',
          proContent: () =>
              _buildProRecordingUI(context, theme, noteProvider, user),
          freeContent: _buildFreeRecordingUI(context, theme),
        ),
      ),
    );
  }

  Widget _buildProRecordingUI(BuildContext context, ThemeData theme,
      NoteProvider provider, UserModel? user) {
    final isRecording = provider.state == NoteProcessingState.recording;
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        if (isRecording) ...[
          _buildPulsingDot(theme),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatDuration(provider.recordingDuration),
                  style: GoogleFonts.jetBrainsMono(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.redAccent),
                ),
                Text(
                  provider.speechAvailable
                      ? (provider.liveTranscript.isNotEmpty
                          ? '"${provider.liveTranscript}"'
                          : 'Listening — transcribing lecture in real-time…')
                      : 'Saving audio (transcript offline)',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      height: 1.4,
                      color: provider.liveTranscript.isNotEmpty
                          ? theme.colorScheme.onSurface.withValues(alpha: 0.85)
                          : theme.hintColor.withValues(alpha: 0.60),
                      fontStyle: provider.liveTranscript.isNotEmpty
                          ? FontStyle.italic
                          : FontStyle.normal,
                      fontWeight: provider.liveTranscript.isNotEmpty
                          ? FontWeight.w500
                          : FontWeight.w400),
                ),
              ],
            ),
          ),
          IconButton.filled(
            icon: const Icon(Icons.stop_rounded, size: 28),
            onPressed: () => provider.stopRecording(),
            style: IconButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding: const EdgeInsets.all(12),
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child:
                Icon(Icons.mic_rounded, color: colorScheme.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Live Lecture Recording',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                Text('Ready to capture insights',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: theme.hintColor)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => provider.startRecording(user?.uid ?? ''),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.play_arrow_rounded, size: 20),
                const SizedBox(width: 8),
                Text('Start',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFreeRecordingUI(BuildContext context, ThemeData theme) {
    return Row(
      children: [
        Icon(Icons.lock_outline_rounded, color: theme.hintColor, size: 20),
        const SizedBox(width: 12),
        Text('Recording is a Pro feature',
            style: GoogleFonts.inter(
                color: theme.hintColor, fontWeight: FontWeight.w500)),
        const Spacer(),
        TextButton(
          onPressed: () {
            UpgradeDialog.show(context, featureName: 'Lecture Recording');
          },
          child: Text('Upgrade',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildPulsingDot(ThemeData theme) {
    return Container(
      width: 12,
      height: 12,
      decoration: const BoxDecoration(
        color: Colors.redAccent,
        shape: BoxShape.circle,
      ),
    )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .scale(
            begin: const Offset(0.8, 0.8),
            end: const Offset(1.2, 1.2),
            duration: 600.ms,
            curve: Curves.easeInOut)
        .then()
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .boxShadow(
            begin: const BoxShadow(color: Colors.transparent, blurRadius: 0),
            end: BoxShadow(
                color: Colors.redAccent.withValues(alpha: 0.4),
                blurRadius: 10));
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }
}
