//
//  Strings.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import Foundation

enum Strings {
    // MARK: - Common
    enum Common {
        static let confirm = "확인"
        static let cancel = "취소"
        static let close = "닫기"
        static let error = "오류"
        static let loading = "로딩 중..."
        static let me = "나"
        static let noName = "이름 없음"
        static let unknown = "알 수 없음"
    }

    // MARK: - Auth
    enum Auth {
        static let login = "로그인"
        static let logout = "로그아웃"
        static let googleLogin = "Google 로그인"
        static let logoutConfirmMessage = "로그아웃 하시겠어요?"
    }

    // MARK: - Home
    enum Home {
        static let friendsTitle = "친구"
        static let noFriends = "아직 친구가 없습니다"
        static let noFriendsDescription = "검색 버튼을 눌러 친구를 추가해보세요"

        static func chatConfirmMessage(_ nickname: String) -> String {
            "\(nickname)님과 채팅하시겠어요?"
        }
    }

    // MARK: - Search
    enum Search {
        static let title = "친구 검색"
        static let placeholder = "닉네임 검색"
        static let searching = "검색 중..."
        static let noResults = "검색 결과가 없습니다"
        static let searchPrompt = "닉네임으로 친구를 검색해보세요"
        static let alreadyFriend = "추가됨"

        static func addFriendConfirmMessage(_ nickname: String) -> String {
            "\(nickname)님을 친구추가 하시겠어요?"
        }
    }

    // MARK: - Chat
    enum Chat {
        static let title = "채팅"
        static let noChatRooms = "아직 채팅이 없습니다"
        static let noChatRoomsDescription = "친구 목록에서 채팅을 시작해보세요"
        static let leaveConfirmMessage = "채팅방을 나가시겠어요?"
        static let leave = "나가기"
        static let messageInputPlaceholder = "메시지를 입력하세요"
        static let noParticipant = "대화 상대 없음"
    }
}
