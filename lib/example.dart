import 'dart:io';
import 'dart:typed_data';
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
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
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
  CameraController? _cameraController;
  
  bool _isInitialized = false;
  String _statusMessage = 'Initializing...';
  Map<String, dynamic> _statistics = {};
  
  // 처리된 이미지 데이터
  Uint8List? _processedImageBytes;
  ProcessedFrameResult? _latestResult;
  
  // UI 업데이트 제어
  DateTime _lastUIUpdate = DateTime.now();
  static const Duration _uiUpdateInterval = Duration(milliseconds: 100);

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
        if (mounted) {
          setState(() {
            _statusMessage = 'Error: ${error.toString()}';
          });
        }
      });

      // 결과 리스너 - UI 업데이트 빈도 제한
      _processor.outputStream.listen((result) {
        final now = DateTime.now();
        if (now.difference(_lastUIUpdate) >= _uiUpdateInterval) {
          if (mounted) {
            setState(() {
              _statusMessage = 'Processed frame ${result.frameId}';
              _statistics = _processor.statistics;
              _latestResult = result;
              _processedImageBytes = result.processedImageBytes;
            });
            _lastUIUpdate = now;
          }
        }
      });

      // 카메라 초기화
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('No cameras available');
      }

      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();

      // 프로세서에 카메라 초기화
      await _processor.initializeCamera(
        cameraDescription: cameras.first,
        resolutionPreset: ResolutionPreset.medium,
      );

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _statusMessage = 'Ready to start';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Initialization failed: $e';
        });
      }
    }
  }

  /// 커스텀 프레임 처리 함수
  Future<ProcessedFrameResult> _customFrameProcessor(FrameData frameData) async {
    // 기본 처리 (이미지 변환)
    final cameraImage = frameData.cameraImage;
    
    // ML Kit InputImage 생성 등의 처리를 수행
    // 여기서 얼굴 인식, 객체 감지 등을 수행할 수 있습니다
    
    return ProcessedFrameResult(
      frameId: frameData.frameId,
      processedAt: DateTime.now(),
      metadata: {
        'width': cameraImage.width,
        'height': cameraImage.height,
        'format': cameraImage.format.group.name,
        'timestamp': frameData.timestamp.toIso8601String(),
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
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Realtime Stream Processor'),
        elevation: 2,
      ),
      body: _isInitialized
          ? Column(
              children: [
                // 카메라 프리뷰 및 처리된 이미지 영역
                Expanded(
                  flex: 3,
                  child: _buildImageDisplayArea(),
                ),
                
                // 통계 정보 영역
                Container(
                  color: Colors.grey[100],
                  child: _buildStatisticsArea(),
                ),
                
                // 상태 및 컨트롤 영역
                Container(
                  color: Colors.white,
                  child: _buildControlArea(),
                ),
              ],
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_statusMessage),
                ],
              ),
            ),
    );
  }

  /// 이미지 표시 영역 (카메라 프리뷰 + 처리된 이미지)
  Widget _buildImageDisplayArea() {
    return Row(
      children: [
        // 왼쪽: 카메라 프리뷰
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue, width: 2),
              color: Colors.black,
            ),
            child: Column(
              children: [
                Container(
                  color: Colors.blue,
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Camera Preview',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (_processor.isProcessing)
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: _buildCameraPreview(),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(width: 8),
        
        // 오른쪽: 처리된 이미지
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.green, width: 2),
              color: Colors.black,
            ),
            child: Column(
              children: [
                Container(
                  color: Colors.green,
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      const Icon(Icons.image, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Processed Image',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (_latestResult != null)
                        Text(
                          '#${_latestResult!.frameId}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: _buildProcessedImage(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 카메라 프리뷰 위젯
  Widget _buildCameraPreview() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Center(
        child: Text(
          'Camera not ready',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: _cameraController!.value.aspectRatio,
        child: CameraPreview(_cameraController!),
      ),
    );
  }

  /// 처리된 이미지 위젯
  Widget _buildProcessedImage() {
    if (_processedImageBytes == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported,
              size: 64,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              _processor.isProcessing
                  ? 'Processing frames...'
                  : 'Start streaming to see processed images',
              style: TextStyle(color: Colors.grey[400]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Center(
      child: Image.memory(
        _processedImageBytes!,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 48),
              const SizedBox(height: 8),
              Text(
                'Image decode error',
                style: TextStyle(color: Colors.grey[400]),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 통계 정보 영역
  Widget _buildStatisticsArea() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics, size: 20),
              const SizedBox(width: 8),
              Text(
                'Real-time Statistics',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatCard(
                'FPS',
                '${(_statistics['fps'] ?? 0).toStringAsFixed(1)}',
                Icons.speed,
                Colors.blue,
              ),
              const SizedBox(width: 8),
              _buildStatCard(
                'Processed',
                '${_statistics['processedFrames'] ?? 0}',
                Icons.check_circle,
                Colors.green,
              ),
              const SizedBox(width: 8),
              _buildStatCard(
                'Dropped',
                '${_statistics['droppedFrames'] ?? 0}',
                Icons.warning,
                Colors.orange,
              ),
              const SizedBox(width: 8),
              _buildStatCard(
                'Queue',
                '${_statistics['queueSize'] ?? 0}',
                Icons.queue,
                Colors.purple,
              ),
            ],
          ),
          if (_latestResult != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Frame #${_latestResult!.frameId} • '
                      '${_latestResult!.metadata['width']}x${_latestResult!.metadata['height']} • '
                      '${_latestResult!.metadata['format']}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 통계 카드 위젯
  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 컨트롤 영역
  Widget _buildControlArea() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 상태 메시지
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getStatusColor(),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  _getStatusIcon(),
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _statusMessage,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          
          // 컨트롤 버튼
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isInitialized && !_processor.isProcessing
                      ? _startStreaming
                      : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _processor.isProcessing ? _stopStreaming : null,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _processor.isProcessing && !_processor.isPaused
                      ? _pauseStreaming
                      : _processor.isProcessing && _processor.isPaused
                          ? _resumeStreaming
                          : null,
                  icon: Icon(
                    _processor.isPaused ? Icons.play_arrow : Icons.pause,
                  ),
                  label: Text(_processor.isPaused ? 'Resume' : 'Pause'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 상태에 따른 색상 반환
  Color _getStatusColor() {
    if (_statusMessage.contains('Error') || _statusMessage.contains('failed')) {
      return Colors.red;
    } else if (_statusMessage.contains('started') || _statusMessage.contains('Processing')) {
      return Colors.green;
    } else if (_statusMessage.contains('paused')) {
      return Colors.orange;
    } else if (_statusMessage.contains('stopped')) {
      return Colors.grey;
    }
    return Colors.blue;
  }

  /// 상태에 따른 아이콘 반환
  IconData _getStatusIcon() {
    if (_statusMessage.contains('Error') || _statusMessage.contains('failed')) {
      return Icons.error;
    } else if (_statusMessage.contains('started') || _statusMessage.contains('Processing')) {
      return Icons.check_circle;
    } else if (_statusMessage.contains('paused')) {
      return Icons.pause_circle;
    } else if (_statusMessage.contains('stopped')) {
      return Icons.stop_circle;
    }
    return Icons.info;
  }
}
