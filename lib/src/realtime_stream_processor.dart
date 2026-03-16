import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:image/image.dart' as img;

/// 프레임 데이터를 담는 클래스
class FrameData {
  final CameraImage cameraImage;
  final DateTime timestamp;
  final int frameId;
  
  FrameData({
    required this.cameraImage,
    required this.timestamp,
    required this.frameId,
  });
}

/// 프레임 처리 결과를 담는 클래스
class ProcessedFrameResult {
  final int frameId;
  final DateTime processedAt;
  final Uint8List? processedImageBytes;
  final Map<String, dynamic> metadata;
  final InputImage? mlKitInputImage;
  
  ProcessedFrameResult({
    required this.frameId,
    required this.processedAt,
    this.processedImageBytes,
    this.metadata = const {},
    this.mlKitInputImage,
  });
}

/// 실시간 스트리밍 분할 클래스
class RealtimeStreamProcessor {
  // 카메라 컨트롤러
  CameraController? _cameraController;
  
  // 입력 큐
  final Queue<FrameData> _inputQueue = Queue<FrameData>();
  
  // 큐 크기 제한
  final int maxQueueSize;
  
  // 프레임 ID 카운터
  int _frameIdCounter = 0;
  
  // 처리 중인지 여부
  bool _isProcessing = false;
  
  // 일시정지 상태
  bool _isPaused = false;
  
  // 중지 요청 플래그
  bool _shouldStop = false;
  
  // 스트림 컨트롤러
  final StreamController<ProcessedFrameResult> _outputStreamController =
      StreamController<ProcessedFrameResult>.broadcast();
  
  // 에러 스트림 컨트롤러
  final StreamController<Exception> _errorStreamController =
      StreamController<Exception>.broadcast();
  
  // 통계
  int _processedFrameCount = 0;
  int _droppedFrameCount = 0;
  DateTime? _startTime;
  
  // 프레임 처리 콜백 (사용자 정의 가능)
  Future<ProcessedFrameResult> Function(FrameData)? onProcessFrame;
  
  RealtimeStreamProcessor({
    this.maxQueueSize = 10,
    this.onProcessFrame,
  });
  
  // ========== Public Methods ==========
  
  /// 카메라 초기화
  Future<void> initializeCamera({
    CameraDescription? cameraDescription,
    ResolutionPreset resolutionPreset = ResolutionPreset.medium,
    bool enableAudio = false,
  }) async {
    try {
      // 카메라 목록 가져오기
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('No cameras available');
      }
      
      // 카메라 선택
      final camera = cameraDescription ?? cameras.first;
      
      // 카메라 컨트롤러 생성
      _cameraController = CameraController(
        camera,
        resolutionPreset,
        enableAudio: enableAudio,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      
      // 카메라 초기화
      await _cameraController!.initialize();
      
    } catch (e) {
      _handleError(Exception('Camera initialization failed: $e'));
      rethrow;
    }
  }
  
