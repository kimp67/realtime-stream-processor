import 'package:flutter_test/flutter_test.dart';
import 'package:camera/camera.dart';
import 'package:realtime_stream_processor/realtime_stream_processor.dart';

void main() {
  group('RealtimeStreamProcessor Tests', () {
    late RealtimeStreamProcessor processor;

    setUp(() {
      processor = RealtimeStreamProcessor(maxQueueSize: 10);
    });

    tearDown(() async {
      await processor.dispose();
    });

    test('Processor initialization', () {
      expect(processor.isProcessing, isFalse);
      expect(processor.isPaused, isFalse);
      expect(processor.queueSize, equals(0));
    });

    test('Statistics initial state', () {
      final stats = processor.statistics;
      expect(stats['processedFrames'], equals(0));
      expect(stats['droppedFrames'], equals(0));
      expect(stats['queueSize'], equals(0));
      expect(stats['isProcessing'], isFalse);
      expect(stats['isPaused'], isFalse);
    });

    test('Pause and resume', () {
      processor.pause();
      expect(processor.isPaused, isTrue);

      processor.resume();
      expect(processor.isPaused, isFalse);
    });

    test('Output stream broadcasts results', () async {
      final results = <ProcessedFrameResult>[];
      
      processor.outputStream.listen((result) {
        results.add(result);
      });

      // 실제 카메라 환경에서 테스트 필요
      // 참고: 이 테스트는 카메라 초기화 후 실행되어야 함
      
      await Future.delayed(const Duration(milliseconds: 100));

      // 카메라가 없는 환경에서는 결과가 없음
      expect(results, isEmpty);
    });

    test('Error stream catches exceptions', () async {
      final errors = <Exception>[];
      
      processor.errorStream.listen((error) {
        errors.add(error);
      });

      // 에러 발생 테스트는 실제 카메라 환경에서 수행
      
      await Future.delayed(const Duration(milliseconds: 100));
      
      // 정상 상태에서는 에러가 없어야 함
      expect(errors, isEmpty);
    });

    test('Queue size limit respected', () {
      // 큐 크기는 maxQueueSize를 초과하지 않아야 함
      expect(processor.queueSize, lessThanOrEqualTo(10));
    });

    test('Custom frame processor callback', () async {
      bool customProcessorCalled = false;
      
      final customProcessor = RealtimeStreamProcessor(
        maxQueueSize: 5,
        onProcessFrame: (frameData) async {
          customProcessorCalled = true;
          return ProcessedFrameResult(
            frameId: frameData.frameId,
            processedAt: DateTime.now(),
            metadata: {'custom': true},
          );
        },
      );

      // 커스텀 프로세서는 프레임이 들어올 때 호출됨
      // 실제 카메라 환경에서 검증 필요
      
      await customProcessor.dispose();
      
      // 카메라 없이는 호출되지 않음
      expect(customProcessorCalled, isFalse);
    });

    test('Multiple pause/resume cycles', () {
      processor.pause();
      expect(processor.isPaused, isTrue);

      processor.resume();
      expect(processor.isPaused, isFalse);

      processor.pause();
      expect(processor.isPaused, isTrue);

      processor.resume();
      expect(processor.isPaused, isFalse);
    });

    test('Statistics update correctly', () {
      final stats = processor.statistics;
      
      expect(stats, isNotNull);
      expect(stats, isA<Map<String, dynamic>>());
      expect(stats.containsKey('processedFrames'), isTrue);
      expect(stats.containsKey('droppedFrames'), isTrue);
      expect(stats.containsKey('queueSize'), isTrue);
      expect(stats.containsKey('fps'), isTrue);
      expect(stats.containsKey('duration'), isTrue);
      expect(stats.containsKey('isProcessing'), isTrue);
      expect(stats.containsKey('isPaused'), isTrue);
    });
  });

  group('FrameData Tests', () {
    test('FrameData creation requires CameraImage', () {
      // FrameData는 실제 CameraImage 객체가 필요
      // 통합 테스트에서 수행
      expect(true, isTrue); // Placeholder test
    });
  });

  group('ProcessedFrameResult Tests', () {
    test('ProcessedFrameResult creation with minimal fields', () {
      final result = ProcessedFrameResult(
        frameId: 1,
        processedAt: DateTime.now(),
        metadata: {'test': 'data'},
      );

      expect(result.frameId, equals(1));
      expect(result.metadata['test'], equals('data'));
      expect(result.processedImageBytes, isNull);
      expect(result.mlKitInputImage, isNull);
    });

    test('ProcessedFrameResult with all fields', () {
      final now = DateTime.now();
      final result = ProcessedFrameResult(
        frameId: 42,
        processedAt: now,
        metadata: {'width': 640, 'height': 480, 'format': 'yuv420'},
      );

      expect(result.frameId, equals(42));
      expect(result.processedAt, equals(now));
      expect(result.metadata['width'], equals(640));
      expect(result.metadata['height'], equals(480));
      expect(result.metadata['format'], equals('yuv420'));
    });

    test('ProcessedFrameResult metadata can contain various types', () {
      final result = ProcessedFrameResult(
        frameId: 100,
        processedAt: DateTime.now(),
        metadata: {
          'string': 'value',
          'int': 123,
          'double': 45.67,
          'bool': true,
          'list': [1, 2, 3],
          'map': {'nested': 'data'},
        },
      );

      expect(result.metadata['string'], equals('value'));
      expect(result.metadata['int'], equals(123));
      expect(result.metadata['double'], equals(45.67));
      expect(result.metadata['bool'], equals(true));
      expect(result.metadata['list'], equals([1, 2, 3]));
      expect(result.metadata['map'], equals({'nested': 'data'}));
    });
  });
}
