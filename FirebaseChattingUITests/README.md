# UI Tests (FirebaseChattingUITests/)

UI 테스트는 XCUITest를 사용하여 **실제 앱 화면**에서의 사용자 인터랙션을 검증합니다.
모든 외부 의존성(Firebase, Storage 등)은 Mock으로 대체되며, 시나리오 기반으로 테스트 데이터가 주입됩니다.

---

## 테스트 커버리지

### 요약

| 영역 | 테스트 수 | 파일 |
|------|----------|------|
| ChatList 기본 흐름 | 1 | `Tests/ChatListBasicUITests.swift` |
| ChatRoom 메시지 (Unread/페이지네이션) | 1 | `Tests/ChatRoomMessageUITests.swift` |
| ChatRoom 메시지 전송 | 1 | `Tests/ChatRoomSendUITests.swift` |
| ChatRoom 그룹 채팅 | 2 | `Tests/ChatRoomGroupUITests.swift` |
| ChatRoom 미디어 전송 | 1 | `Tests/ChatRoomMediaSendUITests.swift` |
| ChatRoom 미디어 뷰어 | 1 | `Tests/ChatRoomMediaViewerUITests.swift` |
| **합계** | **7** | **6개 파일** |

### 기능별 커버리지 매핑

| 앱 기능 | UI 테스트 커버리지 | 비고 |
|---------|-------------------|------|
| 채팅 목록 로드/네비게이션 | ✅ Scenario 1 | 기본 흐름 |
| 채팅방 메시지 표시/스크롤 | ✅ Scenario 2 | Unread divider + 페이지네이션 |
| 텍스트 메시지 전송 | ✅ Scenario 3 | 전송 → ChatList 반영 |
| 그룹 채팅 생성 | ✅ Scenario 4A | 친구 선택 → 채팅방 생성 |
| 그룹 채팅 Drawer | ✅ Scenario 4B | 멤버 표시 |
| 미디어 Picker | ✅ Scenario 5 | 모달 표시/닫기 |
| 미디어 뷰어 (이미지/비디오) | ✅ Scenario 6 | 전체화면 뷰어 인터랙션 |
| 인증 (로그인/로그아웃) | ❌ | 자동 로그인 mock으로 우회 |
| Home (친구 목록) | ❌ | 단위/통합 테스트에서 커버 |
| Search (사용자 검색) | ❌ | 단위 테스트에서 커버 |
| 스와이프 채팅방 나가기 | ❌ | 단위/통합 테스트에서 커버 |
| 1:1 채팅 재입장 | ❌ | 통합 테스트에서 커버 |

---

## 시나리오 상세

### Scenario 1: 채팅 목록 기본 흐름

**파일**: `Tests/ChatListBasicUITests.swift`
**시나리오 키**: `chatListBasic`

```
앱 실행 → 채팅 탭 이동 → 채팅방 2개 표시 확인
→ 채팅방 탭 → ChatRoom 진입 → 뒤로가기 → 목록 유지 확인
```

| 단계 | 검증 |
|------|------|
| 채팅 탭 진입 | 채팅방 2개 렌더링 |
| 채팅방 탭 | ChatRoom 화면 전환 |
| 뒤로가기 | ChatList 복원 (2개 유지) |

### Scenario 2: Unread Divider + 페이지네이션

**파일**: `Tests/ChatRoomMessageUITests.swift`
**시나리오 키**: `chatRoomUnreadDivider`

```
채팅방 진입 → 캐시 10개 + 서버 30개 로드 → Unread Divider 확인
→ 상단 스크롤 (메시지 #1 확인) → 하단 스크롤 → 추가 로드 20개
→ "새 메시지 #60" 확인
```

| 단계 | 데이터 |
|------|--------|
| 캐시 로드 | 메시지 1~10 (10개) |
| 1차 fetch | 메시지 11~40 (30개, unread) |
| 2차 fetch | 메시지 41~60 (20개, newer) |
| Unread Divider | 메시지 #10 이후 배치 |

### Scenario 3: 메시지 전송

**파일**: `Tests/ChatRoomSendUITests.swift`
**시나리오 키**: `chatRoomSend`

