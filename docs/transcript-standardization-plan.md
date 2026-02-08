# Transcript 저장 표준화 작업 계획

## 현재 상태 분석

### 문제점
1. **상태 비영속성**: 트랜스크립션 진행 상태가 메모리에만 존재 (`_transcribingIds` Set)
2. **상태 표시 부족**: pending/success/failed 상태를 명확히 구분하지 않음
3. **재시도 로직 없음**: 실패 시 수동으로 재시도해야 함
4. **앱 재시작 시 손실**: 진행 중이던 작업 정보가 사라짐

### 현재 구조
- **모델**: `Recording` 클래스 (transcriptText, summaryText 필드 존재)
- **저장소**: `LocalRecordingRepository` (SharedPreferences 사용)
- **서비스**: `TranscriptionService` (iOS 네이티브 API 호출)
- **UI**: `HomeScreen` (수동 트리거, 진행 중 표시만)

## 설계

### 1. Recording 모델 표준화

```dart
enum TranscriptionStatus {
  none,       // 트랜스크립션 미실시
  pending,    // 진행 중
  success,    // 성공
  failed,     // 실패
}

class Recording {
  final String id;
  final String filePath;
  final DateTime createdAt;
  final Duration duration;
  
  // 트랜스크립션 관련 필드
  final String? transcriptText;
  final String? summaryText;
  final TranscriptionStatus transcriptionStatus;
  final String? transcriptionError;
  final int transcriptionRetryCount;
  final DateTime? transcriptionCompletedAt;
  
  // ... 생성자 및 메서드
}
```

### 2. Repository 영속성 구현

- `toMap()` / `fromMap()` 메서드에 새 필드 추가
- 기존 데이터 마이그레이션 로직 (기본값 설정)

### 3. UI 상태 표시

```
[아이콘] 제목
        날짜 • 상태
        
상태별 표시:
- none: 일반 재생 아이콘
- pending: 로딩 스피너 + "변환 중..."
- success: 체크 아이콘 + "변환 완료"
- failed: 경고 아이콘 + "변환 실패" (재시도 버튼)
```

### 4. 재시도 로직

```dart
class TranscriptionService {
  Future<String> transcribeFileWithRetry(
    String filePath, {
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 2),
  }) async {
    // 지수 백오프로 재시도
  }
}
```

### 5. 테스트

- `test/models/recording_test.dart`: 모델 직렬화/역직렬화
- `test/repositories/recording_repository_test.dart`: 상태 영속성
- 시뮬레이터 통합 테스트

## 구현 순서

1. ✅ 설계 문서 작성
2. ⬜ TranscriptionStatus enum 추가
3. ⬜ Recording 모델 필드 추가 및 마이그레이션
4. ⬜ Repository 업데이트 로직 구현
5. ⬜ TranscriptionService 재시도 로직 추가
6. ⬜ UI 상태 표시 개선
7. ⬜ 테스트 작성
8. ⬜ 시뮬레이터 테스트
9. ⬜ 커밋

## 성공 기준

- [ ] 트랜스크립션 상태가 앱 재시작 후에도 유지됨
- [ ] UI에서 pending/success/failed 상태를 명확히 구분
- [ ] 실패 시 자동 재시도 (최대 3회)
- [ ] 기존 데이터 마이그레이션 정상 작동
- [ ] 테스트 통과
- [ ] 시뮬레이터에서 정상 동작 확인
