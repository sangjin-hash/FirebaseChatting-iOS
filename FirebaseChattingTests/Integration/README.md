# Integration Tests (Integration/)

통합 테스트는 **다수의 Reducer 간 상호작용**, **Observer 생명주기**, **다단계 비동기 흐름**을 검증합니다.
단위 테스트와 달리, 실제 사용자 시나리오를 시뮬레이션하여 Reducer 간 delegate 전파, 상태 공유, 캐시-서버 동기화가 올바르게 동작하는지 확인합니다.

---

## 테스트 커버리지

### 요약

| 영역 | 테스트 수 | 파일 |
|------|----------|------|
| Auth | 4 | `Auth/AuthIntegrationTests.swift` |
| ChatList | 11 | `ChatList/ChatListIntegrationTests.swift` |
| ChatRoom (Sync) | 2 | `ChatRoom/ChatRoomSyncIntegrationTests.swift` |
| ChatRoom (Rejoin) | 2 | `ChatRoom/ChatRoomRejoinIntegrationTests.swift` |
| ChatRoom (Create/Invite) | 3 | `ChatRoom/ChatRoomCreateInviteIntegrationTests.swift` |
| **합계** | **22** | **5개 파일** |

### 단위 테스트와의 차이

| 관점 | 단위 테스트 | 통합 테스트 |
|------|-----------|-----------|
| 범위 | 단일 Reducer, 격리된 Action | 다중 Reducer 흐름, delegate 전파 |
| 의존성 | 모두 독립 mock | 시나리오 시뮬레이션용 mock |
| 비동기 처리 | 단일 비동기 연산 | 다단계: 캐시 → 페이지네이션 → observer |
| Observer 생명주기 | 미검증 | 호출 횟수 추적, cancel/restart 검증 |
| 상태 공유 | 단일 Reducer | Reducer 간 `.delegate`, 자식 상태 전파 |
| 직렬화 | 일반적으로 병렬 가능 | `@Suite(.serialized)` (IRGen 크래시 회피) |

---

## 시나리오 넘버링 체계

```
1.x  → Auth 흐름
2.x  → ChatList Observer 생명주기 & 표시
3.x  → ChatRoom 동기화 & 생성
```

---

## 시나리오 상세

### 1. Auth 통합 (4개)

Auth 흐름의 전체 생명주기를 검증합니다: 앱 실행 → 인증 확인 → 로그인 → MainTab 생성.

| # | 시나리오 | 테스트 | 검증 포인트 |
|---|---------|--------|-----------|
| 1.1 | 자동 로그인 성공 | `test_autoLoginFlow_success` | `checkAuthenticationState` → userId 반환 → MainTab.State 생성 |
| 1.2 | Google 로그인 성공 | `test_googleLoginFlow_success` | 미인증 → 버튼 탭 → `signInWithGoogle` → MainTab.State 생성 |
| 1.3 | 로그인 실패 | `test_loginFailure_showsError` | `signInWithGoogle` throw → error 상태 표시, MainTab 미생성 |
| 1.4 | 로그아웃 delegate | `test_logoutFlow_delegateFromMainTab` | MainTab `.delegate(.logoutSucceeded)` → Auth 상태 전체 초기화 |

**Reducer 간 상호작용:**
- `AuthFeature` ↔ `MainTabFeature`: 로그인 성공 시 자식 State 생성
- `MainTabFeature` → `AuthFeature`: 로그아웃 delegate 역전파

### 2. ChatList 통합 (11개)

ChatList의 Observer 생명주기, 채팅방 네비게이션, 실시간 업데이트를 검증합니다.

