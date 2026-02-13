# FirebaseChatting-iOS

기존에 Flutter로 운영하던 채팅 시스템을 iOS(SwiftUI + TCA)로 재구현한 프로젝트입니다.
아키텍처 개선과 함께 **Claude Code를 활용한 테스트 코드 자동화**를 적용하여, 단위/통합/UI 테스트를 체계적으로 구축했습니다.

## Tech Stack

### iOS

| 영역 | 기술 |
|------|------|
| UI | SwiftUI |
| Architecture | [TCA (The Composable Architecture)](https://github.com/pointfreeco/swift-composable-architecture) 1.23.1 |
| Navigation | Stack-based (TCA 1.7+ NavigationStack) |
| Async | Swift Concurrency (async/await), Combine |
| Local DB | SwiftData |
| Image Cache | Kingfisher |

### Backend

| 영역 | 기술 |
|------|------|
| Auth | Firebase Auth (Google Sign-In) |
| Database | Cloud Firestore |
| Storage | Firebase Storage |
| Serverless | Firebase Cloud Functions (TypeScript) |

## Getting Started

### 1. Backend 설정

Firebase Cloud Functions 배포 등 백엔드 사전 작업이 필요합니다.

> [Backend/README.md](Backend/README.md) 참고

### 2. Firebase 연동

1. [Firebase Console](https://console.firebase.google.com/)에서 프로젝트 생성
2. iOS 앱 등록 (Bundle ID 입력)
3. `GoogleService-Info.plist` 다운로드 후 Xcode 프로젝트 루트에 추가
4. Authentication > Google 로그인 활성화
5. Firestore Database / Storage 생성

### 3. 개발 환경

| 요구사항 | 버전 |
|----------|------|
| iOS | 26.0+ |
| Xcode | 26.1+ |
| Swift | 6.2.1 |

```bash
git clone https://github.com/sangjin-hash/FirebaseChatting-iOS.git
open FirebaseChatting.xcodeproj
```

> Xcode에서 SPM 의존성이 자동으로 resolve됩니다.

## Architecture

TCA (The Composable Architecture)를 채택하여 **단방향 데이터 흐름**과 **의존성 주입 기반 테스트 용이성**을 확보했습니다.

<p align="center">
  <img src="images/TCA.png" alt="TCA Architecture" width="700" />
</p>

| 레이어 | 역할 |
|--------|------|
| **Presentation** | TCA Feature (State, Action, Reducer) + SwiftUI View |
| **Data** | Model, Repository (Protocol + Impl), DataSource, DTO |
| **Core** | TCA Dependencies, 공통 유틸, 확장 |

```
FirebaseChatting/
├── App/                    # 앱 진입점 (AppDelegate, App)
├── Core/                   # Dependencies, Extensions, Constants
├── Data/                   # Model, Repository, DataSource, DTO
├── Presentation/           # Feature (Reducer + View), Components
└── Resources/              # Assets, Fonts
```

## Testing

Claude Code를 활용하여 **단위 166개, 통합 22개, UI 7개** 총 195개의 테스트를 자동화했습니다.

| 구분 | 테스트 수 | 범위 | 상세 |
|------|----------|------|------|
| Unit | 166 | 9개 Feature Reducer 로직 | [Features/README.md](FirebaseChattingTests/Features/README.md) |
| Integration | 22 | Auth, ChatList, ChatRoom 다단계 흐름 | [Integration/README.md](FirebaseChattingTests/Integration/README.md) |
| UI (XCUITest) | 7 | 6개 시나리오, Page Object 패턴 | [UITests/README.md](FirebaseChattingUITests/README.md) |

### 테스트 실행

```bash
# 단위 + 통합 테스트
xcodebuild test \
  -project FirebaseChatting.xcodeproj \
  -scheme FirebaseChatting \
  -destination 'platform=iOS Simulator,id=1D6788B6-25B3-48E5-84A4-1FC4942356D5' \
  -parallel-testing-enabled NO

# UI 테스트
xcodebuild test \
  -project FirebaseChatting.xcodeproj \
  -scheme FirebaseChattingUITests \
  -destination 'platform=iOS Simulator,id=1D6788B6-25B3-48E5-84A4-1FC4942356D5'
```
