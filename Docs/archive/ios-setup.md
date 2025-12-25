# iOS 프로젝트 초기 설정 가이드

## 1. Xcode 프로젝트 확인

현재 프로젝트: `VoiceQuiz.xcodeproj`

```bash
cd /Users/eunyeong/development/projects/VoiceQuiz
open VoiceQuiz.xcodeproj
```

## 2. Info.plist 권한 설정

### 필수: 마이크 권한

Xcode에서 `VoiceQuiz/Info.plist` 파일을 열고 다음 항목을 추가:

**방법 1: Xcode UI 사용**
1. Info.plist 파일 선택
2. `+` 버튼 클릭
3. "Privacy - Microphone Usage Description" 선택
4. 값 입력: `"VoiceQuiz needs access to your microphone to play the voice quiz game."`

**방법 2: 직접 편집**

```xml
<key>NSMicrophoneUsageDescription</key>
<string>VoiceQuiz needs access to your microphone to play the voice quiz game.</string>
```

### 선택적: 카메라 권한 (Phase 5 이후)

비디오 기능이 추가될 경우에만 필요:

```xml
<key>NSCameraUsageDescription</key>
<string>VoiceQuiz needs access to your camera for video features.</string>
```

**MVP에서는 추가하지 않음** ⚠️

## 3. GoogleWebRTC SDK 추가

### 방법 A: CocoaPods (권장)

**1. Podfile 생성**

프로젝트 루트에 `Podfile` 생성:

```ruby
platform :ios, '16.0'

target 'VoiceQuiz' do
  use_frameworks!

  # GoogleWebRTC
  pod 'GoogleWebRTC', '~> 1.1'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
    end
  end
end
```

**2. 설치**

```bash
cd /Users/eunyeong/development/projects/VoiceQuiz
pod install
```

**3. Workspace 사용**

설치 후 `.xcworkspace` 파일을 사용:

```bash
open VoiceQuiz.xcworkspace
```

⚠️ **주의**: CocoaPods 설치 후에는 `.xcodeproj`가 아닌 `.xcworkspace`를 사용해야 합니다.

### 방법 B: Swift Package Manager (SPM)

**1. Xcode에서 Package 추가**
1. Xcode 메뉴: `File` → `Add Packages...`
2. URL 입력: `https://github.com/stasel/WebRTC`
3. Dependency Rule: "Up to Next Major Version" (1.0.0)
4. "Add Package" 클릭

**2. Target에 추가**
- `VoiceQuiz` target 선택
- "Frameworks, Libraries, and Embedded Content"에서 `WebRTC` 추가

### 비교

| 항목 | CocoaPods | SPM |
|------|-----------|-----|
| 설정 난이도 | 쉬움 | 쉬움 |
| 빌드 속도 | 보통 | 빠름 |
| 안정성 | 높음 (공식 지원) | 보통 (커뮤니티) |
| 권장 | ✅ 권장 | 대안 |

## 4. 디렉토리 구조 생성

Xcode에서 다음 그룹(폴더) 생성:

```
VoiceQuiz/
├── VoiceQuizApp.swift
├── ContentView.swift
├── UI/
│   └── (Views will be added here)
├── ViewModels/
│   └── (ViewModels will be added here)
├── Game/
│   └── (Game logic will be added here)
├── Realtime/
│   └── (WebRTC code will be added here)
├── Audio/
│   └── (Audio session code will be added here)
├── Data/
│   ├── Models/
│   │   └── (Data models will be added here)
│   ├── Persistence/
│   │   └── (Storage code will be added here)
│   └── words.json
└── Utils/
    └── (Utility code will be added here)
```

**그룹 생성 방법:**
1. Xcode Navigator에서 `VoiceQuiz` 폴더 우클릭
2. "New Group" 선택
3. 그룹 이름 입력

## 5. Build Settings 확인

### Minimum iOS Version

1. Project 설정 열기
2. "VoiceQuiz" target 선택
3. "General" 탭
4. "Minimum Deployments" → iOS 16.0 이상

### Swift Language Version

1. "Build Settings" 탭
2. "Swift Language Version" 검색
3. Swift 5.9 이상 확인

### Other Settings

- **Enable Bitcode**: NO (WebRTC는 Bitcode를 지원하지 않음)
- **Allow App Extension API Only**: NO

## 6. 마이크 권한 테스트

간단한 테스트 코드 (ContentView.swift):

```swift
import SwiftUI
import AVFoundation

struct ContentView: View {
    @State private var permissionStatus = "Unknown"

    var body: some View {
        VStack(spacing: 20) {
            Text("Microphone Permission Test")
                .font(.headline)

            Text("Status: \(permissionStatus)")

            Button("Request Permission") {
                requestMicrophonePermission()
            }
        }
        .padding()
    }

    func requestMicrophonePermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                permissionStatus = granted ? "Granted ✅" : "Denied ❌"
            }
        }
    }
}
```

**테스트 방법:**
1. 앱 실행
2. "Request Permission" 버튼 클릭
3. 권한 요청 팝업에서 "Allow" 선택
4. "Status: Granted ✅" 확인

## 7. Simulator vs 실제 기기

### Simulator
- ✅ UI 개발
- ✅ 기본 로직 테스트
- ✅ 마이크 사용 가능 (Mac 마이크 사용)
- ⚠️ WebRTC 성능은 실제 기기와 다를 수 있음

### 실제 기기
- ✅ 실제 음성 품질 테스트
- ✅ WebRTC 연결 안정성 확인
- ✅ 네트워크 환경 테스트
- ✅ 최종 QA

**권장:** 초기 개발은 Simulator, 음성 테스트는 실제 기기

## 8. .gitignore 확인

프로젝트 루트에 `.gitignore` 파일이 있는지 확인:

```gitignore
# Xcode
*.xcuserstate
*.xcuserdatad
xcuserdata/
DerivedData/

# CocoaPods
Pods/
*.xcworkspace

# SPM
.swiftpm/
.build/

# macOS
.DS_Store

# Environment
.env
```

## 9. 초기 빌드 테스트

1. Xcode에서 `Cmd+B` (Build)
2. 에러 없이 빌드 성공 확인
3. Simulator 선택 (예: iPhone 15 Pro)
4. `Cmd+R` (Run)
5. 앱이 정상 실행되는지 확인

## 10. 다음 단계

Phase 0 완료 후:
- [ ] Backend 서버 배포
- [ ] words.json 파일 추가
- [ ] Data Models 정의 (Word, Category 등)

Phase 1 시작:
- [ ] GoogleWebRTC 연동 시작
- [ ] RealtimeWebRTCClient.swift 구현

---

## 문제 해결

### CocoaPods 설치 안 됨

```bash
# CocoaPods 설치
sudo gem install cocoapods

# 버전 확인
pod --version
```

### Build 실패: WebRTC not found

- CocoaPods 사용 시: `.xcworkspace` 파일 사용 확인
- SPM 사용 시: Package Dependencies 다시 추가

### 마이크 권한 요청이 안 나옴

- Info.plist에 `NSMicrophoneUsageDescription` 확인
- 앱 삭제 후 재설치 (권한 캐시 초기화)
- 설정 앱에서 수동으로 권한 확인

### Simulator에서 마이크 안 됨

- Mac의 시스템 환경설정 → 개인정보 보호 → 마이크
- Simulator 또는 Xcode에 마이크 권한 부여 확인

---

**작성일**: 2025-12-19
**Phase**: Phase 0 - iOS Project Setup