  /// 스트리밍 시작
  Future<void> startStreaming() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      throw Exception('Camera not initialized. Call initializeCamera() first.');
    }
    
    if (_isProcessing) {
      throw Exception('Streaming already started');
    }
    
    _isProcessing = true;
    _shouldStop = false;
    _isPaused = false;
    _startTime = DateTime.now();
    _processedFrameCount = 0;
    _droppedFrameCount = 0;
    
    // 카메라 이미지 스트림 시작
    await _cameraController!.startImageStream(_onCameraImage);
    
    // 큐 처리 시작
    _processQueue();
  }
  
  /// 스트리밍 일시정지
  void pause() {
    _isPaused = true;
  }
  
  /// 스트리밍 재개
  void resume() {
    _isPaused = false;
  }
  
  /// 스트리밍 중지
  Future<void> stopStreaming() async {
    if (!_isProcessing) return;
    
    _shouldStop = true;
    _isProcessing = false;
    
    // 카메라 이미지 스트림 중지
    if (_cameraController != null && _cameraController!.value.isStreamingImages) {
      await _cameraController!.stopImageStream();
    }
    
    // 큐 비우기
    _inputQueue.clear();
  }
  
  /// 카메라 및 리소스 정리
  Future<void> dispose() async {
    await stopStreaming();
    
    await _cameraController?.dispose();
    _cameraController = null;
    
    await _outputStreamController.close();
    await _errorStreamController.close();
  }
  
  /// 큐에 프레임 수동 추가 (테스트용)
  void enqueueFrame(FrameData frameData) {
    _addToQueue(frameData);
  }
  
  /// 출력 스트림 가져오기
  Stream<ProcessedFrameResult> get outputStream => _outputStreamController.stream;
  
  /// 에러 스트림 가져오기
  Stream<Exception> get errorStream => _errorStreamController.stream;
  
  /// 현재 큐 크기
  int get queueSize => _inputQueue.length;
  
  /// 처리 중인지 여부
  bool get isProcessing => _isProcessing;
  
  /// 일시정지 상태
  bool get isPaused => _isPaused;
  
  /// 통계 정보
  Map<String, dynamic> get statistics {
    final duration = _startTime != null 
        ? DateTime.now().difference(_startTime!)
        : Duration.zero;
    
    final fps = duration.inSeconds > 0 
        ? _processedFrameCount / duration.inSeconds 
        : 0.0;
    
    return {
      'processedFrames': _processedFrameCount,
      'droppedFrames': _droppedFrameCount,
      'queueSize': _inputQueue.length,
      'fps': fps,
      'duration': duration,
      'isProcessing': _isProcessing,
      'isPaused': _isPaused,
    };
  }
  
  // ========== Private Methods ==========
  
  /// 카메라 이미지 콜백
  void _onCameraImage(CameraImage image) {
    if (_isPaused || _shouldStop) return;
    
    final frameData = FrameData(
      cameraImage: image,
      timestamp: DateTime.now(),
      frameId: _frameIdCounter++,
    );
    
    _addToQueue(frameData);
  }
  
  /// 큐에 프레임 추가
  void _addToQueue(FrameData frameData) {
    // 큐가 가득 찬 경우 가장 오래된 프레임 제거
    if (_inputQueue.length >= maxQueueSize) {
      _inputQueue.removeFirst();
      _droppedFrameCount++;
    }
    
    _inputQueue.add(frameData);
  }
  
  /// 큐 처리 루프
  Future<void> _processQueue() async {
    while (_isProcessing) {
      // 일시정지 또는 큐가 비어있으면 대기
      if (_isPaused || _inputQueue.isEmpty) {
        await Future.delayed(const Duration(milliseconds: 10));
        continue;
      }
      
      // 중지 요청 확인
      if (_shouldStop) break;
      
      // 큐에서 프레임 가져오기
      final frameData = _inputQueue.removeFirst();
      
      try {
        // 프레임 처리
        final result = await _processFrame(frameData);
        
        // 결과가 유효한 경우만 스트림에 전송
        if (!_outputStreamController.isClosed) {
          _outputStreamController.add(result);
        }
        
        _processedFrameCount++;
        
      } catch (e) {
        _handleError(Exception('Frame processing error: $e'));
        // 에러가 발생해도 처리를 계속 진행
        continue;
      }
    }
  }
  
  /// 프레임 처리
  Future<ProcessedFrameResult> _processFrame(FrameData frameData) async {
    // 사용자 정의 처리 함수가 있으면 사용
    if (onProcessFrame != null) {
      return await onProcessFrame!(frameData);
    }
    
    // 기본 처리: CameraImage를 InputImage로 변환
    final inputImage = _convertToInputImage(frameData.cameraImage);
    
    // 이미지 바이트 추출 (선택적)
    final imageBytes = await _convertToImageBytes(frameData.cameraImage);
    
    return ProcessedFrameResult(
      frameId: frameData.frameId,
      processedAt: DateTime.now(),
      processedImageBytes: imageBytes,
      mlKitInputImage: inputImage,
      metadata: {
        'width': frameData.cameraImage.width,
        'height': frameData.cameraImage.height,
        'format': frameData.cameraImage.format.group.name,
        'timestamp': frameData.timestamp.toIso8601String(),
      },
    );
  }
  
  /// CameraImage를 InputImage로 변환 (ML Kit용)
  InputImage? _convertToInputImage(CameraImage cameraImage) {
    try {
      // 플랫폼별 이미지 회전 각도
      final camera = _cameraController?.description;
      if (camera == null) return null;
      
      final sensorOrientation = camera.sensorOrientation;
      InputImageRotation? rotation;
      
      // Android의 경우
      if (camera.lensDirection == CameraLensDirection.back) {
        rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
      } else {
        // 전면 카메라
        rotation = InputImageRotationValue.fromRawValue(
          (sensorOrientation + 180) % 360,
        );
      }
      
      if (rotation == null) return null;
      
      // 이미지 포맷 확인
      final format = InputImageFormatValue.fromRawValue(
        cameraImage.format.raw,
      );
      
      if (format == null) return null;
      
      // 평면 데이터 생성 - 각 평면의 크기를 올바르게 계산
      final planes = _buildPlaneMetadata(cameraImage);
      
      // InputImageData 생성
      final inputImageData = InputImageData(
        size: Size(
          cameraImage.width.toDouble(),
          cameraImage.height.toDouble(),
        ),
        imageRotation: rotation,
        inputImageFormat: format,
        planeData: planes,
      );
      
      // 바이트 데이터 결합
      final bytes = _concatenatePlanes(cameraImage.planes);
      
      return InputImage.fromBytes(
        bytes: bytes,
        inputImageData: inputImageData,
      );
      
    } catch (e) {
      _handleError(Exception('InputImage conversion failed: $e'));
      return null;
    }
  }
  
  /// 평면 메타데이터 생성 (YUV420 및 기타 포맷 지원)
  List<InputImagePlaneMetadata> _buildPlaneMetadata(CameraImage cameraImage) {
    final planes = <InputImagePlaneMetadata>[];
    
    for (int i = 0; i < cameraImage.planes.length; i++) {
      final plane = cameraImage.planes[i];
      int planeHeight;
      int planeWidth;
      
      // YUV420 포맷의 경우 평면별 크기가 다름
      if (cameraImage.format.group == ImageFormatGroup.yuv420) {
        if (i == 0) {
          // Y 평면: 원본 크기
          planeHeight = cameraImage.height;
          planeWidth = cameraImage.width;
        } else {
          // U, V 평면: 절반 크기
          planeHeight = cameraImage.height ~/ 2;
          planeWidth = cameraImage.width ~/ 2;
        }
      } else if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
        // BGRA8888 포맷: 단일 평면, 원본 크기
        planeHeight = cameraImage.height;
        planeWidth = cameraImage.width;
      } else {
        // 기타 포맷: 기본값 사용
        planeHeight = cameraImage.height;
        planeWidth = cameraImage.width;
      }
      
      planes.add(InputImagePlaneMetadata(
        bytesPerRow: plane.bytesPerRow,
        height: planeHeight,
        width: planeWidth,
      ));
    }
    
    return planes;
  }
  
  /// 평면 데이터 결합 (성능 최적화)
  Uint8List _concatenatePlanes(List<Plane> planes) {
    // 전체 크기 계산
    final totalSize = planes.fold<int>(
      0,
      (sum, plane) => sum + plane.bytes.length,
    );
    
    // 한 번에 메모리 할당
    final allBytes = Uint8List(totalSize);
    var offset = 0;
    
    // 각 평면 데이터를 복사
    for (final plane in planes) {
      allBytes.setRange(
        offset,
        offset + plane.bytes.length,
        plane.bytes,
      );
      offset += plane.bytes.length;
    }
    
    return allBytes;
  }
  
  /// CameraImage를 이미지 바이트로 변환
  Future<Uint8List?> _convertToImageBytes(CameraImage cameraImage) async {
    try {
      // YUV420 포맷을 RGB로 변환
      if (cameraImage.format.group == ImageFormatGroup.yuv420) {
        return _convertYUV420ToRGB(cameraImage);
      }
      
      // BGRA8888 포맷 (iOS) - 복사본 생성
      if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
        return Uint8List.fromList(cameraImage.planes[0].bytes);
      }
      
      return null;
    } catch (e) {
      _handleError(Exception('Image bytes conversion failed: $e'));
      return null;
    }
  }
  
  /// YUV420 to RGB 변환
  Uint8List _convertYUV420ToRGB(CameraImage cameraImage) {
    final int width = cameraImage.width;
    final int height = cameraImage.height;
    final int uvRowStride = cameraImage.planes[1].bytesPerRow;
    final int uvPixelStride = cameraImage.planes[1].bytesPerPixel ?? 1;
    
    // RGB 이미지 생성
    final image = img.Image(width: width, height: height);
    
    final yPlane = cameraImage.planes[0].bytes;
    final uPlane = cameraImage.planes[1].bytes;
    final vPlane = cameraImage.planes[2].bytes;
    
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int yIndex = y * width + x;
        final int uvIndex = (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;
        
        final int yValue = yPlane[yIndex];
        final int uValue = uPlane[uvIndex];
        final int vValue = vPlane[uvIndex];
        
        // YUV to RGB 변환 공식
        int r = (yValue + 1.402 * (vValue - 128)).round().clamp(0, 255);
        int g = (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128))
            .round()
            .clamp(0, 255);
        int b = (yValue + 1.772 * (uValue - 128)).round().clamp(0, 255);
        
        image.setPixelRgba(x, y, r, g, b, 255);
      }
    }
    
    // PNG 인코딩
    return Uint8List.fromList(img.encodePng(image));
  }
  
  /// 에러 처리
  void _handleError(Exception error) {
    // 스트림이 닫혀있지 않은 경우만 에러 전송
    if (!_errorStreamController.isClosed) {
      _errorStreamController.add(error);
    }
  }
}
