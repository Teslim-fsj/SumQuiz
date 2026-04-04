import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:sumquiz/models/teacher_models.dart';
import 'package:sumquiz/theme/web_theme.dart';

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
    final filtered = widget.students.where((s) {
      return s.studentName.toLowerCase().contains(_searchQuery.toLowerCase()) || 
             s.studentEmail.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Student Roster', style: GoogleFonts.outfit(fontSize: 42, fontWeight: FontWeight.w900, color: const Color(0xFF1F1F1F), letterSpacing: -1)),
                  const SizedBox(height: 8),
                  Text('Overview of all active students and their engagement trends.', style: GoogleFonts.outfit(fontSize: 18, color: const Color(0xFF6B7280))),
                ],
              ),
              Row(
                children: [
                  _buildSearchBar(),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(border: Border.all(color: WebColors.border), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        const Icon(Icons.filter_list, size: 18),
                        const SizedBox(width: 8),
                        Text('Classes', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: WebColors.border), shape: BoxShape.circle), child: const Icon(Icons.sort, size: 18)),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: widget.onInviteStudent,
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text('Add Student'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: WebColors.purplePrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  )
                ],
              )
            ],
          ),
          const SizedBox(height: 40),
          _buildTable(filtered),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      width: 250,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WebColors.border),
      ),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Search student...',
          hintStyle: GoogleFonts.outfit(fontSize: 14, color: WebColors.textTertiary),
          prefixIcon: const Icon(Icons.search, size: 18, color: WebColors.textTertiary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildTable(List<StudentLink> students) {
    if (students.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: WebColors.border)),
        child: const Center(child: Text('No students found.')),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: WebColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              color: const Color(0xFFF9FAFB),
              child: Row(
                children: [
                   Expanded(flex: 3, child: Text('STUDENT NAME', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 1))),
                   Expanded(flex: 2, child: Text('CLASS', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 1))),
                   Expanded(flex: 2, child: Text('LAST ACTIVE', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 1))),
                   Expanded(flex: 2, child: Text('AVERAGE', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 1))),
                   Expanded(flex: 2, child: Text('ACTIVITY', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 1))),
                   const SizedBox(width: 40),
                ],
              ),
            ),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: students.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
              itemBuilder: (context, i) {
                final student = students[i];
                return _buildTableRow(student, i);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableRow(StudentLink student, int index) {
    final isActive = student.lastActiveAt != null &&
        student.lastActiveAt!.isAfter(DateTime.now().subtract(const Duration(days: 7)));

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFF3E8FF),
                  child: Text(
                    student.studentName.isNotEmpty ? student.studentName[0].toUpperCase() : '?',
                    style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: WebColors.purplePrimary),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(student.studentName, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF1F1F1F))),
                    if (student.studentEmail.isNotEmpty)
                      Text(student.studentEmail, style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey[500])),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
                child: Text('Default Class', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[800])),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              student.lastActiveAt != null ? DateFormat.MMMEd().format(student.lastActiveAt!) : 'Never',
              style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[700]),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Text('${student.averageScore.toStringAsFixed(1)}%', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF1F1F1F))),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: student.averageScore / 100,
                      backgroundColor: const Color(0xFFF3F4F6),
                      valueColor: const AlwaysStoppedAnimation(WebColors.purplePrimary),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
                child: Text(isActive ? 'Active Learner' : 'Inactive', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: isActive ? const Color(0xFF166534) : Colors.grey[600])),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz, color: Colors.grey),
            onPressed: () {},
          )
        ],
      ),
    );
  }
}
