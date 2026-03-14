import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../realtime_stream_processor.dart';

/// 고급 사용 예제: ML Kit 통합 및 실시간 분석
class AdvancedExample extends StatefulWidget {
  const AdvancedExample({Key? key}) : super(key: key);

  @override
  State<AdvancedExample> createState() => _AdvancedExampleState();
}

class _AdvancedExampleState extends State<AdvancedExample> {
  late RealtimeStreamProcessor _processor;
  CameraController? _cameraController;
  
  bool _isInitialized = false;
  List<ProcessedFrameResult> _recentResults = [];
  
  // 통계 업데이트 타이머
  Timer? _statsTimer;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _initializeProcessor();
    _startStatsTimer();
  }

  /// 통계 업데이트 타이머 시작
  void _startStatsTimer() {
    _statsTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_processor.isProcessing) {
        setState(() {
          _stats = _processor.statistics;
        });
      }
    });
  }

  /// 프로세서 초기화
  Future<void> _initializeProcessor() async {
    try {
      _processor = RealtimeStreamProcessor(
        maxQueueSize: 15,
        onProcessFrame: _advancedFrameProcessor,
      );

      // 결과 스트림 리스닝
      _processor.outputStream.listen(_onFrameProcessed);

      // 에러 스트림 리스닝
      _processor.errorStream.listen(_onError);

      // 카메라 초기화
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('No cameras available');
      }

      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();

      // 프로세서에 카메라 설정
      await _processor.initializeCamera(
        cameraDescription: cameras.first,
        resolutionPreset: ResolutionPreset.medium,
      );

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      _showError('Initialization failed: $e');
    }
  }

  /// 고급 프레임 처리 함수
  Future<ProcessedFrameResult> _advancedFrameProcessor(
    FrameData frameData,
  ) async {
    final startTime = DateTime.now();
    
    // 여기서 ML Kit 또는 다른 분석 수행
    // 예시: 
    // - 얼굴 감지
    // - 텍스트 인식
    // - 객체 감지
    // - 포즈 추정
    // - 세그멘테이션
    
    final cameraImage = frameData.cameraImage;
    
    // 처리 시뮬레이션 (실제로는 ML 모델 사용)
    await Future.delayed(const Duration(milliseconds: 50));
    
    final endTime = DateTime.now();
    final processingTime = endTime.difference(startTime);
    
    return ProcessedFrameResult(
      frameId: frameData.frameId,
      processedAt: endTime,
      metadata: {
        'width': cameraImage.width,
        'height': cameraImage.height,
        'format': cameraImage.format.group.name,
        'processingTimeMs': processingTime.inMilliseconds,
        'timestamp': frameData.timestamp.toIso8601String(),
        
        // 실제 분석 결과를 여기에 추가
        'analysis': {
          'faceCount': 0,
          'textBlocks': 0,
          'objects': [],
        },
      },
    );
  }

  /// 프레임 처리 완료 콜백
  void _onFrameProcessed(ProcessedFrameResult result) {
    setState(() {
      // 최근 10개 결과만 유지
      _recentResults.add(result);
      if (_recentResults.length > 10) {
        _recentResults.removeAt(0);
      }
    });
  }

  /// 에러 콜백
  void _onError(Exception error) {
    _showError(error.toString());
  }

  /// 에러 메시지 표시
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  /// 스트리밍 시작
  Future<void> _startStreaming() async {
    try {
      await _processor.startStreaming();
      _showMessage('Streaming started');
    } catch (e) {
      _showError('Failed to start: $e');
    }
  }

  /// 스트리밍 중지
  Future<void> _stopStreaming() async {
    await _processor.stopStreaming();
    _showMessage('Streaming stopped');
  }

  /// 메시지 표시
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
    _processor.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Stream Processor'),
        actions: [
          IconButton(
            icon: Icon(_processor.isPaused ? Icons.play_arrow : Icons.pause),
            onPressed: () {
              if (_processor.isPaused) {
                _processor.resume();
                _showMessage('Resumed');
              } else {
                _processor.pause();
                _showMessage('Paused');
              }
              setState(() {});
            },
          ),
        ],
      ),
      body: _isInitialized
          ? Column(
              children: [
                // 카메라 프리뷰
                Expanded(
                  flex: 2,
                  child: _buildCameraPreview(),
                ),
                
                // 통계 패널
                Expanded(
                  flex: 1,
                  child: _buildStatisticsPanel(),
                ),
                
                // 최근 결과
                Expanded(
                  flex: 2,
                  child: _buildRecentResults(),
                ),
                
                // 컨트롤 버튼
                _buildControls(),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }

  /// 카메라 프리뷰
  Widget _buildCameraPreview() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Center(child: Text('Camera not ready'));
    }
    
    return Container(
      color: Colors.black,
      child: Center(
        child: AspectRatio(
          aspectRatio: _cameraController!.value.aspectRatio,
          child: CameraPreview(_cameraController!),
        ),
      ),
    );
  }

  /// 통계 패널
  Widget _buildStatisticsPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Real-time Statistics',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                _buildStatItem('FPS', '${(_stats['fps'] ?? 0).toStringAsFixed(1)}'),
                _buildStatItem('Processed', '${_stats['processedFrames'] ?? 0}'),
                _buildStatItem('Dropped', '${_stats['droppedFrames'] ?? 0}'),
                _buildStatItem('Queue Size', '${_stats['queueSize'] ?? 0}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 통계 항목
  Widget _buildStatItem(String label, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 최근 결과 목록
  Widget _buildRecentResults() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Results',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _recentResults.isEmpty
                ? const Center(child: Text('No results yet'))
                : ListView.builder(
                    itemCount: _recentResults.length,
                    reverse: true,
                    itemBuilder: (context, index) {
                      final result = _recentResults[
                        _recentResults.length - 1 - index
                      ];
                      return _buildResultItem(result);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// 결과 항목
  Widget _buildResultItem(ProcessedFrameResult result) {
    final processingTime = result.metadata['processingTimeMs'] ?? 0;
    
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Text('${result.frameId % 100}'),
        ),
        title: Text('Frame ${result.frameId}'),
        subtitle: Text(
          'Processed in ${processingTime}ms\n'
          'Size: ${result.metadata['width']}x${result.metadata['height']}',
        ),
        trailing: const Icon(Icons.check_circle, color: Colors.green),
        isThreeLine: true,
      ),
    );
  }

  /// 컨트롤 버튼
  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            onPressed: _processor.isProcessing ? null : _startStreaming,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
          ElevatedButton.icon(
            onPressed: _processor.isProcessing ? _stopStreaming : null,
            icon: const Icon(Icons.stop),
            label: const Text('Stop'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
