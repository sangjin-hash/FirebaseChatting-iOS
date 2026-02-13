# Unit Tests (Features/)

단위 테스트는 각 TCA Feature의 Reducer 로직을 **독립적으로** 검증합니다.
모든 외부 의존성은 mock으로 대체되어, 순수한 상태 변화와 Effect 실행을 테스트합니다.

---

## 테스트 커버리지

### 요약

| Feature | 테스트 수 | 파일 |
|---------|----------|------|
| Auth | 2 | `AuthFeatureTests.swift` |
| Home | 12 | `HomeFeatureTests.swift` |
| Search | 12 | `SearchFeatureTests.swift` |
| MainTab | 24 | `MainTabFeatureTests.swift` |
| ChatList | 31 | `ChatListFeatureTests.swift` |
| ChatRoom | 43 | `ChatRoomFeatureTests.swift` |
| ChatRoom (Media) | 24 | `ChatRoomMediaTests.swift` |
| CreateGroupChat | 9 | `CreateGroupChatFeatureTests.swift` |
| InviteFriends | 9 | `InviteFriendsFeatureTests.swift` |
| **합계** | **166** | **9개 파일** |

### Feature별 커버리지 상세

#### AuthFeature (2/2)

| 시나리오 | 테스트 | 상태 |
|----------|--------|------|
| 초기 상태 기본값 | `test_initialState_hasCorrectDefaults` | ✅ |
| MainTab 로그아웃 성공 → Auth 상태 초기화 | `test_mainTabLogoutSucceeded_clearsAuthState` | ✅ |

> 로그인 흐름(자동 로그인, Google 로그인, 실패)은 Integration 테스트에서 커버

#### HomeFeature (12/12)

| 시나리오 | 테스트 | 상태 |
|----------|--------|------|
| 초기 상태 기본값 | `test_initialState_hasCorrectDefaults` | ✅ |
| 로그아웃 버튼 → 확인 다이얼로그 표시 | `test_logoutButtonTapped_showsConfirmDialog` | ✅ |
| 로그아웃 확인 다이얼로그 닫기 | `test_logoutConfirmDismissed_hidesDialog` | ✅ |
| 검색 버튼 → SearchFeature 시트 표시 | `test_searchButtonTapped_presentsSearchSheet` | ✅ |
| 검색 버튼 (currentUser 없음) → 무동작 | `test_searchButtonTapped_noCurrentUser_doesNothing` | ✅ |
| 채팅 버튼 → 채팅 확인 다이얼로그 표시 | `test_chatButtonTapped_showsChatConfirmDialog` | ✅ |
| 채팅 확인 다이얼로그 닫기 | `test_chatConfirmDismissed_hidesDialog` | ✅ |
| 채팅 확인 → ChatRoom으로 네비게이션 | `test_chatConfirmed_navigatesToChatRoom` | ✅ |
| 채팅 확인 (currentUser 없음) → 무동작 | `test_chatConfirmed_noCurrentUser_doesNothing` | ✅ |
| 로그아웃 확인 → API 호출 | `test_logoutConfirmed_callsLogoutAPI` | ✅ |
| 로그아웃 성공 → delegate 전달 | `test_logoutCompleted_success_sendsDelegate` | ✅ |
| 로그아웃 실패 → 에러 상태 설정 | `test_logoutCompleted_failure_setsError` | ✅ |

#### SearchFeature (12/12)

| 시나리오 | 테스트 | 상태 |
|----------|--------|------|
| 초기 상태 기본값 | `test_initialState_hasCorrectDefaults` | ✅ |
| 빈 쿼리로 검색 → 무동작 | `test_searchButtonTapped_withEmptyQuery_doesNothing` | ✅ |
| 공백 쿼리로 검색 → 무동작 | `test_searchButtonTapped_withWhitespaceQuery_doesNothing` | ✅ |
| 친구 추가 버튼 → 확인 다이얼로그 | `test_addFriendButtonTapped_showsConfirmDialog` | ✅ |
| 친구 추가 다이얼로그 닫기 | `test_addFriendConfirmDismissed_hidesDialog` | ✅ |
| searchQuery 바인딩 업데이트 | `test_binding_searchQuery_updatesState` | ✅ |
| 유효 쿼리 → searchUsers API 호출 | `test_searchButtonTapped_withValidQuery_callsSearchUsers` | ✅ |
| 검색 실패 → 에러 설정 | `test_searchResultsLoaded_failure_setsError` | ✅ |
| 친구 추가 확인 → addFriend API 호출 | `test_addFriendConfirmed_callsAddFriendAPI` | ✅ |
| 친구 추가 (대상 없음) → 무동작 | `test_addFriendConfirmed_withNoTarget_doesNothing` | ✅ |
| 친구 추가 실패 → 에러 설정 | `test_friendAdded_failure_setsError` | ✅ |
| 닫기 버튼 → dismiss | `test_dismissButtonTapped_triggersDismissal` | ✅ |

