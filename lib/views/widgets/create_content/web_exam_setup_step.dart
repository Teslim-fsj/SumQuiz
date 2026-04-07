import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WebExamSetupStep extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController subjectController;
  final TextEditingController schoolNameController;
  final TextEditingController durationController;
  final String selectedLevel;
  final ValueChanged<String?> onLevelChanged;
  final VoidCallback onPickSourcePdf;
  final VoidCallback onPickSourceNotes;
  final VoidCallback onNext;
  final bool hasSource;
  final String uploadStatusMessage;

  const WebExamSetupStep({
    super.key,
    required this.titleController,
    required this.subjectController,
    required this.schoolNameController,
    required this.durationController,
    required this.selectedLevel,
    required this.onLevelChanged,
    required this.onPickSourcePdf,
    required this.onPickSourceNotes,
    required this.onNext,
    this.hasSource = false,
    this.uploadStatusMessage = '',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Step 1: Source & Subject Grounding',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Define the intellectual boundaries of your exam. Upload your course materials and\nestablish the academic context to ensure AI-generated questions align with your curriculum.',
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: const Color(0xFF475569),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildSourceMaterial(context)),
              const SizedBox(width: 16),
              Expanded(child: _buildAcademicContext(context)),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 240,
              height: 48,
              child: ElevatedButton(
                onPressed: hasSource && titleController.text.isNotEmpty && subjectController.text.isNotEmpty ? onNext : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                  elevation: 8,
                  shadowColor: const Color(0xFF4F46E5).withValues(alpha: 0.4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Continue to Configuration',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 48.0),
              child: Text(
                'EST. TIME: 2 MINS TO COMPLETE SETUP',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceMaterial(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 4),
          )
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.cloud_upload_rounded, color: Color(0xFF4F46E5), size: 18),
              ),
              const SizedBox(width: 16),
              Text(
                'Source Material',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: InkWell(
              onTap: onPickSourcePdf,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: hasSource ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                  border: Border.all(
                    color: hasSource ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        hasSource ? Icons.check_circle_rounded : Icons.upload_file_rounded,
                        size: 24,
                        color: hasSource ? const Color(0xFF22C55E) : const Color(0xFF4F46E5),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      hasSource ? 'Source Material Processed' : 'Syllabus, Textbooks, or PDF',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      hasSource ? uploadStatusMessage : 'Drag and drop your course materials here or\nclick to browse files. Supports .pdf, .docx, .txt',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF64748B),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildBadge(Icons.lock_rounded, '256-bit Encrypted'),
                        const SizedBox(width: 16),
                        _buildBadge(Icons.auto_awesome_rounded, 'AI-Ready Parsing'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (!hasSource) ...[
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                onPressed: onPickSourceNotes,
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text('Or paste raw text notes instead'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF4F46E5),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF475569)),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcademicContext(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.tune_rounded, color: Color(0xFF1E293B), size: 18),
              ),
              const SizedBox(width: 16),
              Text(
                'Academic Context',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInputGroup('EXAM TITLE', titleController, 'e.g., Midterm: Cellular Biology'),
          const SizedBox(height: 12),
          _buildInputGroup('SCHOOL / INSTITUTION', schoolNameController, 'e.g., SumQuiz Academy', prefixIcon: Icons.account_balance_rounded),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildInputGroup('SUBJECT/DOMAIN', subjectController, 'e.g., Biology', prefixIcon: Icons.school_rounded)),
              const SizedBox(width: 12),
              Expanded(child: _buildInputGroup('DURATION (MINS)', durationController, 'e.g., 60', prefixIcon: Icons.timer_rounded)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'ACADEMIC LEVEL',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedLevel,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF94A3B8)),
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  color: const Color(0xFF1E293B),
                  fontWeight: FontWeight.w500,
                ),
                items: [
                  'Primary / Elementary',
                  'Middle School',
                  'High School / Secondary',
                  'Vocational / Technical',
                  'Undergraduate (University)',
                  'Postgraduate (Masters/PhD)',
                  'Professional Certification',
                  'Corporate Training'
                ].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Row(
                      children: [
                        const Icon(Icons.layers_rounded, size: 20, color: Color(0xFF64748B)),
                        const SizedBox(width: 12),
                        Text(value),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: onLevelChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputGroup(String label, TextEditingController controller, String hint, {IconData? prefixIcon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: const Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: TextField(
            controller: controller,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: const Color(0xFF1E293B),
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.outfit(
                color: const Color(0xFFCBD5E1),
              ),
              prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: const Color(0xFF94A3B8)) : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}
