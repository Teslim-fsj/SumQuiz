import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/note_provider.dart';
import '../../models/user_model.dart';
import '../../widgets/pro_gate.dart';

class RecordingBarWidget extends StatelessWidget {
  const RecordingBarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final noteProvider = context.watch<NoteProvider>();
    final user = Provider.of<UserModel?>(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.9),
        border:
            Border(top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1))),
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

    return Row(
      children: [
        if (isRecording) ...[
          _buildPulsingDot(theme),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatDuration(provider.recordingDuration),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontFamily: 'monospace', color: Colors.red),
              ),
              const Text('Lecture in progress...', style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
          const Spacer(),
          IconButton.filled(
            icon: const Icon(Icons.stop_rounded),
            onPressed: () => provider.stopRecording(),
            style: IconButton.styleFrom(backgroundColor: Colors.red),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.mic_rounded, color: Colors.blue, size: 20),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Live Lecture Recording', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text('Tap to start capturing audio', style: TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () => provider.startRecording(user?.uid ?? ''),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Start'),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFreeRecordingUI(BuildContext context, ThemeData theme) {
    return Row(
      children: [
        Icon(Icons.mic_off_rounded, color: theme.hintColor),
        const SizedBox(width: 8),
        Text('Recording is a Pro feature',
            style: TextStyle(color: theme.hintColor)),
        const Spacer(),
        TextButton(
          onPressed: () {
            // Navigator or something to upgrade
          },
          child: const Text('Upgrade'),
        ),
      ],
    );
  }

  Widget _buildPulsingDot(ThemeData theme) {
    return Container(
      width: 12,
      height: 12,
      decoration: const BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
      ),
    )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .scale(
            begin: const Offset(0.8, 0.8),
            end: const Offset(1.2, 1.2),
            duration: 500.ms)
        .then()
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .boxShadow(
            begin: BoxShadow(color: Colors.red.withValues(alpha: 0), blurRadius: 0),
            end: BoxShadow(color: Colors.red.withValues(alpha: 0.5), blurRadius: 10));
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }
}
