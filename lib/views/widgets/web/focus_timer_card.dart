import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Focus Session Complete!',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text('Great job staying focused! Take a short break.',
            style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Dismiss',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary)),
          ),
        ],
      ),
    );
  }

  void _showSettings() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) {
        int selectedMinutes = (_currentGoalSeconds / 60).round();
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              title: Text('Timer Settings',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Set your focus duration:', style: GoogleFonts.inter()),
                  const SizedBox(height: 24),
                  Slider(
                    value: selectedMinutes.toDouble(),
                    min: 5,
                    max: 60,
                    divisions: 11,
                    activeColor: theme.colorScheme.primary,
                    label: '$selectedMinutes min',
                    onChanged: (val) {
                      setDialogState(() => selectedMinutes = val.round());
                    },
                  ),
                  Text('$selectedMinutes minutes',
                      style: GoogleFonts.jetBrainsMono(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary)),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel',
                      style: GoogleFonts.inter(color: theme.hintColor)),
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
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: Text('Apply',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
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
  String get _secondsStr => (_secondsRemaining % 60).toString().padLeft(2, '0');

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.timer_outlined,
                      size: 14, color: Color(0xFF0D9488)),
                  const SizedBox(width: 8),
                  Text(
                    'FOCUS TIMER',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: theme.hintColor,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: _showSettings,
                icon: Icon(Icons.tune_rounded,
                    size: 18, color: theme.hintColor.withOpacity(0.5)),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            '$_minutesStr:$_secondsStr',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.displayLarge?.color,
              height: 1.0,
            ),
          ).animate(target: _isRunning ? 1 : 0).shimmer(
              duration: 2.seconds,
              color: theme.colorScheme.primary.withOpacity(0.2)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0D9488).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'POMODORO ACTIVE',
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0D9488),
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _toggleTimer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRunning
                        ? theme.dividerColor.withOpacity(0.1)
                        : theme.colorScheme.primary,
                    foregroundColor:
                        _isRunning ? theme.hintColor : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    _isRunning ? 'Pause' : 'Start',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _resetTimer,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.hintColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side:
                        BorderSide(color: theme.dividerColor.withOpacity(0.1)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    'Reset',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.05, end: 0);
  }
}
