import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty) return;
  final file = File(args[0]);
  final content = file.readAsStringSync();
  
  final stack = <Map<String, dynamic>>[];
  final pairs = {'(': ')', '{': '}', '[': ']'};
  
  for (var i = 0; i < content.length; i++) {
    final char = content[i];
    if (char == '(' || char == '{' || char == '[') {
      stack.add({'char': char, 'pos': i});
    } else if (char == ')' || char == '}' || char == ']') {
      if (stack.isEmpty) {
        print("Extra closing '$char' at position $i");
        printContext(content, i);
        return;
      }
      final top = stack.removeLast();
      if (pairs[top['char']] != char) {
        print("Mismatched '$char' at position $i, expected '${pairs[top['char']]}' to match '${top['char']}' from position ${top['pos']}");
        printContext(content, i);
        return;
      }
    }
  }
  
  if (stack.isNotEmpty) {
    for (final item in stack) {
      print("Unclosed '${item['char']}' from position ${item['pos']}");
      printContext(content, item['pos']);
    }
  } else {
    print("Balanced!");
  }
}

void printContext(String content, int pos) {
  final start = pos - 50 < 0 ? 0 : pos - 50;
  final end = pos + 50 > content.length ? content.length : pos + 50;
  print("Context: ${content.substring(start, end)}");
}