```
채팅방 진입 → "안녕하세요" 입력 → 전송
→ 입력창 초기화 확인 → 메시지 화면 표시 확인
→ 뒤로가기 → ChatList에서 lastMessage "안녕하세요" 확인
```

| 단계 | 검증 |
|------|------|
| 메시지 전송 | 입력창 clear |
| ChatRoom | "안녕하세요" 메시지 표시 |
| ChatList | lastMessage 반영 |

### Scenario 4A: 그룹 채팅 생성

**파일**: `Tests/ChatRoomGroupUITests.swift`
**시나리오 키**: `chatRoomGroup`

```
채팅 탭 → 그룹 생성 버튼 → 친구 2명 선택 → 생성
→ ChatRoom 로드 → Drawer 열기 → 멤버 확인 → 닫기
```

### Scenario 4B: Drawer 표시

**파일**: `Tests/ChatRoomGroupUITests.swift`
**시나리오 키**: `chatRoomGroup`

```
채팅 탭 → 그룹 채팅방 진입 → Drawer 버튼 존재 확인
→ Drawer 열기 → 멤버 표시 확인 → 닫기
```

### Scenario 5: 미디어 Picker

**파일**: `Tests/ChatRoomMediaSendUITests.swift`
**시나리오 키**: `chatRoomMediaSend`

```
채팅방 진입 → 미디어 버튼 탭 → PHPicker 모달 표시
→ 스와이프 닫기 → ChatRoom 복귀
```

> PHPicker는 out-of-process이므로, 실제 미디어 선택/업로드는 UI 테스트에서 불가. 모달 표시/닫기만 검증.

### Scenario 6: 미디어 뷰어

**파일**: `Tests/ChatRoomMediaViewerUITests.swift`
**시나리오 키**: `chatRoomMediaViewer`

```
채팅방 진입 → 이미지 그리드 셀 탭 → FullScreenImageViewer 표시
→ 드래그로 닫기 → 비디오 썸네일 탭 → VideoPlayer 표시 → 닫기
```

| 단계 | 검증 |
|------|------|
| 이미지 셀 탭 | FullScreenImageViewer 표시 |
| 드래그 제스처 | 뷰어 dismiss |
| 비디오 썸네일 탭 | VideoPlayer 표시 |
| 비디오 dismiss | ChatRoom 복귀 |

---

## Mock 인프라 (앱 타겟)

UI 테스트용 Mock은 앱 타겟(`FirebaseChatting/Core/Dependencies/`)에 위치합니다.

### UITestScenario

Launch argument로 테스트 시나리오를 결정합니다.

```swift
enum UITestScenario: String {
    case chatListBasic
    case chatListDisplay
    case chatListRealtime
    case chatRoomPagination
    case chatRoomSend
    case chatRoomGroup
    case chatRoomMediaSend
    case chatRoomMediaViewer
    case chatRoomUnreadDivider
}
```

**Launch argument 형식**: `-UITesting -Scenario_chatRoomSend`

### MockDataFactory

테스트 데이터를 일관되게 생성하는 Factory입니다.

| 카테고리 | 데이터 |
|----------|--------|
| 사용자 | `currentUser`, `friend1`~`friend3`, `invitableFriend1`~`2` |
| 채팅방 | `directRoom` (1:1), `groupRoom` (1:N), `noParticipantRoom` |
| 메시지 | `makeMessages(count:)`, `makeYesterdayMessages(count:)`, `makeNewerMessages(count:)` |
| 시스템 메시지 | `joinSystemMessage(nickname:)`, `leaveSystemMessage(userId:nickname:)` |
| 미디어 메시지 | `imageMessage` (3장), `videoMessage` (1개) |

### UITestTrigger

실시간 Firestore 업데이트를 시뮬레이션하는 Singleton입니다.

```swift
UITestTrigger.shared.fireChatListEvent()  // unread count 변경 시뮬레이션
UITestTrigger.shared.yieldUpdatedChatList()  // lastMessage 갱신
```

- ChatList 타이틀 **트리플 탭**으로 이벤트 발생 (UI 테스트에서 제어)

### UITestingDependencies

