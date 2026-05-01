import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/note_provider.dart';
import '../../models/user_model.dart';
import '../../widgets/pro_gate.dart';
import '../../services/recording_service.dart';

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
        color: theme.cardColor.withOpacity(0.9),
        border: Border(top: BorderSide(color: theme.dividerColor.withOpacity(0.1))),
      ),
      child: SafeArea(
        top: false,
        child: ProGate(
          requiresPro: true,
          featureName: 'Lecture Recording',
          proContent: () => _buildProRecordingUI(context, theme, noteProvider, user),
          freeContent: _buildFreeRecordingUI(context, theme),
        ),
      ),
    );
  }

  Widget _buildProRecordingUI(BuildContext context, ThemeData theme, NoteProvider provider, UserModel? user) {
    final isRecording = provider.state == NoteProcessingState.recording;
    
    return Row(
      children: [
        if (isRecording) ...[
          _buildPulsingDot(theme),
          const SizedBox(width: 8),
          Text(
            _formatDuration(provider.recordingDuration),
            style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace'),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.stop_circle_rounded, color: Colors.red, size: 32),
            onPressed: () => provider.stopRecording(),
          ),
        ] else ...[
          const Icon(Icons.mic_none_rounded),
          const SizedBox(width: 8),
          const Text('Tap to start recording lecture'),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.mic_rounded, color: Colors.blue, size: 32),
            onPressed: () => provider.startRecording(user?.uid ?? ''),
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
        Text('Recording is a Pro feature', style: TextStyle(color: theme.hintColor)),
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
    ).animate(onPlay: (controller) => controller.repeat(reverse: true))
     .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2), duration: 500.ms)
     .then()
     .animate(onPlay: (controller) => controller.repeat(reverse: true))
     .boxShadow(begin: BoxShadow(color: Colors.red.withOpacity(0), blurRadius: 0),
                end: BoxShadow(color: Colors.red.withOpacity(0.5), blurRadius: 10));
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }
}
