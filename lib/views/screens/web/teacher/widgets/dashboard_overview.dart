import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:sumquiz/models/public_deck.dart';
import 'package:sumquiz/models/teacher_models.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/theme/web_theme.dart';

class DashboardOverview extends StatelessWidget {
  final TeacherStats? stats;
  final List<ActivityItem> activity;
  final List<PublicDeck> content;
  final Map<String, ContentAnalytics> analytics;

  const DashboardOverview({
    super.key,
    required this.stats,
    required this.activity,
    required this.content,
    required this.analytics,
  });

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel?>(context);
    final name = user?.displayName.split(' ').first ?? 'Educator';
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hello, Dr. $name',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF1F1F1F),
              letterSpacing: -0.5,
            ),
          ).animate().fadeIn().slideY(begin: 0.1),
          const SizedBox(height: 8),
          Text(
            'Keep building momentum. Knowledge is flowing.',
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: const Color(0xFF6B7280),
              fontWeight: FontWeight.w400,
            ),
          ).animate().fadeIn().slideY(begin: 0.1, delay: 50.ms),
          
          const SizedBox(height: 16),
          
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 5,
                  child: _buildEngagementOverview(),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      Expanded(child: _buildActiveStudentsCard()),
                      const SizedBox(height: 16),
                      Expanded(child: _buildContentRatingCard()),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn().slideY(begin: 0.1, delay: 100.ms),

          const SizedBox(height: 12),
          
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _buildClassroomCodes()),
              const SizedBox(width: 16),
              Expanded(flex: 4, child: _buildStudentSentiment()),
            ],
          ).animate().fadeIn().slideY(begin: 0.1, delay: 150.ms),

          const SizedBox(height: 16),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Active Content Decks',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1F1F1F),
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('View all decks', style: TextStyle(color: WebColors.purplePrimary, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildActiveDecksTable(),
        ],
      ),
    );
  }

  Widget _buildEngagementOverview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: WebColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text('Engagement Overview', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800)),
                   const SizedBox(height: 4),
                   Text('Quiz performance trends', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
              Container(
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
                      child: Text('WEEKLY', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text('MONTHLY', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _barChartColumn('MON', 40, 30),
                _barChartColumn('TUE', 55, 45),
                _barChartColumn('WED', 80, 60),
                _barChartColumn('THU', 100, 90),
                _barChartColumn('FRI', 65, 50),
                _barChartColumn('SAT', 35, 20),
                _barChartColumn('SUN', 25, 15),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text('Started', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(width: 24),
              Container(width: 10, height: 10, decoration: BoxDecoration(color: WebColors.purplePrimary, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text('Completed', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          )
        ],
      ),
    );
  }

  Widget _barChartColumn(String day, double height1, double height2) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 32,
          height: height1 * 1.2,
          decoration: BoxDecoration(
            color: const Color(0xFFE5E7EB),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.bottomCenter,
          child: Container(
            width: 32,
            height: height2 * 1.2,
            decoration: BoxDecoration(
              color: WebColors.purplePrimary,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(day, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildActiveStudentsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: WebColors.purplePrimary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('ACTIVE STUDENTS', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 1)),
          const SizedBox(height: 12),
          Text('${stats?.activeStudents ?? 0}', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 12),
          Text('+${activity.where((e) => e.type == "attempt").length} students joined recently', style: GoogleFonts.outfit(fontSize: 12, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildContentRatingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: WebColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('CONTENT RATING', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 1)),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(((stats?.averageScore ?? 0) / 20).clamp(0.0, 5.0).toStringAsFixed(1), style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: const Color(0xFF1F1F1F))),
              const SizedBox(width: 12),
              Row(
                children: List.generate(5, (index) => const Icon(Icons.star, color: WebColors.purplePrimary, size: 20)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Based on ${stats?.totalAttempts ?? 0} student evaluations this semester.', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600], height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildClassroomCodes() {
    final publicPacks = content.take(2).toList();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: WebColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Classroom Codes', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800)),
              const Icon(Icons.qr_code_2, color: WebColors.purplePrimary),
            ],
          ),
          const SizedBox(height: 16),
          if (publicPacks.isEmpty)
            Text('No public packs available.', style: TextStyle(color: Colors.grey[500]))
          else
            ...publicPacks.map((pack) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pack.title.toUpperCase(), style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                        const SizedBox(height: 4),
                        Text(pack.shareCode, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: WebColors.purplePrimary, letterSpacing: 2)),
                      ],
                    ),
                    Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.copy, size: 16)),
                  ],
                ),
              ),
            )),
        ],
      ),
    );
  }

  Widget _buildStudentSentiment() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: WebColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
               Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFF3E8FF), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.psychology, color: WebColors.purplePrimary, size: 24)),
               const SizedBox(width: 16),
               Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text('Student Sentiment', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800)),
                   Text('Real-time feedback analysis', style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[600])),
                 ],
               ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _sentimentProgress('Clarity of Content', 0.94),
                    const SizedBox(height: 12),
                    _sentimentProgress('Difficulty Balance', 0.82),
                  ],
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('"The AI-generated insights on the Molecular Deck were incredibly helpful for my exam prep last night."', style: GoogleFonts.outfit(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.grey[700], height: 1.5)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const CircleAvatar(radius: 12, backgroundColor: Colors.teal),
                          const SizedBox(width: 8),
                          Text('Student #A203', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _sentimentProgress(String label, double val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700)),
            Text('${(val*100).toInt()}%', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: WebColors.purplePrimary)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: val,
            backgroundColor: const Color(0xFFE5E7EB),
            valueColor: const AlwaysStoppedAnimation(WebColors.purplePrimary),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildActiveDecksTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: WebColors.cardShadow,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('DECK NAME', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 1))),
                Expanded(flex: 1, child: Text('STATUS', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 1))),
                Expanded(flex: 2, child: Text('COMPLETION RATE', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 1))),
                const Expanded(flex: 1, child: Align(alignment: Alignment.centerRight, child: Text('ACTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.transparent)))),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          if (content.isEmpty)
             const Padding(padding: EdgeInsets.all(32), child: Text("No content yet.", style: TextStyle(color: Colors.grey)))
          else 
            ...content.take(4).map((deck) => _buildDeckRow(deck)),
        ],
      ),
    );
  }

  Widget _buildDeckRow(PublicDeck deck) {
    final a = analytics[deck.id];
    final completionRate = a?.engagementRate ?? 0;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFF3E8FF), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.science_outlined, color: WebColors.purplePrimary, size: 18),
                ),
                const SizedBox(width: 16),
                Expanded(child: Text(deck.title, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF1F1F1F)), overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(20)),
                child: Text('LIVE', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF166534))),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Text('${completionRate.toStringAsFixed(0)}%', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(width: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: completionRate / 100,
                      backgroundColor: const Color(0xFFE5E7EB),
                      valueColor: const AlwaysStoppedAnimation(WebColors.purplePrimary),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 24),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.centerRight,
              child: IconButton(icon: const Icon(Icons.more_vert, color: Colors.grey), onPressed: () {}),
            ),
          ),
        ],
      ),
    );
  }
}
