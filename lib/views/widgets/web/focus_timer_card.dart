import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sumquiz/theme/web_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';

class FocusTimerCard extends StatefulWidget {
  const FocusTimerCard({super.key});

  @override
  State<FocusTimerCard> createState() => _FocusTimerCardState();
}

class _FocusTimerCardState extends State<FocusTimerCard> {
  int _secondsRemaining = 25 * 60;
  int _currentGoalSeconds = 25 * 60;
  Timer? _timer;
  bool _isRunning = false;

  void _toggleTimer() {
    if (_isRunning) {
      _stopTimer();
    } else {
      _startTimer();
    }
  }

  void _startTimer() {
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _stopTimer();
        if (mounted) _showCompletion();
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _resetTimer() {
    _stopTimer();
    setState(() => _secondsRemaining = _currentGoalSeconds);
  }

  void _showCompletion() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Focus Session Complete!',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text('Great job staying focused! Take a short break.',
            style: GoogleFonts.outfit()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) {
        int selectedMinutes = (_currentGoalSeconds / 60).round();
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Timer Settings',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Set your focus duration:',
                      style: GoogleFonts.outfit()),
                  const SizedBox(height: 20),
                  Slider(
                    value: selectedMinutes.toDouble(),
                    min: 5,
                    max: 60,
                    divisions: 11,
                    activeColor: WebColors.purplePrimary,
                    label: '$selectedMinutes min',
                    onChanged: (val) {
                      setDialogState(() => selectedMinutes = val.round());
                    },
                  ),
                  Text('$selectedMinutes minutes',
                      style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600,
                          color: WebColors.purplePrimary)),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _currentGoalSeconds = selectedMinutes * 60;
                      _secondsRemaining = _currentGoalSeconds;
                      _stopTimer();
                    });
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: WebColors.purplePrimary,
                      foregroundColor: Colors.white),
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String get _minutesStr =>
      (_secondsRemaining / 60).floor().toString().padLeft(2, '0');
  String get _secondsStr =>
      (_secondsRemaining % 60).toString().padLeft(2, '0');

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WebColors.border),
        boxShadow: WebColors.subtleShadow,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'FOCUS TIMER',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: WebColors.textSecondary,
                  letterSpacing: 1.5,
                ),
              ),
              InkWell(
                onTap: _showSettings,
                child: const Icon(Icons.settings_rounded,
                    size: 20, color: WebColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            '$_minutesStr:$_secondsStr',
            style: GoogleFonts.outfit(
              fontSize: 48,
              fontWeight: FontWeight.w800,
              color: WebColors.textPrimary,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'POMODORO PHASE',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: WebColors.purplePrimary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _toggleTimer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: WebColors.purplePrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _isRunning ? 'Pause' : 'Start',
                    style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _resetTimer,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: WebColors.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: WebColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Reset',
                    style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.05);
  }
}
