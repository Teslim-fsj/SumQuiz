import 'package:sumquiz/services/ai/generator_ai_service.dart';

void main() async {
  print('Testing GeneratorAIService.generateSummary...');
  final service = GeneratorAIService();
  print('Waiting for service initialization...');
  final initResult = await service.ensureInitialized(30);
  print('Service initialized: $initResult. Initialization error: \${service.initializationError ?? "None"}');
  
  print('Checking service health...');
  final isHealthy = await service.isServiceHealthy();
  print('Healthy: $isHealthy');
  
  try {
    print('Generating summary...');
    final summary = await service.generateSummary('The mitochondria is the powerhouse of the cell.');
    print('Summary Title: \${summary.title}');
    print('Summary Tags: \${summary.tags}');
  } catch (e) {
    print('Error during generation: \$e');
  }
}