#### MainTabFeature (24/24)

| 시나리오 | 테스트 | 상태 |
|----------|--------|------|
| 초기 상태 기본값 | `test_initialState_hasCorrectDefaults` | ✅ |
| 탭 전환 (Chat) | `test_selectedTabChanged_toChat_changesCurrentTab` | ✅ |
| 탭 전환 (Home) | `test_selectedTabChanged_toHome_changesCurrentTab` | ✅ |
| ChatList onAppear 전파 | `test_chatListAction_onAppear_propagates` | ✅ |
| 탭 전환 시 Home 상태 유지 | `test_tabChange_preservesHomeState` | ✅ |
| Home 내 검색 플로우 | `test_homeSearchFlow_worksWithinMainTab` | ✅ |
| Home 내 로그아웃 플로우 | `test_homeLogoutButtonFlow_worksWithinMainTab` | ✅ |
| onAppear (인증 유저) → 유저 문서 관찰 시작 | `test_onAppear_withAuthenticatedUser_startsObservingUserDocument` | ✅ |
| onAppear (미인증) → 무동작 | `test_onAppear_withNoAuthenticatedUser_doesNothing` | ✅ |
| onDisappear → 관찰 취소 | `test_onDisappear_cancelsObservation` | ✅ |
| 유저 문서 업데이트 → currentUser 및 자식 상태 갱신 | `test_userDocumentUpdated_updatesCurrentUserAndChildStates` | ✅ |
| 새 friendIds → getFriends 호출 | `test_userDocumentUpdated_withNewFriendIds_callsGetFriends` | ✅ |
| 동일 friendIds → getFriends 미호출 | `test_userDocumentUpdated_withSameFriendIds_doesNotCallGetFriends` | ✅ |
| 빈 friendIds → 친구 목록 초기화 | `test_userDocumentUpdated_withEmptyFriendIds_clearsFriends` | ✅ |
| 친구 로드 성공 → Home 상태 업데이트 | `test_friendsLoaded_success_updatesFriendsInHomeState` | ✅ |
| 친구 로드 실패 → 에러 설정 | `test_friendsLoaded_failure_setsErrorInHomeState` | ✅ |
| Home 로그아웃 → 부모에게 delegate | `test_homeLogoutSucceeded_delegatesToParent` | ✅ |
| 새 chatRoomIds → 자식에게 전달 | `test_userDocumentUpdated_withNewChatRoomIds_sendsChatRoomIdsToChild` | ✅ |
| 새 chatRoomIds → getUserBatch 호출 | `test_userDocumentUpdated_withNewChatRoomIds_callsGetUserBatch` | ✅ |
| 동일 chatRoomIds → 전달 안함 | `test_userDocumentUpdated_withSameChatRoomIds_doesNotSendToChild` | ✅ |
| 빈 chatRooms → 프로필 초기화 | `test_userDocumentUpdated_withEmptyChatRooms_clearsChatRoomProfiles` | ✅ |
| 빈 chatRooms → 빈 IDs 전달 | `test_userDocumentUpdated_withEmptyChatRooms_sendsEmptyIdsToChild` | ✅ |
| 프로필 로드 성공 → chatRoomProfiles 업데이트 | `test_chatRoomProfilesLoaded_success_updatesChatRoomProfiles` | ✅ |
| 프로필 로드 실패 → 에러 설정 | `test_chatRoomProfilesLoaded_failure_setsError` | ✅ |

#### ChatListFeature (31/31)

