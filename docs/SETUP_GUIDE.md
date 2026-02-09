# MeetNote 설정 가이드

## 빠른 시작

### 1. API 키 설정

프로젝트 루트에 `.env` 파일을 생성하고 다음 내용을 추가하세요:

```env
# Anthropic Claude API (추천)
ANTHROPIC_API_KEY=sk-ant-api03-your-key-here

# OpenAI GPT API (선택사항)
OPENAI_API_KEY=sk-your-key-here

# 기본 LLM 제공자 (claude 또는 openai)
DEFAULT_LLM_PROVIDER=claude
```

### 2. API 키 발급 방법

#### Anthropic Claude (추천)

1. [Anthropic Console](https://console.anthropic.com/) 접속
2. 계정 생성 또는 로그인
3. 좌측 메뉴에서 "API Keys" 선택
4. "Create Key" 버튼 클릭
5. 키 이름 입력 후 생성
6. 생성된 키를 복사하여 `.env` 파일에 추가

**비용**: 
- Claude 3.5 Sonnet: $3/MTok (input), $15/MTok (output)
- 30분 회의 예상 비용: $0.10 - $0.20

#### OpenAI GPT (선택사항)

1. [OpenAI Platform](https://platform.openai.com/) 접속
2. 계정 생성 또는 로그인
3. 우측 상단 프로필 → "View API keys" 선택
4. "Create new secret key" 버튼 클릭
5. 키 이름 입력 후 생성
6. 생성된 키를 복사하여 `.env` 파일에 추가

**비용**:
- GPT-4o-mini: $0.150/MTok (input), $0.600/MTok (output)
- 30분 회의 예상 비용: $0.02 - $0.05

### 3. 패키지 설치

```bash
flutter pub get
```

### 4. 앱 실행

```bash
# iOS
flutter run -d ios

# Android
flutter run -d android

# macOS
flutter run -d macos
```

## 기능 테스트

### 1. 회의록 생성 테스트

1. 앱을 실행하고 새 녹음을 생성하거나 오디오 파일을 가져옵니다
2. 텍스트 변환을 완료합니다 (메뉴 → "텍스트 변환")
3. 변환이 완료되면 메뉴 → "회의록 생성" 선택
4. LLM 제공자 선택 (Claude 또는 GPT)
5. 예상 비용 확인 후 "회의록 생성" 버튼 터치
6. 생성 완료 후 회의록 확인

### 2. 짧은 테스트 시나리오

```
테스트용 회의 대본:
"오늘 회의는 신규 프로젝트 기획에 대해 논의했습니다.
참석자는 팀장, 개발자 두 명, 디자이너 한 명입니다.
주요 논의 사항은 프로젝트 일정과 기술 스택 선정이었습니다.
결정 사항은 다음과 같습니다.
첫째, Flutter를 사용하여 크로스 플랫폼 앱을 개발합니다.
둘째, 개발 기간은 3개월로 설정합니다.
액션 아이템은 개발자 김철수님이 11월 말까지 기술 문서를 작성하고,
디자이너 이영희님이 12월 초까지 UI 목업을 완성하기로 했습니다.
다음 회의는 다음 주 월요일 오후 2시입니다."
```

이 대본을 녹음하거나 텍스트 파일로 저장하여 테스트할 수 있습니다.

## 문제 해결

### API 키 관련 오류

**증상**: "API key not configured" 오류 발생

**해결 방법**:
1. `.env` 파일이 프로젝트 루트에 있는지 확인
2. API 키가 올바르게 입력되었는지 확인
3. 앱을 완전히 종료하고 재실행
4. `flutter clean && flutter pub get` 실행 후 재빌드

### 회의록 생성 실패

**증상**: "Failed to generate summary" 오류 발생

**해결 방법**:
1. 인터넷 연결 확인
2. API 키 유효성 확인
3. API 제공자의 서비스 상태 확인
   - [Anthropic Status](https://status.anthropic.com/)
   - [OpenAI Status](https://status.openai.com/)
4. 다른 LLM 제공자로 전환 시도
5. Rate limit 초과 여부 확인 (잠시 후 재시도)

### 텍스트 변환 실패

**증상**: 음성 텍스트 변환이 완료되지 않음

**해결 방법**:
1. 마이크 권한 확인
2. 녹음 파일 형식 확인 (M4A, WAV 등)
3. 음성 인식 언어 설정 확인
4. 기기의 음성 인식 서비스 활성화 확인

### 빌드 오류

**증상**: 앱 빌드 중 오류 발생

**해결 방법**:
```bash
# 1. 캐시 정리
flutter clean

# 2. 패키지 재설치
flutter pub get

# 3. 플랫폼별 정리 (필요시)
# iOS
cd ios && pod deintegrate && pod install && cd ..

# Android
cd android && ./gradlew clean && cd ..

# 4. 재빌드
flutter run
```

## 고급 설정

### 1. 커스텀 프롬프트

`lib/services/prompts/meeting_summary_prompt.dart` 파일을 수정하여 프롬프트를 커스터마이징할 수 있습니다.

### 2. LLM 모델 변경

`lib/services/llm_service.dart` 파일에서 모델을 변경할 수 있습니다:

```dart
// Claude 모델
static const String claudeModel = 'claude-3-5-sonnet-20241022';

// OpenAI 모델
static const String openaiModel = 'gpt-4o-mini';
```

### 3. 타임아웃 조정

긴 회의록 생성 시 타임아웃이 발생하면 다음을 조정하세요:

```dart
static const Duration timeout = Duration(seconds: 60);
```

### 4. 재시도 횟수 조정

```dart
static const int maxRetries = 2;
```

## 추가 리소스

- [Flutter 공식 문서](https://flutter.dev/docs)
- [Anthropic API 문서](https://docs.anthropic.com/)
- [OpenAI API 문서](https://platform.openai.com/docs/)
- [프로젝트 문서](./AI_MEETING_SUMMARY.md)

## 지원

문제가 발생하거나 기능 제안이 있으시면:
1. GitHub Issues에 등록
2. 문서를 참고하여 자체 해결 시도
3. API 제공자 지원 팀 문의

## 라이선스

이 프로젝트는 MIT 라이선스를 따릅니다.
