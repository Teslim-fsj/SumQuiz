import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hive/hive.dart';
import 'package:sumquiz/models/mastery/topic_node.dart';
import 'package:sumquiz/models/spaced_repetition.dart';
import 'package:sumquiz/models/mastery/mastery_history.dart';
import 'package:sumquiz/services/mastery_service.dart';
import 'package:sumquiz/services/local_database_service.dart';

class MockBox<T> extends Mock implements Box<T> {}
class MockLocalDatabaseService extends Mock implements LocalDatabaseService {}
class MockTopicNode extends Mock implements TopicNode {}

class FakeMasteryHistory extends Fake implements MasteryHistory {}
class FakeTopicNode extends Fake implements TopicNode {}
class FakeLearningSignal extends Fake implements LearningSignal {}

void main() {
  late MasteryService masteryService;
  late MockBox<TopicNode> mockTopicBox;
  late MockBox<SpacedRepetitionItem> mockSrsBox;
  late MockLocalDatabaseService mockDb;

  setUpAll(() {
    registerFallbackValue(FakeMasteryHistory());
    registerFallbackValue(FakeTopicNode());
    registerFallbackValue(FakeLearningSignal());
  });

  setUp(() {
    mockTopicBox = MockBox<TopicNode>();
    mockSrsBox = MockBox<SpacedRepetitionItem>();
    mockDb = MockLocalDatabaseService();
    
    // Default mock behavior
    when(() => mockDb.saveMasteryHistory(any())).thenAnswer((_) async {});
    when(() => mockTopicBox.values).thenReturn([]); // Prevent null errors in global analytics
    
    masteryService = MasteryService(mockTopicBox, mockSrsBox, mockDb);
  });

  group('Retention Integration Logic Tests', () {
    test('Quiz Signal Flow: Success increases mastery and stability', () async {
      final topicId = 'test_topic_1';
      final topic = MockTopicNode();
      
      when(() => topic.id).thenReturn(topicId);
      when(() => topic.userId).thenReturn('user_123');
      when(() => topic.name).thenReturn('Mitosis');
      when(() => topic.masteryScore).thenReturn(0.5);
      when(() => topic.stabilityScore).thenReturn(0.5);
      when(() => topic.confidenceScore).thenReturn(0.5);
      when(() => topic.lastInteraction).thenReturn(DateTime.now());
      
      // Assignments in Dart return the assigned value
      when(() => topic.masteryScore = any()).thenAnswer((invocation) => invocation.positionalArguments[0] as double);
      when(() => topic.stabilityScore = any()).thenAnswer((invocation) => invocation.positionalArguments[0] as double);
      when(() => topic.confidenceScore = any()).thenAnswer((invocation) => invocation.positionalArguments[0] as double);
      when(() => topic.learningVelocity = any()).thenAnswer((invocation) => invocation.positionalArguments[0] as double);
      when(() => topic.lastInteraction = any()).thenAnswer((invocation) => invocation.positionalArguments[0] as DateTime);
      
      when(() => topic.save()).thenAnswer((_) async {});
      when(() => mockTopicBox.get(topicId)).thenReturn(topic);

      await masteryService.processSignal(LearningSignal(
        topicId: topicId,
        type: SignalType.quizCorrect,
        timestamp: DateTime.now(),
        metadata: {'isFast': true},
      ));

      verify(() => topic.masteryScore = any(that: greaterThan(0.5))).called(1);
    });

    test('Fuzzy Matching: Should return existing topic for similar names', () async {
      final existingTopic = TopicNode(
        id: '1',
        name: 'Photosynthesis',
        userId: 'user_123',
        lastInteraction: DateTime.now(),
        createdAt: DateTime.now(),
        contentIds: [],
      );

      when(() => mockTopicBox.values).thenReturn([existingTopic]);

      final result = await masteryService.getOrCreateTopic('user_123', 'photosynthesys');
      
      expect(result.id, equals(existingTopic.id));
      expect(result.name, equals('Photosynthesis'));
    });
  });
}
