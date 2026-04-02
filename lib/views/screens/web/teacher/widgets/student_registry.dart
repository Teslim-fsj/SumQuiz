import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sumquiz/models/teacher_models.dart';
import 'package:sumquiz/theme/web_theme.dart';
import 'shared_teacher_widgets.dart';

class StudentRegistry extends StatefulWidget {
  final List<StudentLink> students;
  final VoidCallback onInviteStudent;

  const StudentRegistry({
    super.key,
    required this.students,
    required this.onInviteStudent,
  });

  @override
  State<StudentRegistry> createState() => _StudentRegistryState();
}

class _StudentRegistryState extends State<StudentRegistry> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filteredStudents = widget.students.where((s) =>
        s.studentName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        s.studentEmail.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SharedTeacherWidgets.moduleHeader('Students',
                    'Registry of all students engaging with your content'),
              ),
              _buildSearchBar(),
              const SizedBox(width: 24),
              ElevatedButton.icon(
                onPressed: widget.onInviteStudent,
                icon: const Icon(Icons.person_add_outlined, size: 18),
                label: const Text('Invite Student'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: WebColors.purplePrimary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          if (filteredStudents.isEmpty)
            SharedTeacherWidgets.emptyCard(
                _searchQuery.isEmpty ? 'No students yet' : 'No students found',
                _searchQuery.isEmpty 
                  ? 'Share your content with students to see them here.'
                  : 'Try adjusting your search query.')
          else
            _buildStudentTable(filteredStudents),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      width: 300,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WebColors.border),
      ),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Search students...',
          hintStyle: GoogleFonts.outfit(fontSize: 14, color: WebColors.textTertiary),
          prefixIcon: const Icon(Icons.search, size: 20, color: WebColors.textTertiary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildStudentTable(List<StudentLink> students) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WebColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: WebColors.backgroundAlt,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                _tableHeader('Student', flex: 3),
                _tableHeader('Last Active', flex: 2),
                _tableHeader('Attempts'),
                _tableHeader('Avg Score'),
                _tableHeader('Completion'),
              ],
            ),
          ),
          // Rows
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: students.length,
            itemBuilder: (context, index) => _studentRow(students[index]),
          ),
        ],
      ),
    );
  }

  Widget _tableHeader(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(text,
          style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: WebColors.textSecondary,
              letterSpacing: 0.5)),
    );
  }

  Widget _studentRow(StudentLink s) {
    final isActive = s.lastActiveAt != null &&
        s.lastActiveAt!.isAfter(DateTime.now().subtract(const Duration(days: 7)));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: WebColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor:
                      WebColors.purplePrimary.withValues(alpha: 0.1),
                  child: Text(
                    s.studentName.isNotEmpty ? s.studentName[0].toUpperCase() : '?',
                    style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: WebColors.purplePrimary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.studentName,
                          style: GoogleFonts.outfit(
                              fontSize: 13, fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis),
                      if (s.studentEmail.isNotEmpty)
                        Text(s.studentEmail,
                            style: GoogleFonts.outfit(
                                fontSize: 11, color: WebColors.textTertiary),
                            overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive ? WebColors.success : WebColors.border,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  s.lastActiveAt != null
                      ? SharedTeacherWidgets.relativeTime(s.lastActiveAt!)
                      : 'Never',
                  style: GoogleFonts.outfit(
                      fontSize: 12, color: WebColors.textSecondary),
                ),
              ],
            ),
          ),
          Expanded(
              child: Text('${s.totalAttempts}',
                  style: GoogleFonts.outfit(
                      fontSize: 13, fontWeight: FontWeight.w700))),
          Expanded(
            child: SharedTeacherWidgets.scoreChip(s.averageScore),
          ),
          Expanded(
            child: _progressBar(s.completionRate / 100),
          ),
        ],
      ),
    );
  }

  Widget _progressBar(double value) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: WebColors.backgroundAlt,
              valueColor: AlwaysStoppedAnimation(WebColors.blueInfo),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('${(value * 100).toStringAsFixed(0)}%',
            style: GoogleFonts.outfit(
                fontSize: 11, color: WebColors.textSecondary)),
      ],
    );
  }
}