| 시나리오 | 테스트 | 상태 |
|----------|--------|------|
| 초기 상태 기본값 | `test_initialState_hasCorrectDefaults` | ✅ |
| setCurrentUserId → 상태 업데이트 | `test_setCurrentUserId_updatesState` | ✅ |
| onAppear (chatRoomIds 없음) → 무동작 | `test_onAppear_withNoChatRoomIds_doesNothing` | ✅ |
| onAppear → observer 미시작 (스트림 관리) | `test_onAppear_doesNothing` | ✅ |
| chatRoomsUpdated → lastMessageAt 정렬 | `test_chatRoomsUpdated_sortsByLastMessageAt` | ✅ |
| 채팅방 탭 → 네비게이션 + observer 취소 | `test_chatRoomTapped_navigatesToChatRoomAndCancelsObserver` | ✅ |
| 스와이프 나가기 → 확인 다이얼로그 | `test_leaveSwipeAction_showsConfirmDialog` | ✅ |
| 나가기 확인 닫기 | `test_leaveConfirmDismissed_hidesDialog` | ✅ |
| 나가기 확인 → 채팅방 제거 | `test_leaveConfirmed_removesChatRoom` | ✅ |
| displayName (프로필 있음) | `test_displayName_withProfile` | ✅ |
| displayName (프로필 없음) | `test_displayName_withoutProfile` | ✅ |
| onDisappear → 스트림 유지 | `test_onDisappear_doesNothing` | ✅ |
| setChatRoomIds (빈 배열) → 초기화 | `test_setChatRoomIds_withEmptyIds_clearsRoomsAndCancels` | ✅ |
| setChatRoomIds → observer 시작 | `test_setChatRoomIds_withIds_startsObserving` | ✅ |
| setChatRoomIds (새 IDs) → 재시작 | `test_setChatRoomIds_withNewIds_cancelsAndRestarts` | ✅ |
| setChatRoomIds → unreadCount 업데이트 | `test_setChatRoomIds_updatesUnreadCounts` | ✅ |
| 로드 실패 → 에러 설정 | `test_loadFailed_setsErrorAndStopsLoading` | ✅ |
| 그룹 채팅방 displayName (N명) | `test_displayName_forGroupChatRoom_showsCountSuffix` | ✅ |
| 그룹 채팅방 displayName (2명) | `test_displayName_forGroupChatRoom_withTwoUsers_showsNicknameOnly` | ✅ |
| 1:1 채팅방 닉네임 nil → "알 수 없음" | `test_displayName_forDirectChatRoom_withNilNickname_showsUnknown` | ✅ |
| 프로필이 본인 → "대화 상대 없음" | `test_displayName_whenProfileIsMyself_showsNoParticipant` | ✅ |
| 채팅방 탭 → 상대방 프로필 포함 | `test_chatRoomTapped_withProfile_includesOtherUserInDestination` | ✅ |
| destination dismiss → observer 재시작 | `test_chatRoomDestination_dismiss_restartsObserver` | ✅ |
| destination dismiss (빈 IDs) → 무동작 | `test_chatRoomDestination_dismiss_withEmptyChatRoomIds_doesNothing` | ✅ |
| 빈 목록 업데이트 | `test_chatRoomsUpdated_withEmptyList_setsEmptyChatRooms` | ✅ |
| 나가기 실패 → 에러 설정 | `test_leaveCompleted_failure_setsError` | ✅ |
| setFriends → 친구 목록 업데이트 | `test_setFriends_updatesFriends` | ✅ |
| setCurrentUserNickname → 닉네임 업데이트 | `test_setCurrentUserNickname_updatesNickname` | ✅ |
| 그룹 채팅 생성 버튼 → 시트 표시 | `test_createGroupChatButtonTapped_presentsSheet` | ✅ |
| 그룹 채팅 생성 (친구 없음) → 시트 표시 | `test_createGroupChatButtonTapped_withNoFriends_stillPresentsSheet` | ✅ |
| 그룹 채팅 준비 완료 → ChatRoom 네비게이션 | `test_createGroupChatDestination_groupChatPrepared_navigatesToChatRoom` | ✅ |
| 나가기 확인 (그룹) → 시스템 메시지 전송 | `test_leaveConfirmed_sendsSystemMessage_forGroupChat` | ✅ |
| 나가기 확인 (1:1) → 시스템 메시지 미전송 | `test_leaveConfirmed_doesNotSendSystemMessage_forDirectChat` | ✅ |
| 채팅방 탭 → 그룹 채팅 정보 전달 | `test_chatRoomTapped_passesGroupChatInfo` | ✅ |