| # | 시나리오 | 테스트 | 검증 포인트 |
|---|---------|--------|-----------|
| - | 채팅방 로드 + 네비게이션 | `test_fullFlow_loadChatRoomsAndNavigate` | setChatRoomIds → stream → chatRoomTapped → ChatRoom State 생성 |
| - | 채팅방 나가기 전체 흐름 | `test_fullFlow_leaveRoom` | 스와이프 → 확인 다이얼로그 → leaveConfirmed → 목록 제거 |
| - | 실시간 업데이트 | `test_realTimeUpdate_newChatRoom` | Observer stream yield → chatRooms 자동 업데이트 |
| - | displayName 생성 | `test_displayName_direct` | 프로필 기반 채팅방 이름 생성 |
| 7.1 | 빈 채팅 목록 | `test_fullFlow_emptyChatRooms_rendersEmptyUI` | setChatRoomIds([]) → 빈 UI 렌더링 |
| 7.2 | 채팅방 로드 + 표시 | `test_fullFlow_setChatRoomIds_loadsAndDisplaysRooms` | Observer 호출 → 채팅방 정렬 표시 |
| 8 | 새 채팅방 추가 | `test_fullFlow_newChatRoomAdded_updatesUI` | Observer 유지 중 새 채팅방 수신 → 목록 증가 |
| - | 채팅방 진입/퇴장 Observer 관리 | `test_fullFlow_enterAndExitChatRoom_managesObserverCorrectly` | 진입 시 cancel, 퇴장 시 restart |
| - | 그룹 채팅방 displayName | `test_fullFlow_groupChatRoom_displaysCorrectName` | "닉네임 외 N명" 형식 |
| 2.1 | Observer cancel + restart | `test_observerLifecycle_cancelAndRestartReceivesUpdatedData` | 재시작 후 갱신된 데이터 수신 확인 |
| 2.2 | unreadCount 전달 | `test_unreadCount_passedToChatRoomAsInitialUnreadCount` | Observer unreadCounts → ChatRoom `initialUnreadCount`로 전달 |

### 3. ChatRoom 동기화 (7개)

캐시-서버 동기화, 재입장, Lazy 생성, 그룹 초대의 다단계 비동기 흐름을 검증합니다.

#### 3.1 Cache → Observer 동기화 (Case A: 안읽음 = 0)

`test_caseA_cacheLoadThenObserve_mergesById`

```
SwiftData 캐시 로드 → ChatRoom 문서 확인 (unread=0) → Observer 시작
→ ID 기반 merge (dict union) → createdAt 기준 정렬
```

- 캐시 메시지와 Observer 메시지가 ID 중복 시, Observer 메시지가 우선

#### 3.2 Cache → 페이지네이션 → Observer 전환 (Case B: 안읽음 > 0)

`test_caseB_paginationThenObserverTransition`

```
캐시 로드 → ChatRoom 문서 확인 (unread>0) → fetchNewerMessages ×2
→ hasMoreNewerMessages == false → Observer 전환
```

- `fetchNewerCallCount == 2` 확인 (페이지네이션 2회)
- 마지막 페이지 수신 후 자동으로 Observer 전환

#### 3.3-1 재입장 감지

`test_rejoinFlow_detectNeedsRejoin`

```
캐시 로드 (기존 메시지 포함) → ChatRoom 문서 확인
→ activeUsers에 현재 유저 없음 → needsRejoin = true
```

> **주의**: 캐시가 비어있으면 `needsToCreateChatRoom = true`가 되어 rejoin 분기 대신 create 분기로 진입. 재입장 테스트에서는 반드시 기존 메시지를 캐시에 포함해야 함.

#### 3.3-2 전송 → 재입장 트리거

`test_rejoinFlow_sendTriggersRejoin`

```
needsRejoin 상태에서 메시지 전송
→ rejoinChatRoom API 호출 → Observer 시작 → messageSent
```

- `rejoinCalled` + `sendCalled` boolean 추적으로 API 호출 순서 검증

#### 3.4 새 1:1 채팅방 Lazy 생성

`test_newDirectChat_createAndSendThenObserve`

```
빈 캐시 + nil ChatRoom → 첫 메시지 전송
→ createChatRoomAndSendMessage API 호출 → Observer 시작
```

- `createRoomId`, `createUserIds`, `createContent` 캡처 후 검증

#### 3.5 그룹 채팅 Lazy 생성

`test_lazyGroupChatCreation_pendingToCreated`

```
pendingGroupChatUserIds 설정 → 메시지 전송
→ createGroupChatRoomAndSendMessage API 호출 → pendingUserIds 초기화
```

#### 3.6 그룹 초대 흐름

`test_groupInvite_drawerToInviteFriendsToApiCalls`

```
Drawer → inviteFriendsButtonTapped → InviteFriendsFeature 시트
→ 친구 선택 → friendsInvited delegate
→ inviteToGroupChat API + sendSystemMessage × N회
```

- 초대 인원 수만큼 시스템 메시지 검증
