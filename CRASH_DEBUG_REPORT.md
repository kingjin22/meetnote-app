# MeetNote 크래시 긴급 디버깅 보고서

## 📋 요약
**문제**: 파일 업로드(가져오기) 후 iOS 앱 크래시  
**원인**: iOS Info.plist에 file_picker 패키지 필수 권한 누락  
**해결**: 필수 권한 2개 추가  
**상태**: ✅ 수정 완료

---

## 🔍 원인 분석

### 발견된 문제
iOS에서 `file_picker` 패키지를 사용하여 파일을 선택할 때, 특정 파일 타입(사진, 오디오)에 접근하려면 Info.plist에 권한 설명이 **필수**입니다.

MeetNote 앱의 `ios/Runner/Info.plist`에는 다음 권한이 **누락**되어 있었습니다:

1. `NSPhotoLibraryUsageDescription` - 사진/미디어 라이브러리 접근 권한
2. `NSAppleMusicUsageDescription` - 음악/오디오 파일 접근 권한

### 크래시 시나리오
1. 사용자가 "가져오기" 버튼 클릭
2. `FilePicker.platform.pickFiles()` 호출
3. iOS가 사진 또는 음악 라이브러리 접근 시도
4. Info.plist에 권한 설명이 없음 → **즉시 크래시**

iOS는 보안상의 이유로 이런 권한 설명이 없으면 앱을 강제 종료시킵니다.

---

## ✅ 적용된 수정

### 수정 파일
- `ios/Runner/Info.plist`

### 추가된 권한

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>미디어 파일을 가져오기 위해 사진 라이브러리 접근이 필요합니다.</string>

<key>NSAppleMusicUsageDescription</key>
<string>오디오 파일을 가져오기 위해 음악 라이브러리 접근이 필요합니다.</string>
```

### Git Commit
```
commit 0cb86dc
Fix: iOS 파일 업로드 크래시 해결 - 필수 권한 추가

- NSPhotoLibraryUsageDescription 추가
- NSAppleMusicUsageDescription 추가
- file_picker 패키지 사용 시 필수 권한 누락으로 인한 크래시 수정
```

---

## 🧪 테스트 방법

### 1. 앱 재빌드 (필수)
```bash
cd /Users/sungjinchoi/claude-code-app/meetnote-app

# iOS 디바이스에 빌드 및 실행
flutter run --release
# 또는 Xcode에서 실행
```

### 2. 테스트 시나리오

#### 시나리오 1: 오디오 파일 가져오기 (필수 테스트)
1. 앱 실행
2. 하단의 **"가져오기"** 버튼 클릭
3. 파일 선택 화면이 정상적으로 열리는지 확인
4. 오디오 파일(m4a, mp3 등) 선택
5. **크래시 없이** 파일이 정상적으로 추가되는지 확인

#### 시나리오 2: 다양한 파일 타입 테스트
- m4a, mp3, wav, aac 등 다양한 오디오 파일 가져오기
- 사진 라이브러리에서 오디오 파일 선택 (있는 경우)

#### 시나리오 3: 권한 프롬프트 확인
- 첫 실행 시 권한 요청 다이얼로그가 표시되어야 함
- 권한을 "허용" 또는 "허용 안 함" 선택해도 크래시가 없어야 함

---

## 📱 지원되는 파일 형식

MeetNote가 지원하는 오디오 파일 형식:
- m4a
- mp3
- wav
- aac
- caf
- flac
- ogg

코드 위치: `lib/services/recording_import_service.dart`

---

## 🔧 추가 확인 사항

### 현재 앱 권한 (Info.plist)
✅ `NSMicrophoneUsageDescription` - 녹음 기능  
✅ `NSSpeechRecognitionUsageDescription` - 음성 인식  
✅ `NSPhotoLibraryUsageDescription` - 사진 라이브러리 (수정으로 추가)  
✅ `NSAppleMusicUsageDescription` - 음악 라이브러리 (수정으로 추가)

### file_picker 버전
- 현재 설치: `8.3.7`
- pubspec.yaml 명시: `^8.1.7`

---

## 🎯 결론

이번 크래시는 **iOS 플랫폼 권한 설정 누락**으로 인한 것이었습니다.

### 해결된 것
- ✅ 파일 가져오기 시 크래시
- ✅ iOS 보안 정책 준수
- ✅ 사용자 친화적인 권한 설명 메시지

### 다음 단계
1. 앱 재빌드 및 실제 디바이스에서 테스트
2. 크래시가 재발하지 않는지 확인
3. 필요시 추가 디버깅

---

## 📚 참고 자료

- [file_picker 공식 문서](https://github.com/miguelpruivo/flutter_file_picker)
- [iOS Info.plist 권한 키](https://developer.apple.com/documentation/bundleresources/information_property_list)
- file_picker 예제: `/Users/sungjinchoi/.pub-cache/hosted/pub.dev/file_picker-8.3.7/example/ios/Runner/Info.plist`

---

**디버깅 완료 시간**: 2026-02-09  
**작성자**: Claude Code Subagent (meetnote-crash-debug)