#### ChatRoomFeature (43/43)

| 시나리오 | 테스트 | 상태 |
|----------|--------|------|
| 초기 상태 기본값 | `test_initialState_hasCorrectDefaults` | ✅ |
| onAppear → 메시지 observer 시작 | `test_onAppear_startsMessageObserver` | ✅ |
| onAppear (기존 채팅방) → 메시지 로드 | `test_onAppear_withExistingChatRoom_loadsMessages` | ✅ |
| onDisappear → observer 취소 | `test_onDisappear_cancelsMessageObserver` | ✅ |
| 입력 텍스트 변경 → 상태 업데이트 | `test_inputTextChanged_updatesState` | ✅ |
| 전송 (빈 텍스트) → 무동작 | `test_sendButtonTapped_withEmptyText_doesNothing` | ✅ |
| 전송 (공백만) → 무동작 | `test_sendButtonTapped_withWhitespaceOnly_doesNothing` | ✅ |
| 전송 성공 | `test_sendButtonTapped_sendsMessage_success` | ✅ |
| 전송 실패 | `test_sendButtonTapped_sendsMessage_failure` | ✅ |
| 첫 메시지 전송 → 채팅방 생성 | `test_sendFirstMessage_createsChatRoomAndSendsMessage` | ✅ |
| 이전 메시지 로드 (역방향 페이지네이션) | `test_loadMoreMessages_fetchesOlderMessages` | ✅ |
| 이전 메시지 끝 → hasMoreMessages false | `test_loadMoreMessages_withNoMoreMessages_setsHasMoreMessagesFalse` | ✅ |
| 로딩 중 중복 로드 방지 | `test_loadMoreMessages_whenAlreadyLoading_doesNothing` | ✅ |
| 더 없을 때 로드 방지 | `test_loadMoreMessages_whenNoMoreMessages_doesNothing` | ✅ |
| 메시지 업데이트 → index 정렬 | `test_messagesUpdated_sortsMessagesByIndex` | ✅ |
| 메시지 로드 실패 → 에러 설정 | `test_messagesLoadFailed_setsError` | ✅ |
| canSendMessage (텍스트 있음) → true | `test_canSendMessage_returnsTrueWhenTextNotEmpty` | ✅ |
| canSendMessage (전송 중) → false | `test_canSendMessage_returnsFalseWhenSending` | ✅ |
| canSendMessage (빈 텍스트) → false | `test_canSendMessage_returnsFalseWhenTextEmpty` | ✅ |
| 시스템 메시지 포함 업데이트 | `test_messagesUpdated_includesSystemMessages` | ✅ |
| 그룹 채팅 판별 (group) | `test_isGroupChat_returnsTrueForGroupType` | ✅ |
| 그룹 채팅 판별 (direct) | `test_isGroupChat_returnsFalseForDirectType` | ✅ |
| 초대 가능 친구 필터링 | `test_invitableFriends_filtersActiveUsers` | ✅ |
| 초대 버튼 (그룹) → 시트 표시 | `test_inviteFriendsButtonTapped_presentsSheet_forGroupChat` | ✅ |
| 초대 버튼 (1:1) → 무동작 | `test_inviteFriendsButtonTapped_doesNothing_forDirectChat` | ✅ |
| 친구 초대 → API + 시스템 메시지 | `test_inviteFriendsDestination_friendsInvited_invitesAndSendsSystemMessage` | ✅ |
| 초대 실패 → 에러 설정 | `test_inviteCompleted_failure_setsError` | ✅ |
| 재초대 탭 → 확인 대상 설정 | `test_reinviteUserTapped_setsConfirmTarget` | ✅ |
| 재초대 닫기 → 대상 초기화 | `test_reinviteConfirmDismissed_clearsTarget` | ✅ |
| 재초대 확인 → API + 시스템 메시지 | `test_reinviteConfirmed_invitesUserAndSendsSystemMessage` | ✅ |
| 재초대 (대상 없음) → 무동작 | `test_reinviteConfirmed_withNoTarget_doesNothing` | ✅ |
| 재초대 실패 → 에러 설정 | `test_reinviteCompleted_failure_setsError` | ✅ |
| 캐시 메시지 로드 → 상태 설정 | `test_cachedMessagesLoaded_withMessages_setsState` | ✅ |
| 빈 캐시 → 상태 미변경 | `test_cachedMessagesLoaded_empty_doesNotChangeState` | ✅ |
| Case A (안읽음=0) → observer 시작 | `test_chatRoomLoaded_noUnread_startsObserving` | ✅ |
| Case B (안읽음>0) → 페이지네이션 시작 | `test_chatRoomLoaded_withUnreadMessages_startsPagination` | ✅ |
| Case E (재입장 필요) → 로딩 중지 | `test_chatRoomLoaded_needsRejoin_stopsLoading` | ✅ |
| 최신 메시지 로드 (순방향 페이지네이션) | `test_loadNewerMessages_fetchesNewerMessages` | ✅ |
| 최신 메시지 끝 → 무동작 | `test_loadNewerMessages_whenNoMoreNewerMessages_doesNothing` | ✅ |
| 로딩 중 최신 메시지 중복 방지 | `test_loadNewerMessages_whenAlreadyLoading_doesNothing` | ✅ |
| 최신 메시지 실패 → observer 전환 | `test_newerMessagesFetched_failure_startsObserving` | ✅ |
| 그룹 채팅 pending 판별 (true) | `test_needsToCreateGroupChat_returnsTrueWhenPending` | ✅ |
| 그룹 채팅 pending 판별 (false) | `test_needsToCreateGroupChat_returnsFalseWhenNotPending` | ✅ |
| pending 그룹 → 생성 + 전송 | `test_sendButtonTapped_createsGroupChatAndSendsMessage_whenPending` | ✅ |

