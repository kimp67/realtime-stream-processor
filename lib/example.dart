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
      print('🎬 Starting initialization...');
      
      // 프로세서 생성 - 기본 처리 사용 (이미지 변환 포함)
      _processor = RealtimeStreamProcessor(
        maxQueueSize: 10,
        // onProcessFrame을 제거하여 기본 처리 사용
        // 기본 처리는 자동으로 processedImageBytes를 생성함
      );

      // 에러 리스너
      _processor.errorStream.listen((error) {
        if (mounted) {
          setState(() {
            _statusMessage = 'Error: ${error.toString()}';
          });
          // 콘솔에도 에러 출력
          print('❌ Processor Error: $error');
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
              
              // 디버깅: 이미지 바이트 상태 확인
              if (_processedImageBytes != null) {
                print('✅ Frame #${result.frameId}: Image bytes received (${_processedImageBytes!.length} bytes)');
              } else {
                print('⚠️ Frame #${result.frameId}: No image bytes (processedImageBytes is null)');
              }
            });
            _lastUIUpdate = now;
          }
        }
      });

      print('📷 Getting available cameras...');
      
      // 카메라 초기화
      final cameras = await availableCameras();
      print('📷 Found ${cameras.length} cameras');
      
      if (cameras.isEmpty) {
        throw Exception('No cameras available');
      }

      print('📷 Initializing camera controller...');
      print('   - Camera: ${cameras.first.name}');
      print('   - Lens: ${cameras.first.lensDirection}');
      print('   - Sensor orientation: ${cameras.first.sensorOrientation}');
      
      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      print('📷 Waiting for camera initialization...');
      await _cameraController!.initialize();
      print('✅ Camera controller initialized successfully');
      print('   - Resolution: ${_cameraController!.value.previewSize}');
      print('   - Aspect ratio: ${_cameraController!.value.aspectRatio}');

      // 프로세서에 카메라 초기화
      print('🔧 Initializing processor with camera...');
      await _processor.initializeCamera(
        cameraDescription: cameras.first,
        resolutionPreset: ResolutionPreset.medium,
      );
      print('✅ Processor initialized successfully');

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _statusMessage = 'Ready to start - Camera preview should be visible';
        });
        print('✅ UI updated - initialization complete');
      }
    } catch (e, stackTrace) {
      print('❌ Initialization failed: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _statusMessage = 'Initialization failed: $e';
        });
      }
    }
  }

  /// 커스텀 프레임 처리 함수 (참고용 - 현재 사용 안 함)
  /// 
  /// 기본 프로세서를 사용하면 자동으로 이미지가 변환됩니다.
  /// ML Kit 처리가 필요한 경우 이 함수를 활성화하세요.
  /// 
  /// 사용 방법:
  /// RealtimeStreamProcessor(
  ///   maxQueueSize: 10,
  ///   onProcessFrame: _customFrameProcessor,  // 이 줄 추가
  /// )
  Future<ProcessedFrameResult> _customFrameProcessor(FrameData frameData) async {
    // 기본 처리 (이미지 변환)
    final cameraImage = frameData.cameraImage;
    
    // ✅ 중요: processedImageBytes를 반환해야 UI에 이미지가 표시됨
    // 방법 1: 프로세서의 내부 메서드 사용 (권장)
    // 하지만 private 메서드라서 직접 접근 불가
    
    // 방법 2: 직접 이미지 변환 (예시)
    Uint8List? imageBytes;
    
    // Android (nv21) 또는 iOS (bgra8888) 처리
    if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
      // iOS: 바로 사용 가능
      imageBytes = Uint8List.fromList(cameraImage.planes[0].bytes);
    } else if (cameraImage.format.group == ImageFormatGroup.nv21) {
      // Android: 간단한 그레이스케일 변환
      // 실제 사용 시에는 더 복잡한 변환 로직 필요
      imageBytes = cameraImage.planes[0].bytes;
    }
    
    // ML Kit InputImage 생성 등의 처리를 수행
    // 여기서 얼굴 인식, 객체 감지 등을 수행할 수 있습니다
    // final inputImage = InputImage.fromBytes(...);
    // final faces = await faceDetector.processImage(inputImage);
    
    return ProcessedFrameResult(
      frameId: frameData.frameId,
      processedAt: DateTime.now(),
      processedImageBytes: imageBytes,  // ✅ 이미지 바이트 포함
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
        actions: [
          // 디버그 정보 표시
          if (_cameraController != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(
                child: Text(
                  _cameraController!.value.isInitialized ? '📹' : '⏳',
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
        ],
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
                  const SizedBox(height: 24),
                  Text(
                    _statusMessage,
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  // 초기화 단계 표시
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Initialization Steps:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[900],
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildInitStep('Creating processor', true),
                        _buildInitStep('Finding cameras', _cameraController != null),
                        _buildInitStep('Initializing camera', 
                          _cameraController?.value.isInitialized ?? false),
                        _buildInitStep('Ready', _isInitialized),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
  
  Widget _buildInitStep(String label, bool completed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            completed ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: completed ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: completed ? Colors.green[700] : Colors.grey[600],
            ),
          ),
        ],
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
    print('🖼️ Building camera preview widget...');
    print('   - Controller null? ${_cameraController == null}');
    print('   - Initialized? ${_cameraController?.value.isInitialized}');
    
    if (_cameraController == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.camera_alt,
              size: 64,
              color: Colors.white54,
            ),
            const SizedBox(height: 16),
            const Text(
              'Camera controller not created',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }
    
    if (!_cameraController!.value.isInitialized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 16),
            const Text(
              'Initializing camera...',
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Please wait',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      );
    }

    print('✅ Camera preview ready - displaying');
    print('   - Preview size: ${_cameraController!.value.previewSize}');
    print('   - Aspect ratio: ${_cameraController!.value.aspectRatio}');
    
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
                  ? 'Processing frames...\nWaiting for image data...'
                  : 'Start streaming to see processed images',
              style: TextStyle(color: Colors.grey[400]),
              textAlign: TextAlign.center,
            ),
            if (_processor.isProcessing) ...[
              const SizedBox(height: 16),
              const CircularProgressIndicator(),
              const SizedBox(height: 8),
              Text(
                'Frames processed: ${_statistics['processedFrames'] ?? 0}',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ],
        ),
      );
    }

    // 이미지 바이트가 있을 때
    print('🖼️ Displaying image: ${_processedImageBytes!.length} bytes');
    
    return Center(
      child: Image.memory(
        _processedImageBytes!,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          print('❌ Image decode error: $error');
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 48),
              const SizedBox(height: 8),
              Text(
                'Image decode error',
                style: TextStyle(color: Colors.grey[400]),
              ),
              const SizedBox(height: 8),
              Text(
                'Size: ${_processedImageBytes!.length} bytes',
                style: const TextStyle(color: Colors.red, fontSize: 12),
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
