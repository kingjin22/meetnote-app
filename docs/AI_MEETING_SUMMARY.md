# AI 회의록 자동 정리 기능

## 개요

MeetNote 앱에 AI 기반 회의록 자동 정리 기능이 추가되었습니다. 음성 텍스트 변환이 완료된 녹음에 대해 LLM을 사용하여 구조화된 회의록을 자동으로 생성할 수 있습니다.

## 주요 기능

### 1. LLM 통합
- **Claude API** (Anthropic) - 기본 제공자
- **OpenAI GPT API** - 선택적 지원
- 사용자가 원하는 LLM 제공자를 선택 가능

### 2. 회의록 구조
생성된 회의록은 다음 섹션으로 구성됩니다:
- **회의 개요**: 주제, 참석자, 일시 등
- **주요 논의 사항**: 회의에서 논의된 핵심 내용
- **결정 사항**: 회의에서 결정된 사항들
- **액션 아이템**: 담당자와 기한이 포함된 할 일 목록
- **다음 회의 일정**: 예정된 다음 회의 정보

### 3. UI/UX
- 텍스트 변환 완료 후 팝업 메뉴에 "회의록 생성" 옵션 표시
- LLM 제공자 선택 (Claude/GPT)
- 예상 비용 및 토큰 수 표시
- 생성 진행 상태 표시
- 생성된 회의록 뷰어
- 편집 기능 (향후 구현)
- 클립보드 복사 기능

## 설정 방법

### 1. API 키 설정

`.env` 파일에 API 키를 추가하세요:

```env
# Anthropic Claude API
ANTHROPIC_API_KEY=sk-ant-api03-...

# OpenAI GPT API (선택사항)
OPENAI_API_KEY=sk-...

# 기본 제공자 선택 (claude 또는 openai)
DEFAULT_LLM_PROVIDER=claude
```

### 2. API 키 발급

#### Anthropic Claude
1. [Anthropic Console](https://console.anthropic.com/) 접속
2. API Keys 메뉴에서 새 키 생성
3. 생성된 키를 `.env` 파일에 추가

#### OpenAI (선택사항)
1. [OpenAI Platform](https://platform.openai.com/) 접속
2. API Keys 메뉴에서 새 키 생성
3. 생성된 키를 `.env` 파일에 추가

## 사용 방법

### 1. 회의록 생성

1. 홈 화면에서 텍스트 변환이 완료된 녹음 선택
2. 우측 상단 메뉴(⋮) 터치
3. "회의록 생성" 선택
4. 원하는 LLM 제공자 선택 (Claude/GPT)
5. 예상 비용 확인 후 "회의록 생성" 버튼 터치
6. 생성 완료 후 회의록 확인

### 2. 회의록 보기

생성된 회의록은 다음 형식으로 표시됩니다:
- 📋 회의 개요
- 💬 주요 논의 사항
- ✅ 결정 사항
- 📌 액션 아이템 (담당자, 기한 포함)
- 📅 다음 회의 일정

### 3. 회의록 복사

회의록 화면에서 우측 상단의 복사(📋) 버튼을 터치하면 전체 회의록이 클립보드에 복사됩니다.

## 비용 정보

### 예상 비용 (30분 회의 기준)

#### Claude Sonnet
- 입력: $3 / 1M 토큰
- 출력: $15 / 1M 토큰
- **예상 비용**: $0.10 - $0.20

#### GPT-4o-mini
- 입력: $0.150 / 1M 토큰
- 출력: $0.600 / 1M 토큰
- **예상 비용**: $0.02 - $0.05

> 💡 **팁**: Claude는 품질이 우수하고, GPT-4o-mini는 비용이 저렴합니다.

## 기술 상세

### 아키텍처

```
┌─────────────────┐
│  Recording      │
│  (텍스트 변환    │
│   완료)         │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ MeetingSummary  │
│ Screen          │
│ - Provider 선택 │
│ - 비용 추정     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   LLMService    │
│ - Claude API    │
│ - OpenAI API    │
│ - Retry Logic   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ MeetingSummary  │
│ Model           │
│ - JSON 저장     │
└─────────────────┘
```

### 주요 파일

```
lib/
├── models/
│   └── meeting_summary.dart          # 회의록 데이터 모델
├── services/
│   ├── llm_service.dart               # LLM API 통합
│   └── prompts/
│       └── meeting_summary_prompt.dart # 프롬프트 템플릿
└── screens/
    └── meeting_summary_screen.dart    # 회의록 UI
```

### 프롬프트 엔지니어링

회의록 생성에 사용되는 프롬프트는 다음과 같이 구성되어 있습니다:

```dart
// System Prompt
당신은 전문 회의록 작성자입니다.

// User Prompt
아래 회의 내용을 분석하여 구조화된 회의록을 작성해주세요.
[회의 텍스트]
{transcribed_text}

다음 JSON 형식으로 정리해주세요:
{
  "overview": "...",
  "discussions": [...],
  "decisions": [...],
  "actionItems": [...],
  "nextMeeting": "..."
}
```

## 에러 처리

### 일반적인 오류

| 오류 | 원인 | 해결 방법 |
|------|------|-----------|
| "API key not configured" | API 키 미설정 | `.env` 파일에 API 키 추가 |
| "Failed to parse LLM response" | 잘못된 응답 형식 | 재시도 또는 다른 LLM 사용 |
| "Timeout" | 네트워크 지연 | 재시도 |
| "API request failed: 401" | 잘못된 API 키 | API 키 확인 및 재설정 |
| "API request failed: 429" | Rate limit 초과 | 잠시 후 재시도 |

### 자동 재시도

- 최대 재시도 횟수: 2회
- 재시도 간격: Exponential backoff (2초, 4초)

## 향후 개선 사항

- [ ] 회의록 편집 기능
- [ ] PDF/텍스트 파일 내보내기
- [ ] 커스텀 프롬프트 템플릿
- [ ] 회의록 히스토리 검색
- [ ] 회의 참석자 자동 인식
- [ ] 다국어 지원
- [ ] 긴 회의 자동 청크 분할
- [ ] 로컬 LLM 지원 (Ollama 등)

## 라이선스

이 기능은 MeetNote 앱의 일부로 제공됩니다.

## 문의

기능 관련 문의사항이나 버그 리포트는 이슈 트래커에 등록해주세요.