#### ChatRoomFeature - Media (24/24)

| 시나리오 | 테스트 | 상태 |
|----------|--------|------|
| 미디어 버튼 → picker 표시 | `test_mediaButtonTapped_presentsMediaPicker` | ✅ |
| picker 닫기 | `test_setMediaPickerPresented_false_dismissesPicker` | ✅ |
| 미디어 선택 → 항목 추가 | `test_mediaSelected_addsToSelectedItems` | ✅ |
| 선택 미디어 제거 | `test_removeSelectedMedia_removesItem` | ✅ |
| 전체 미디어 삭제 | `test_clearSelectedMedia_removesAllItems` | ✅ |
| 파일 크기 초과 → 에러 | `test_fileSizeExceeded_setsError` | ✅ |
| 미디어 전송 (미디어 없음) → 무동작 | `test_sendMediaButtonTapped_withNoMedia_doesNothing` | ✅ |
| 업로드 진행률 업데이트 | `test_uploadProgress_updatesProgress` | ✅ |
| 업로드 완료 → 상태 업데이트 | `test_uploadCompleted_updatesState` | ✅ |
| 업로드 실패 → 에러 | `test_uploadFailed_setsError` | ✅ |
| 전체 업로드 완료 → 이미지/동영상 분리 | `test_allUploadsCompleted_separatesImagesAndVideos` | ✅ |
| 혼합 미디어 → 다중 메시지 생성 | `test_mixedMedia_separatesIntoMultipleMessages` | ✅ |
| 미디어 메시지 전송 (기존 채팅방) | `test_sendMediaMessages_sendsMediaToExistingChatRoom` | ✅ |
| 미디어 전송 실패 → 에러 | `test_sendMediaMessages_failure_setsError` | ✅ |
| 이미지 탭 → 전체화면 뷰어 | `test_imageTapped_presentsFullScreenViewer` | ✅ |
| 이미지 뷰어 닫기 | `test_dismissImageViewer_closesViewer` | ✅ |
| 이미지 인덱스 변경 | `test_imageViewerIndexChanged_updatesIndex` | ✅ |
| 비디오 탭 → 플레이어 표시 | `test_videoTapped_presentsVideoPlayer` | ✅ |
| 비디오 플레이어 닫기 | `test_dismissVideoPlayer_closesPlayer` | ✅ |
| hasSelectedMedia (있음) → true | `test_hasSelectedMedia_returnsTrueWhenMediaSelected` | ✅ |
| hasSelectedMedia (없음) → false | `test_hasSelectedMedia_returnsFalseWhenEmpty` | ✅ |
| remainingMediaCount 계산 | `test_remainingMediaCount_calculatesCorrectly` | ✅ |
| canSendAny (텍스트) → true | `test_canSendAny_returnsTrueWithText` | ✅ |
| canSendAny (미디어) → true | `test_canSendAny_returnsTrueWithMedia` | ✅ |
| canSendAny (빈 상태) → false | `test_canSendAny_returnsFalseWhenEmpty` | ✅ |

