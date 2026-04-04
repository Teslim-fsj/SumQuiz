import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WebExamConfigStep extends StatelessWidget {
  final int numberOfQuestions;
  final ValueChanged<double> onQuestionsChanged;
  
  final int easyCount;
  final int mediumCount;
  final int hardCount;
  final ValueChanged<double> onEasyChanged;
  final ValueChanged<double> onHardChanged;
  
  final bool includeMultipleChoice;
  final bool includeTrueFalse;
  final bool includeTheory;
  final bool includeFillInBlank;
  final Function(String, bool) onTypeToggled;
  
  final bool evenTopicCoverage;
  final bool focusWeakAreas;
  final Function(String, bool) onRuleToggled;
  
  final VoidCallback onFinalize;
  final bool isGenerating;

  const WebExamConfigStep({
    super.key,
    required this.numberOfQuestions,
    required this.onQuestionsChanged,
    required this.easyCount,
    required this.mediumCount,
    required this.hardCount,
    required this.onEasyChanged,
    required this.onHardChanged,
    required this.includeMultipleChoice,
    required this.includeTrueFalse,
    required this.includeTheory,
    required this.includeFillInBlank,
    required this.onTypeToggled,
    required this.evenTopicCoverage,
    required this.focusWeakAreas,
    required this.onRuleToggled,
    required this.onFinalize,
    this.isGenerating = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Advanced Exam Configuration',
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Fine-tune the intelligence engine. Define your constraints, question variety,\nand difficulty distribution for the Final Architecture exam.',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  color: const Color(0xFF475569),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 48),
              
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        _buildTotalQuestionsCard(context),
                        const SizedBox(height: 24),
                        _buildTypesCard(context),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 4,
                    child: Column(
                      children: [
                        _buildDifficultyCard(context),
                        const SizedBox(height: 24),
                        _buildRulesCard(context),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 120), // Bottom padding for floating bar
            ],
          ),
          
          // Floating Action Bar
          Container(
            height: 90,
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(45),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Stack(
                        children: [
                          _buildAvatar(0, 'assets/images/avatar_placeholder.png'),
                          Positioned(left: 20, child: _buildAvatar(1, 'assets/images/avatar_placeholder.png')),
                          Positioned(
                            left: 40,
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: const Color(0xFFE2E8F0),
                              child: Text('+12', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF475569))),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: '14 Educators ', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
                          TextSpan(text: 'recently used these settings for similar courses.', style: GoogleFonts.outfit(color: const Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: isGenerating ? null : onFinalize,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  ),
                  child: Row(
                    children: [
                      Text(
                        isGenerating ? 'GENERATING...' : 'Generate Draft Exam',
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 12),
                      if (isGenerating)
                        const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      else
                        const Icon(Icons.auto_awesome, size: 20),
                    ],
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
  
  Widget _buildAvatar(int index, String asset) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: CircleAvatar(radius: 16, child: Icon(Icons.person, size: 20, color: Colors.white), backgroundColor: Colors.grey),
    );
  }

  Widget _buildTotalQuestionsCard(BuildContext context) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTAL QUESTION COUNT',
                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: const Color(0xFF475569)),
              ),
              const Icon(Icons.numbers_rounded, color: Color(0xFFE2E8F0), size: 32),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                width: 120,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    numberOfQuestions.toString(),
                    style: GoogleFonts.outfit(fontSize: 48, fontWeight: FontWeight.w900, color: const Color(0xFF4F46E5)),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Recommended: 40 - 60', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF1E293B))),
                    const SizedBox(height: 4),
                    Text('Optimal for a 2-hour session.', style: GoogleFonts.outfit(color: const Color(0xFF64748B))),
                    const SizedBox(height: 16),
                    SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: const Color(0xFF4F46E5),
                        inactiveTrackColor: const Color(0xFFE2E8F0),
                        thumbColor: const Color(0xFF4F46E5),
                        trackHeight: 4,
                      ),
                      child: Slider(
                        value: numberOfQuestions.toDouble(),
                        min: 5,
                        max: 100,
                        onChanged: onQuestionsChanged,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildTypesCard(BuildContext context) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'QUESTION TYPE DISTRIBUTION',
            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: const Color(0xFF475569)),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildTypeToggle('Multiple Choice', 'Standard 4-option items', includeMultipleChoice, (v) => onTypeToggled('mcq', v)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTypeToggle('True/False', 'Binary validation logic', includeTrueFalse, (v) => onTypeToggled('tf', v)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTypeToggle('Theory/Essay', 'Deep conceptual responses', includeTheory, (v) => onTypeToggled('theory', v)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTypeToggle('Fill-in-the-Blank', 'Vocabulary & recall', includeFillInBlank, (v) => onTypeToggled('fib', v)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeToggle(String title, String subtitle, bool isSelected, Function(bool) onChanged) {
    return InkWell(
      onTap: () => onChanged(!isSelected),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF8FAFC) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF4F46E5) : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFCBD5E1),
                ),
              ),
              child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
                  const SizedBox(height: 4),
                  Text(subtitle, style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF64748B))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyCard(BuildContext context) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DIFFICULTY MIX ENGINE',
            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: const Color(0xFF475569)),
          ),
          const SizedBox(height: 24),
          // Simple visual representation using sliders - in a real app this would be a custom multi-thumb slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBadge('Mix Proportion', const Color(0xFFF1F5F9), const Color(0xFF1E293B)),
              _buildBadge('${(easyCount/numberOfQuestions*100).round()}% EASY', const Color(0xFFDCFCE7), const Color(0xFF166534)),
              _buildBadge('${(mediumCount/numberOfQuestions*100).round()}% MEDIUM', const Color(0xFFEEF2FF), const Color(0xFF4F46E5)),
              _buildBadge('${(hardCount/numberOfQuestions*100).round()}% HARD', const Color(0xFFFFE4E6), const Color(0xFFBE123C)),
            ],
          ),
          const SizedBox(height: 24),
          
          Text('Easy Ratio', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
          SliderTheme(
            data: SliderThemeData(activeTrackColor: const Color(0xFF22C55E), thumbColor: const Color(0xFF22C55E)),
            child: Slider(value: easyCount / numberOfQuestions, min: 0, max: 1, onChanged: onEasyChanged),
          ),
          
          Text('Hard Ratio', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
          SliderTheme(
            data: SliderThemeData(activeTrackColor: const Color(0xFFE11D48), thumbColor: const Color(0xFFE11D48)),
            child: Slider(value: hardCount / numberOfQuestions, min: 0, max: 1, onChanged: onHardChanged),
          ),

          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _buildStatColumn('EASY', easyCount.toString())),
              Expanded(child: _buildStatColumn('MEDIUM', mediumCount.toString())),
              Expanded(child: _buildStatColumn('HARD', hardCount.toString())),
            ],
          )
        ],
      ),
    );
  }
  
  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1, color: const Color(0xFF64748B))),
        const SizedBox(height: 8),
        Text(value, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: const Color(0xFF1E293B))),
      ],
    );
  }

  Widget _buildRulesCard(BuildContext context) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TOPIC COVERAGE RULES',
            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: const Color(0xFF475569)),
          ),
          const SizedBox(height: 24),
          _buildRuleToggle('Even Coverage', 'Spread questions across all units', Icons.balance_rounded, evenTopicCoverage, (v) => onRuleToggled('even', v)),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          _buildRuleToggle('Focus Weak Areas', 'Prioritize topics with low class average', Icons.psychology_rounded, focusWeakAreas, (v) => onRuleToggled('weak', v)),
        ],
      ),
    );
  }

  Widget _buildRuleToggle(String title, String subtitle, IconData icon, bool isOn, Function(bool) onChanged) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isOn ? const Color(0xFFEEF2FF) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: isOn ? const Color(0xFF4F46E5) : const Color(0xFF64748B)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
              Text(subtitle, style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B))),
            ],
          ),
        ),
        Switch(
          value: isOn,
          onChanged: onChanged,
          activeColor: Colors.white,
          activeTrackColor: const Color(0xFF4F46E5),
          inactiveTrackColor: const Color(0xFFCBD5E1),
          inactiveThumbColor: Colors.white,
        ),
      ],
    );
  }

  Widget _buildCard({required Widget child}) {
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
      padding: const EdgeInsets.all(32),
      child: child,
    );
  }

  Widget _buildBadge(String text, Color bg, Color textC) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: textC)),
    );
  }
}
