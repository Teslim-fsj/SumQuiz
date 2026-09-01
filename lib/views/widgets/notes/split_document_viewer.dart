import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SplitDocumentViewer extends StatefulWidget {
  final String documentName;
  final Widget child;

  const SplitDocumentViewer({
    super.key,
    this.documentName = 'Cellular Biology - Chapter 4.pdf',
    required this.child,
  });

  @override
  State<SplitDocumentViewer> createState() => _SplitDocumentViewerState();
}

class _SplitDocumentViewerState extends State<SplitDocumentViewer> {
  int _zoomPercentage = 125;
  bool _isHighlighterActive = true;
  double _splitRatio = 0.42; // Upper pane ratio

  void _zoomIn() {
    setState(() {
      _zoomPercentage = (_zoomPercentage + 15).clamp(75, 250);
    });
  }

  void _zoomOut() {
    setState(() {
      _zoomPercentage = (_zoomPercentage - 15).clamp(75, 250);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalHeight = constraints.maxHeight;
        final upperHeight = (totalHeight * _splitRatio).clamp(140.0, totalHeight - 160.0);

        return Column(
          children: [
            // Upper Document Pane
            SizedBox(
              height: upperHeight,
              child: Column(
                children: [
                  // Document Viewer Toolbar
                  _buildDocumentToolbar(isDark),
                  // Document Content Page
                  Expanded(
                    child: _buildDocumentContent(isDark),
                  ),
                ],
              ),
            ),

            // Draggable Splitter Handle
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onVerticalDragUpdate: (details) {
                setState(() {
                  _splitRatio = (_splitRatio + (details.delta.dy / totalHeight)).clamp(0.2, 0.75);
                });
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  border: Border.symmetric(
                    horizontal: BorderSide(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),

            // Lower Note Editor Pane
            Expanded(
              child: widget.child,
            ),
          ],
        );
      },
    );
  }

  Widget _buildDocumentToolbar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9),
          ),
        ),
      ),
      child: Row(
        children: [
          // Document Name Pill
          Flexible(
            child: Text(
              widget.documentName,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Zoom & Search Controls
          IconButton(
            icon: const Icon(Icons.search_rounded, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            onPressed: () {},
          ),
          const SizedBox(width: 4),
          Text(
            '$_zoomPercentage%',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out_rounded, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            onPressed: _zoomOut,
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in_rounded, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            onPressed: _zoomIn,
          ),

          Container(
            height: 16,
            width: 1,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: isDark ? Colors.white24 : const Color(0xFFE2E8F0),
          ),

          // Highlighter Tool (Purple Pill)
          InkWell(
            onTap: () => setState(() => _isHighlighterActive = !_isHighlighterActive),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: _isHighlighterActive
                    ? const Color(0xFF6B5CE7).withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.border_color_rounded,
                size: 16,
                color: _isHighlighterActive ? const Color(0xFF6B5CE7) : (isDark ? Colors.white70 : const Color(0xFF64748B)),
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Pencil / Draw Tool
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentContent(bool isDark) {
    return Container(
      width: double.infinity,
      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '4.2 Mitochondria\nStructure and Function',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Mitochondria are often referred to as the powerhouses of the cell. They generate most of the cell\'s supply of adenosine triphosphate (ATP), used as a source of chemical energy. A mitochondrion contains outer and inner membranes composed of phospholipid bilayers and proteins.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.6,
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
