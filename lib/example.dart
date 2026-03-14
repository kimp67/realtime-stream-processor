import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'realtime_stream_processor.dart';

/// RealtimeStreamProcessor 사용 예제
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Realtime Stream Processor Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const StreamProcessorDemo(),
    );
  }
}

class StreamProcessorDemo extends StatefulWidget {
  const StreamProcessorDemo({Key? key}) : super(key: key);

  @override
  State<StreamProcessorDemo> createState() => _StreamProcessorDemoState();
}

class _StreamProcessorDemoState extends State<StreamProcessorDemo> {
  late RealtimeStreamProcessor _processor;
  bool _isInitialized = false;
  String _statusMessage = 'Initializing...';
  Map<String, dynamic> _statistics = {};

  @override
  void initState() {
    super.initState();
    _initializeProcessor();
  }

  Future<void> _initializeProcessor() async {
    try {
      // 프로세서 생성
      _processor = RealtimeStreamProcessor(
        maxQueueSize: 10,
        onProcessFrame: _customFrameProcessor,
      );

      // 에러 리스너
      _processor.errorStream.listen((error) {
        setState(() {
          _statusMessage = 'Error: ${error.toString()}';
        });
      });

      // 결과 리스너
      _processor.outputStream.listen((result) {
        setState(() {
          _statusMessage = 'Processed frame ${result.frameId}';
          _statistics = _processor.statistics;
        });
      });

      // 카메라 초기화
      await _processor.initializeCamera(
        resolutionPreset: ResolutionPreset.medium,
      );

      setState(() {
        _isInitialized = true;
        _statusMessage = 'Ready to start';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Initialization failed: $e';
      });
    }
  }

  /// 커스텀 프레임 처리 함수
  Future<ProcessedFrameResult> _customFrameProcessor(FrameData frameData) async {
    // 여기서 원하는 프레임 처리 로직을 구현
    // 예: 객체 감지, 얼굴 인식, 세그멘테이션 등
    
    // 기본 처리 (이미지 변환)
    final cameraImage = frameData.cameraImage;
    
    // ML Kit InputImage 생성 등의 처리를 수행
    // ...
    
    return ProcessedFrameResult(
      frameId: frameData.frameId,
      processedAt: DateTime.now(),
      metadata: {
        'width': cameraImage.width,
        'height': cameraImage.height,
        'format': cameraImage.format.group.name,
        'custom_processing': 'applied',
      },
    );
  }

  Future<void> _startStreaming() async {
    try {
      await _processor.startStreaming();
      setState(() {
        _statusMessage = 'Streaming started';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Start failed: $e';
      });
    }
  }

  Future<void> _stopStreaming() async {
    await _processor.stopStreaming();
    setState(() {
      _statusMessage = 'Streaming stopped';
      _statistics = _processor.statistics;
    });
  }

  void _pauseStreaming() {
    _processor.pause();
    setState(() {
      _statusMessage = 'Streaming paused';
    });
  }

  void _resumeStreaming() {
    _processor.resume();
    setState(() {
      _statusMessage = 'Streaming resumed';
    });
  }

  @override
  void dispose() {
    _processor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Realtime Stream Processor'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 상태 메시지
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(_statusMessage),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 통계
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Statistics',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text('Processed Frames: ${_statistics['processedFrames'] ?? 0}'),
                    Text('Dropped Frames: ${_statistics['droppedFrames'] ?? 0}'),
                    Text('Queue Size: ${_statistics['queueSize'] ?? 0}'),
                    Text('FPS: ${(_statistics['fps'] ?? 0).toStringAsFixed(2)}'),
                    Text('Is Processing: ${_statistics['isProcessing'] ?? false}'),
                    Text('Is Paused: ${_statistics['isPaused'] ?? false}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 컨트롤 버튼
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _isInitialized && !_processor.isProcessing
                      ? _startStreaming
                      : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start'),
                ),
                ElevatedButton.icon(
                  onPressed: _processor.isProcessing ? _stopStreaming : null,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                ),
                ElevatedButton.icon(
                  onPressed: _processor.isProcessing && !_processor.isPaused
                      ? _pauseStreaming
                      : null,
                  icon: const Icon(Icons.pause),
                  label: const Text('Pause'),
                ),
                ElevatedButton.icon(
                  onPressed: _processor.isProcessing && _processor.isPaused
                      ? _resumeStreaming
                      : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Resume'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
