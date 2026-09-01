import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../providers/note_provider.dart';

class LiveRecordingView extends StatefulWidget {
  final NoteProvider noteProvider;
  final String title;
  final String? topic;
  final VoidCallback onStopRecording;
  final VoidCallback onBack;

  const LiveRecordingView({
    super.key,
    required this.noteProvider,
    required this.title,
    this.topic,
    required this.onStopRecording,
    required this.onBack,
  });

  @override
  State<LiveRecordingView> createState() => _LiveRecordingViewState();
}

class _LiveRecordingViewState extends State<LiveRecordingView> {
  final ScrollController _scrollController = ScrollController();
  final List<String> _bookmarkedMoments = [];
  bool _isPaused = false;
  String _detectedInsight = 'Key concept detected: Active recall boosts long-term retention.';

  StreamSubscription<String>? _transcriptSub;

  @override
  void initState() {
    super.initState();
    _transcriptSub = widget.noteProvider.transcriptChunkStream.listen((chunk) {
      if (mounted && chunk.isNotEmpty) {
        _updateDynamicInsight(chunk);
        _scrollToBottom();
      }
    });
  }

  void _updateDynamicInsight(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('entropy') || lower.contains('second law')) {
      setState(() {
        _detectedInsight = 'Key concept detected: Entropy indicates disorder.';
      });
    } else if (lower.contains('mitochondria') || lower.contains('atp')) {
      setState(() {
        _detectedInsight = 'Key concept detected: Mitochondria produces ATP energy.';
      });
    } else if (lower.contains('important') || lower.contains('exam')) {
      setState(() {
        _detectedInsight = 'High-priority exam concept flagged by instructor.';
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _transcriptSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
    });
    if (_isPaused) {
      widget.noteProvider.pauseRecording();
    } else {
      widget.noteProvider.resumeRecording();
    }
  }

  void _bookmarkCurrentMoment() {
    final duration = widget.noteProvider.recordingDuration;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final timestamp = '$minutes:$seconds';

    setState(() {
      _bookmarkedMoments.add(timestamp);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.bookmark_added_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('Bookmarked moment at $timestamp', style: GoogleFonts.inter(fontSize: 14)),
          ],
        ),
        backgroundColor: const Color(0xFF6B5CE7),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentNote = widget.noteProvider.currentNote;
    final plainText = currentNote?.plainText ?? '';

    // Sample default text if transcript is starting
    final displayText = plainText.trim().isNotEmpty
        ? plainText
        : '...so when we consider the second law, it fundamentally dictates the direction of spontaneous processes.\n\nIt states that the total entropy of an isolated system can never decrease over time.\n\nThis means that the universe is constantly moving towards a state of higher disorder or randomness...';

    final lectureTitle = widget.title.isNotEmpty ? widget.title : 'Lecture 4';
    final lectureTopic = widget.topic ?? 'Thermodynamics';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            size: 24,
          ),
          onPressed: widget.onBack,
        ),
        centerTitle: true,
        title: Text(
          'Live Recording',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Lecture Title & Subject
            Text(
              lectureTitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              lectureTopic,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 28),

            // Soundwave Visualizer Bars
            _buildAnimatedSoundwave(isDark),
            const SizedBox(height: 36),

            // Live Transcription & Sumi Insight
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // LIVE TRANSCRIPTION indicator
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEF4444),
                              shape: BoxShape.circle,
                            ),
                          )
                              .animate(onPlay: (controller) => controller.repeat(reverse: true))
                              .scale(begin: const Offset(1, 1), end: const Offset(1.3, 1.3), duration: 800.ms),
                          const SizedBox(width: 8),
                          Text(
                            'LIVE TRANSCRIPTION',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Streaming Transcription Text
                      Text(
                        displayText,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          height: 1.65,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Sumi Insight Card
                      _buildSumiInsightCard(isDark),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom 3 Action Buttons (Bookmark, Pause/Resume, Stop)
            _buildBottomControls(isDark),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedSoundwave(bool isDark) {
    return StreamBuilder<double>(
      stream: widget.noteProvider.amplitudeStream,
      builder: (context, snapshot) {
        final amplitude = _isPaused ? 0.05 : (snapshot.data ?? 0.3);

        final barHeights = [
          14.0 + (amplitude * 18),
          22.0 + (amplitude * 32),
          32.0 + (amplitude * 44),
          42.0 + (amplitude * 50),
          30.0 + (amplitude * 38),
          20.0 + (amplitude * 26),
          12.0 + (amplitude * 14),
        ];

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(barHeights.length, (index) {
            final isCenter = index >= 2 && index <= 4;
            final color = isCenter
                ? const Color(0xFF4338CA)
                : const Color(0xFF818CF8).withValues(alpha: 0.7);

            return AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 5,
              height: barHeights[index].clamp(8.0, 52.0),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildSumiInsightCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              color: Color(0xFF3B82F6),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sumi Insight',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF3B82F6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _detectedInsight,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.4,
                    color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.08, end: 0);
  }

  Widget _buildBottomControls(bool isDark) {
    final baseBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final iconColor = isDark ? Colors.white70 : const Color(0xFF475569);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Bookmark Button (Left)
          Tooltip(
            message: 'Flag key moment',
            child: Material(
              color: baseBg,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: _bookmarkCurrentMoment,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 58,
                  height: 58,
                  alignment: Alignment.center,
                  child: Icon(Icons.bookmark_border_rounded, color: iconColor, size: 24),
                ),
              ),
            ),
          ),

          // 2. Center Pause / Resume Button (Large Purple)
          Tooltip(
            message: _isPaused ? 'Resume recording' : 'Pause recording',
            child: Material(
              color: const Color(0xFF4338CA),
              shape: const CircleBorder(),
              elevation: 4,
              shadowColor: const Color(0xFF4338CA).withValues(alpha: 0.4),
              child: InkWell(
                onTap: _togglePause,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 72,
                  height: 72,
                  alignment: Alignment.center,
                  child: Icon(
                    _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),
            ),
          ),

          // 3. Stop Button (Right)
          Tooltip(
            message: 'Finish & save lecture',
            child: Material(
              color: baseBg,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: widget.onStopRecording,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 58,
                  height: 58,
                  alignment: Alignment.center,
                  child: Icon(Icons.stop_rounded, color: iconColor, size: 26),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
