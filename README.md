# Realtime Stream Processor

Camera 패키지와 Google ML Kit을 사용한 실시간 스트리밍 프레임 분할 및 처리 클래스

## 📋 개요

이 라이브러리는 카메라로부터 실시간으로 프레임을 수신하고, 내부 큐를 통해 비동기적으로 처리하는 효율적인 스트림 프로세서를 제공합니다.

## ✨ 주요 기능

- ✅ **실시간 카메라 스트리밍**: Camera 패키지를 사용한 프레임 캡처
- ✅ **입력 큐 관리**: 프레임을 큐에 저장하고 순차적으로 처리
- ✅ **ML Kit 통합**: Google ML Kit InputImage 자동 변환
- ✅ **비동기 프레임 처리**: 백그라운드에서 프레임 처리
- ✅ **큐 오버플로우 방지**: 최대 큐 크기 설정 및 자동 프레임 드롭
- ✅ **일시정지/재개**: 스트림 제어 기능
- ✅ **통계 모니터링**: FPS, 처리된 프레임, 드롭된 프레임 등
- ✅ **에러 핸들링**: 별도의 에러 스트림 제공
- ✅ **커스터마이징**: 사용자 정의 프레임 처리 함수 지원

## 📦 설치

`pubspec.yaml`에 다음 의존성을 추가하세요:

```yaml
dependencies:
  camera: ^0.10.5+7
  google_mlkit_commons: ^0.6.0
  image: ^4.1.3
```

## 🚀 빠른 시작

### 1. 기본 사용법

```dart
import 'package:realtime_stream_processor/realtime_stream_processor.dart';

// 프로세서 생성
final processor = RealtimeStreamProcessor(
  maxQueueSize: 10, // 최대 큐 크기
);

// 카메라 초기화
await processor.initializeCamera(
  resolutionPreset: ResolutionPreset.medium,
);

// 스트리밍 시작
await processor.startStreaming();

// 결과 수신
processor.outputStream.listen((result) {
  print('Processed frame ${result.frameId}');
  print('Metadata: ${result.metadata}');
  
  // ML Kit InputImage 사용
  if (result.mlKitInputImage != null) {
    // ML Kit 모델로 처리
    // await faceDetector.processImage(result.mlKitInputImage!);
  }
});

// 에러 처리
processor.errorStream.listen((error) {
  print('Error: $error');
});

// 스트리밍 중지
await processor.stopStreaming();

// 리소스 정리
await processor.dispose();
```

### 2. 커스텀 프레임 처리

```dart
final processor = RealtimeStreamProcessor(
  maxQueueSize: 10,
  onProcessFrame: (frameData) async {
    // 커스텀 처리 로직
    final cameraImage = frameData.cameraImage;
    
    // 예: 얼굴 인식, 객체 감지, 세그멘테이션 등
    // final faces = await faceDetector.processImage(inputImage);
    
    return ProcessedFrameResult(
      frameId: frameData.frameId,
      processedAt: DateTime.now(),
      metadata: {
        'width': cameraImage.width,
        'height': cameraImage.height,
        'customData': 'your_data',
      },
    );
  },
);
```

### 3. 스트림 제어

```dart
// 일시정지
processor.pause();

// 재개
processor.resume();

// 중지
await processor.stopStreaming();

// 통계 확인
final stats = processor.statistics;
print('FPS: ${stats['fps']}');
print('Processed: ${stats['processedFrames']}');
print('Dropped: ${stats['droppedFrames']}');
```

## 🏗️ 아키텍처

```
┌─────────────┐
│   Camera    │
└──────┬──────┘
       │ Stream
       ▼
┌─────────────┐
│ Input Queue │ ◄── maxQueueSize로 제한
└──────┬──────┘
       │ Pop
       ▼
┌─────────────┐
│  Process    │ ◄── onProcessFrame 콜백
│   Frame     │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ Output      │
│ Stream      │ ──► outputStream.listen()
└─────────────┘
```

## 📊 클래스 구조

### RealtimeStreamProcessor

주요 프로세서 클래스

#### 생성자

```dart
RealtimeStreamProcessor({
  int maxQueueSize = 10,
  Future<ProcessedFrameResult> Function(FrameData)? onProcessFrame,
})
```

#### 주요 메서드

| 메서드 | 설명 |
|--------|------|
| `initializeCamera()` | 카메라 초기화 |
| `startStreaming()` | 스트리밍 시작 |
| `stopStreaming()` | 스트리밍 중지 |
| `pause()` | 일시정지 |
| `resume()` | 재개 |
| `dispose()` | 리소스 정리 |
| `enqueueFrame()` | 수동 프레임 추가 (테스트용) |

#### 주요 속성

| 속성 | 타입 | 설명 |
|------|------|------|
| `outputStream` | `Stream<ProcessedFrameResult>` | 처리된 프레임 스트림 |
| `errorStream` | `Stream<Exception>` | 에러 스트림 |
| `queueSize` | `int` | 현재 큐 크기 |
| `isProcessing` | `bool` | 처리 중 여부 |
| `isPaused` | `bool` | 일시정지 상태 |
| `statistics` | `Map<String, dynamic>` | 통계 정보 |

