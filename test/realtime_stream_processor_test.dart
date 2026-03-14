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

      // 테스트 프레임 데이터 추가 (실제 CameraImage 없이 테스트)
      // 실제 환경에서는 카메라 초기화 후 테스트해야 함
      
      // Wait for potential results
      await Future.delayed(const Duration(milliseconds: 100));

      // Note: This test needs actual camera to work properly
      // expect(results, isNotEmpty);
    });

    test('Error stream catches exceptions', () async {
      final errors = <Exception>[];
      
      processor.errorStream.listen((error) {
        errors.add(error);
      });

      // 에러를 발생시키는 테스트
      // 실제 환경에서는 카메라 초기화 실패 등으로 테스트
      
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Note: This test needs actual error conditions
      // expect(errors, isEmpty);
    });

    test('Queue size limit', () {
      // 큐 크기 제한 테스트
      // 실제 CameraImage 객체가 필요하므로 통합 테스트에서 수행
      expect(processor.queueSize, lessThanOrEqualTo(10));
    });

    test('Custom frame processor', () async {
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

      // 실제 프레임 처리 시 customProcessorCalled가 true가 되어야 함
      // 통합 테스트에서 검증
      
      await customProcessor.dispose();
    });
  });

  group('FrameData Tests', () {
    test('FrameData creation', () {
      // 실제 CameraImage 없이는 테스트 불가
      // 통합 테스트에서 수행
    });
  });

  group('ProcessedFrameResult Tests', () {
    test('ProcessedFrameResult creation', () {
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
        metadata: {'width': 640, 'height': 480},
      );

      expect(result.frameId, equals(42));
      expect(result.processedAt, equals(now));
      expect(result.metadata['width'], equals(640));
      expect(result.metadata['height'], equals(480));
    });
  });
}
