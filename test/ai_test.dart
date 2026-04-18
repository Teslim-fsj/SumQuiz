import 'package:flutter_test/flutter_test.dart';
import 'package:sumquiz/services/ai/generator_ai_service.dart';

import 'dart:io';

class MyHttpOverrides extends HttpOverrides {}

void main() {
  HttpOverrides.global = MyHttpOverrides();
  TestWidgetsFlutterBinding.ensureInitialized();
  
  test('Test GeneratorAIService summary generation', () async {
    final service = GeneratorAIService();
    await service.ensureInitialized(30);
    final healthy = await service.isServiceHealthy();
    print('Service Healthy: $healthy');
    
    try {
      final summary = await service.generateSummary('The mitochondria is the powerhouse of the cell.', difficulty: 'intermediate');
      print('Summary Title: ${summary.title}');
      print('Summary Tags: ${summary.tags}');
    } catch (e, s) {
      print('Error during summary generation: $e');
      print('Stacktrace: $s');
    }
  });
}
