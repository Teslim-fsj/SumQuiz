import 'dart:io';

void main() {
  final file = File('lib/views/screens/review_screen.dart');
  final lines = file.readAsLinesSync();
  int depth = 0;
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    for (int j = 0; j < line.length; j++) {
      if (line[j] == '{') depth++;
      if (line[j] == '}') {
        depth--;
        if (depth < 0) {
          print('Extra closing brace at line ${i + 1}');
          return;
        }
      }
    }
  }
  print('Final depth: $depth');
  if (depth > 0) {
    print('Unclosed opening brace somewhere!');
  }
}
