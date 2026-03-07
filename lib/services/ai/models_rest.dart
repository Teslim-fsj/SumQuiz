import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const String apiKey = 'AIzaSyDWEUCZ9lfq7yspgl6fMt84jIUOAN9mItI';
  const String url =
      'https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey';

  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final models = data['models'] as List;
      print('--- Available Models ---');
      for (var model in models) {
        print(model['name']);
      }
    } else {
      print('Failed to list models: ${response.statusCode}');
      print(response.body);
    }
  } catch (e) {
    print('Error: $e');
  }
}