모든 TCA 의존성을 Mock으로 교체합니다.

| 의존성 | Mock 동작 |
|--------|----------|
| `AuthRepository` | `checkAuthenticationState` → "current-user-123" |
| `KeychainDataSource` | `loadToken` → "mock-token" |
| `ChatListRepository` | 시나리오별 `MockChatListRepository.make(scenario:)` |
| `ChatRoomRepository` | 시나리오별 `MockChatRoomRepository.make(scenario:)` |
| `StorageClient` | 가짜 업로드 (진행률 시뮬레이션) |
| `UserRepository` | 고정 프로필 반환 |
| `ChatLocalDataSource` | no-op (빈 캐시) |

---

## Page Object 패턴

각 화면을 Page 객체로 추상화하여, 테스트 코드에서 UI 요소 접근과 assertion을 깔끔하게 분리합니다.

### ChatListPage

```swift
let chatList = ChatListPage(app: app)
chatList.assertRoomCount(2)
chatList.tapRoom(chatRoomId: "D_current-user-123_friend-1")
chatList.assertUnread(chatRoomId: "D_...", count: 3)
chatList.swipeToLeave(chatRoomId: "D_...")
chatList.triggerRealtimeEvent()  // 트리플 탭으로 실시간 이벤트 발생
```

### ChatRoomPage

```swift
let chatRoom = ChatRoomPage(app: app)
chatRoom.sendMessage("안녕하세요")
chatRoom.assertMessageContains("안녕하세요")
chatRoom.assertUnreadDividerExists()
chatRoom.scrollToTop()
chatRoom.tapDrawer()
chatRoom.goBack()
```

### CreateGroupChatPage

```swift
let createGroup = CreateGroupChatPage(app: app)
createGroup.selectFriend(friendId: "friend-1")
createGroup.selectFriend(friendId: "friend-2")
createGroup.assertCreateEnabled()
createGroup.tapCreate()
```

### DrawerPage

```swift
let drawer = DrawerPage(app: app)
drawer.assertVisible()
drawer.assertMemberCount(3)
drawer.assertMemberExists(name: "홍길동")
drawer.tapInvite()
drawer.dismiss()  // backdrop 탭
```

### MediaViewerPage

```swift
let viewer = MediaViewerPage(app: app)
viewer.assertImageViewerVisible()
viewer.swipeLeft()
viewer.assertIndex("2 / 3")
viewer.dismissByDrag()
```

---

## AccessibilityIdentifier 매핑

테스트에서 사용하는 주요 Accessibility ID입니다.

### ChatList

| ID | UI 요소 |
|----|---------|
| `chatList.roomList` | 채팅방 목록 전체 |
| `chatList.room.{chatRoomId}` | 개별 채팅방 셀 |
| `chatList.unread.{chatRoomId}` | Unread badge |
| `chatList.createGroup` | 그룹 채팅 생성 버튼 |
| `chatList.emptyState` | 빈 상태 뷰 |

### ChatRoom

| ID | UI 요소 |
|----|---------|
| `chatRoom.messageInput` | 메시지 입력 TextField |
| `chatRoom.sendButton` | 전송 버튼 |
| `chatRoom.mediaButton` | 미디어 선택 버튼 |
| `chatRoom.drawerButton` | Drawer 열기 버튼 |
| `chatRoom.message.{messageId}` | 개별 메시지 |
| `chatRoom.unreadDivider` | Unread 구분선 |
| `chatRoom.dateSeparator` | 날짜 구분선 |
| `chatRoom.mediaGrid.{index}` | 미디어 그리드 셀 |

### Drawer

| ID | UI 요소 |
|----|---------|
| `drawer.container` | Drawer 컨테이너 |
| `drawer.inviteButton` | 친구 초대 버튼 |
| `drawer.memberCount` | 멤버 수 레이블 |
| `drawer.backdrop` | 배경 오버레이 (닫기용) |

### Media Viewer

| ID | UI 요소 |
|----|---------|
| `imageViewer.container` | 이미지 뷰어 |
| `imageViewer.index` | 이미지 인덱스 (예: "2 / 3") |
| `videoPlayer.container` | 비디오 플레이어 |