import 'dart:io';

void main() {
  final file = File('lib/views/screens/review_screen.dart');
  final lines = file.readAsLinesSync();
  int open = 0;
  int close = 0;
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    for (int j = 0; j < line.length; j++) {
      if (line[j] == '{') open++;
      if (line[j] == '}') close++;
    }
  }
  print('Open: $open, Close: $close');
}