#### CreateGroupChatFeature (9/9)

| 시나리오 | 테스트 | 상태 |
|----------|--------|------|
| 초기 상태 기본값 | `test_initialState_hasCorrectDefaults` | ✅ |
| 친구 토글 → 선택 | `test_friendToggled_addsFriend` | ✅ |
| 친구 토글 → 해제 | `test_friendToggled_removesFriend` | ✅ |
| 친구 토글 → 다중 선택/해제 | `test_friendToggled_addsAndRemovesFriend` | ✅ |
| canCreate (2명 미만) → false | `test_canCreate_returnsFalseWithLessThanTwoFriends` | ✅ |
| canCreate (2명 이상) → true | `test_canCreate_returnsTrueWithTwoOrMoreFriends` | ✅ |
| 생성 버튼 (2명 미만) → 무동작 | `test_createButtonTapped_withLessThanTwoFriends_doesNothing` | ✅ |
| 생성 버튼 → Lazy 그룹 채팅 준비 | `test_createButtonTapped_preparesGroupChat_lazyCreation` | ✅ |
| 선택 수 카운트 | `test_selectedCount_returnsCorrectCount` | ✅ |

#### InviteFriendsFeature (9/9)

| 시나리오 | 테스트 | 상태 |
|----------|--------|------|
| 초기 상태 기본값 | `test_initialState_hasCorrectDefaults` | ✅ |
| 친구 토글 → 선택 | `test_friendToggled_addsFriend` | ✅ |
| 친구 토글 → 해제 | `test_friendToggled_removesFriend` | ✅ |
| 친구 토글 → 다중 선택/해제 | `test_friendToggled_addsAndRemovesFriend` | ✅ |
| canInvite (미선택) → false | `test_canInvite_returnsFalseWithNoSelection` | ✅ |
| canInvite (선택) → true | `test_canInvite_returnsTrueWithSelection` | ✅ |
| 초대 버튼 (미선택) → 무동작 | `test_inviteButtonTapped_withNoSelection_doesNothing` | ✅ |
| 초대 버튼 → delegate 전송 | `test_inviteButtonTapped_sendsDelegate` | ✅ |
| 선택 수 카운트 | `test_selectedCount_returnsCorrectCount` | ✅ |

---

## 의존성 모킹 패턴

모든 테스트는 TCA의 `withDependencies` 블록을 통해 의존성을 mock으로 대체합니다.

### 패턴 A: 단순 Side Effect (void 반환)
```swift
$0.chatListRepository.leaveChatRoom = { _, _ in }
```

### 패턴 B: 파라미터 캡처 후 검증
```swift
var sentChatRoomId: String?
$0.chatRoomRepository.sendSystemMessage = { chatRoomId, _ in
    sentChatRoomId = chatRoomId
}
// ...
#expect(sentChatRoomId == "expected-id")
```

### 패턴 C: AsyncStream (Observable 의존성)
```swift
$0.chatListRepository.observeChatRooms = { ids in
    AsyncStream { continuation in
        continuation.yield((chatRooms, [:]))
        continuation.finish()
    }
}
```

### 패턴 D: 반환값 제공
```swift
$0.chatRoomRepository.fetchOlderMessages = { _, _, _, _ in
    return olderMessages
}
```

### 패턴 E: 에러 throw
```swift
$0.chatRoomRepository.sendMessage = { _, _, _ in
    throw TestError.networkError
}
```

### 패턴 F: 클로저 내 인라인 검증
```swift
$0.chatListRepository.observeChatRooms = { ids in
    #expect(ids == expectedIds) // 호출 파라미터 즉시 검증
    return AsyncStream { ... }
}
```