### FrameData

입력 프레임 데이터

```dart
class FrameData {
  final CameraImage cameraImage;
  final DateTime timestamp;
  final int frameId;
}
```

### ProcessedFrameResult

처리된 프레임 결과

```dart
class ProcessedFrameResult {
  final int frameId;
  final DateTime processedAt;
  final Uint8List? processedImageBytes;
  final Map<String, dynamic> metadata;
  final InputImage? mlKitInputImage;
}
```

## 🎯 사용 사례

### 1. 실시간 얼굴 인식

```dart
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

final faceDetector = FaceDetector(
  options: FaceDetectorOptions(enableLandmarks: true),
);

final processor = RealtimeStreamProcessor(
  onProcessFrame: (frameData) async {
    final inputImage = _convertToInputImage(frameData.cameraImage);
    final faces = await faceDetector.processImage(inputImage);
    
    return ProcessedFrameResult(
      frameId: frameData.frameId,
      processedAt: DateTime.now(),
      metadata: {
        'faceCount': faces.length,
        'faces': faces.map((f) => f.boundingBox).toList(),
      },
      mlKitInputImage: inputImage,
    );
  },
);
```

### 2. 실시간 텍스트 인식

```dart
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

final textRecognizer = TextRecognizer();

final processor = RealtimeStreamProcessor(
  onProcessFrame: (frameData) async {
    final inputImage = _convertToInputImage(frameData.cameraImage);
    final recognizedText = await textRecognizer.processImage(inputImage);
    
    return ProcessedFrameResult(
      frameId: frameData.frameId,
      processedAt: DateTime.now(),
      metadata: {
        'text': recognizedText.text,
        'blocks': recognizedText.blocks.length,
      },
      mlKitInputImage: inputImage,
    );
  },
);
```

### 3. 실시간 객체 감지

```dart
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

final objectDetector = ObjectDetector(
  options: ObjectDetectorOptions(mode: DetectionMode.stream),
);

final processor = RealtimeStreamProcessor(
  onProcessFrame: (frameData) async {
    final inputImage = _convertToInputImage(frameData.cameraImage);
    final objects = await objectDetector.processImage(inputImage);
    
    return ProcessedFrameResult(
      frameId: frameData.frameId,
      processedAt: DateTime.now(),
      metadata: {
        'objectCount': objects.length,
        'objects': objects.map((o) => o.labels).toList(),
      },
      mlKitInputImage: inputImage,
    );
  },
);
```

## ⚙️ 설정 옵션

### 카메라 설정

```dart
await processor.initializeCamera(
  cameraDescription: cameras[0],  // 특정 카메라 선택
  resolutionPreset: ResolutionPreset.high,  // 해상도
  enableAudio: false,  // 오디오 비활성화
);
```

### 큐 크기 조정

```dart
// 큐 크기가 클수록 더 많은 프레임을 버퍼링
// 하지만 메모리 사용량 증가 및 지연 시간 증가
final processor = RealtimeStreamProcessor(
  maxQueueSize: 20,  // 기본값: 10
);
```

## 📈 성능 최적화

### 1. 적절한 해상도 선택

```dart
// 낮은 해상도 = 빠른 처리
ResolutionPreset.low      // 352x288
ResolutionPreset.medium   // 720x480
ResolutionPreset.high     // 1280x720
ResolutionPreset.veryHigh // 1920x1080
```

### 2. 큐 크기 조절

- **작은 큐 (5-10)**: 낮은 지연, 더 많은 프레임 드롭
- **큰 큐 (20-30)**: 높은 지연, 적은 프레임 드롭

### 3. 처리 시간 모니터링

```dart
processor.outputStream.listen((result) {
  final processingTime = result.processedAt.difference(
    result.metadata['timestamp'] as DateTime,
  );
  print('Processing time: ${processingTime.inMilliseconds}ms');
});
```

## 🐛 문제 해결

### 카메라가 초기화되지 않음

```dart
// 권한 확인
// AndroidManifest.xml에 추가
<uses-permission android:name="android.permission.CAMERA"/>

// iOS Info.plist에 추가
<key>NSCameraUsageDescription</key>
<string>카메라 접근이 필요합니다</string>
```

### 프레임이 과도하게 드롭됨

```dart
// 1. 해상도 낮추기
ResolutionPreset.low

// 2. 큐 크기 증가
maxQueueSize: 20

// 3. 처리 로직 최적화
// 무거운 연산은 isolate로 분리
```

### 메모리 부족

```dart
// 1. 큐 크기 감소
maxQueueSize: 5

// 2. 정기적으로 dispose() 호출
await processor.dispose();
processor = RealtimeStreamProcessor(...);
```

## 📄 라이선스

MIT License

## 👨‍💻 개발자

GenSpark AI Developer

## 🙏 감사의 말

- Flutter Camera Package
- Google ML Kit
- Dart Image Package
