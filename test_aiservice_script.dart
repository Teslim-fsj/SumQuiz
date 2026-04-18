import 'package:sumquiz/services/ai/generator_ai_service.dart';

void main() async {
  print('Testing GeneratorAIService.generateSummary...');
  final service = GeneratorAIService();
  await service.ensureInitialized(30);
  print('Service initialized. Healthy: ${await service.isServiceHealthy()}');
  
  try {
    final summary = await service.generateSummary('The mitochondria is the powerhouse of the cell.');
    print('Summary Title: ${summary.title}');
    print('Summary Tags: ${summary.tags}');
  } catch (e) {
    print('Error: $e');
  }
}
