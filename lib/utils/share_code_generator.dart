import 'dart:math';

class ShareCodeGenerator {
  static const String _chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static final Random _random = Random();

  /// Generates a unique 6-character alphanumeric share code
  /// Excludes confusing characters like 0, O, 1, I
  static String generate() {
    return List.generate(6, (_) => _chars[_random.nextInt(_chars.length)])
        .join();
  }
}
