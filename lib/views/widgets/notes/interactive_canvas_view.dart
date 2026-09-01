import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

class InteractiveCanvasView extends StatefulWidget {
  final VoidCallback onSynthesize;
  final bool isSynthesizing;

  const InteractiveCanvasView({
    super.key,
    required this.onSynthesize,
    this.isSynthesizing = false,
  });

  @override
  State<InteractiveCanvasView> createState() => _InteractiveCanvasViewState();
}

class _InteractiveCanvasViewState extends State<InteractiveCanvasView> {
  bool _isPlayingAudio = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // Canvas Workspace with Reorderable/Modular Cards
        Positioned.fill(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Cellular Respiration Text Block
                _buildTextBlock(isDark),
                const SizedBox(height: 18),

                // 2. Lecture Audio Player Block
                _buildAudioPlayerBlock(isDark),
                const SizedBox(height: 24),

                // 3. Diagram / Visual Block
                _buildDiagramBlock(isDark),
                const SizedBox(height: 90), // Spacing for bottom floating button
              ],
            ),
          ),
        ),

        // Floating Bottom Action Capsule ("Synthesize Canvas")
        Positioned(
          left: 0,
          right: 0,
          bottom: 24,
          child: Center(
            child: _buildSynthesizeButton(isDark),
          ),
        ),
      ],
    );
  }

  Widget _buildAudioPlayerBlock(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Drag dots + Title + Duration
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.drag_indicator_rounded,
                    size: 18,
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Lecture Audio',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Text(
                '2:14',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Player Controls + Waveform
          Row(
            children: [
              // Play/Pause Button
              Material(
                color: const Color(0xFF6B5CE7),
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: () => setState(() => _isPlayingAudio = !_isPlayingAudio),
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    child: Icon(
                      _isPlayingAudio ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Audio Waveform Bars
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _waveformBar(14, isActive: true),
                    _waveformBar(20, isActive: true),
                    _waveformBar(32, isActive: true),
                    _waveformBar(18, isActive: true),
                    _waveformBar(26, isActive: true),
                    _waveformBar(12, isActive: false),
                    _waveformBar(16, isActive: false),
                    _waveformBar(10, isActive: false),
                    _waveformBar(14, isActive: false),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _waveformBar(double height, {required bool isActive}) {
    return Container(
      width: 4,
      height: height,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF6B5CE7) : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _buildTextBlock(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.drag_indicator_rounded,
                size: 18,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 8),
              Text(
                'Cellular Respiration',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'The process by which cells derive energy from glucose. It involves glycolysis, the Krebs cycle, and the electron transport chain...',
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.6,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagramBlock(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.drag_indicator_rounded,
                size: 18,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 8),
              Text(
                'Mitochondria Diagram',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Clean SVG/Custom Diagram Illustration Container
          Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(260, 140),
                  painter: _MitochondriaPainter(isDark: isDark),
                ),
                Positioned(
                  top: 14,
                  right: 18,
                  child: Text(
                    'Inter-membrane space\nCristae\nMatrix',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSynthesizeButton(bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.isSynthesizing ? null : widget.onSynthesize,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: const Color(0xFF6B5CE7).withValues(alpha: 0.25),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6B5CE7).withValues(alpha: 0.15),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.smart_toy_rounded,
                  color: Color(0xFF3B82F6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Synthesize\nCanvas',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFF6B5CE7),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    ).animate(target: widget.isSynthesizing ? 1 : 0).shimmer(duration: 1.seconds);
  }
}

class _MitochondriaPainter extends CustomPainter {
  final bool isDark;
  _MitochondriaPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final outerPaint = Paint()
      ..color = const Color(0xFF6B5CE7).withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final innerPaint = Paint()
      ..color = const Color(0xFF818CF8).withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final fillPaint = Paint()
      ..color = const Color(0xFF6B5CE7).withValues(alpha: isDark ? 0.1 : 0.05)
      ..style = PaintingStyle.fill;

    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(size.width * 0.45, size.height * 0.5), width: 180, height: 90),
      const Radius.circular(45),
    );

    canvas.drawRRect(rect, fillPaint);
    canvas.drawRRect(rect, outerPaint);

    // Inner cristae folds
    final path = Path();
    path.moveTo(size.width * 0.22, size.height * 0.5);
    path.quadraticBezierTo(size.width * 0.28, size.height * 0.3, size.width * 0.35, size.height * 0.5);
    path.quadraticBezierTo(size.width * 0.42, size.height * 0.7, size.width * 0.48, size.height * 0.5);
    path.quadraticBezierTo(size.width * 0.55, size.height * 0.3, size.width * 0.62, size.height * 0.5);
    path.quadraticBezierTo(size.width * 0.68, size.height * 0.7, size.width * 0.72, size.height * 0.5);

    canvas.drawPath(path, innerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
