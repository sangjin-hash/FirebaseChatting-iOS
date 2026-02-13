//
//  AccessibilityIdentifiers.swift
//  FirebaseChatting
//
//  Created by Claude Code
//

import Foundation

enum AccessibilityID {
    // MARK: - ChatList
    enum ChatList {
        static let rooms = "chatlist_rooms"
        static let createGroupButton = "chatlist_create_group_button"
        static func room(_ chatRoomId: String) -> String { "chatlist_room_\(chatRoomId)" }
        static let leaveButton = "chatlist_leave_button"
        static func unread(_ chatRoomId: String) -> String { "chatlist_unread_\(chatRoomId)" }
        static let emptyState = "chatlist_empty_state"
        static let title = "chatlist_title"
    }

    // MARK: - ChatRoom
    enum ChatRoom {
        static let messageInput = "chatroom_message_input"
        static let sendButton = "chatroom_send_button"
        static let mediaButton = "chatroom_media_button"
        static let drawerButton = "chatroom_drawer_button"
        static func message(_ messageId: String) -> String { "chatroom_message_\(messageId)" }
        static let dateSeparator = "chatroom_date_separator"
        static let unreadDivider = "chatroom_unread_divider"
        static let loadingMore = "chatroom_loading_more"
        static let loadingNewer = "chatroom_loading_newer"
        static let mediaPreview = "chatroom_media_preview"
        static func mediaThumb(_ index: Int) -> String { "chatroom_media_thumb_\(index)" }
        static func mediaRemove(_ index: Int) -> String { "chatroom_media_remove_\(index)" }
        static let uploadingGrid = "chatroom_uploading_grid"
    }

    // MARK: - Image Viewer
    enum ImageViewer {
        static let container = "image_viewer"
        static let index = "image_viewer_index"
    }

    // MARK: - Video Player
    enum VideoPlayer {
        static let container = "video_player"
    }

    // MARK: - Drawer
    enum Drawer {
        static let container = "drawer_container"
        static let inviteButton = "drawer_invite_button"
        static let memberCount = "drawer_member_count"
        static let backdrop = "drawer_backdrop"
    }

    // MARK: - CreateGroupChat
    enum CreateGroupChat {
        static let createButton = "create_group_create_button"
        static let cancelButton = "create_group_cancel_button"
        static let selectionCount = "create_group_selection_count"
        static func friend(_ friendId: String) -> String { "create_group_friend_\(friendId)" }
    }

    // MARK: - InviteFriends
    enum InviteFriends {
        static let inviteButton = "invite_friends_invite_button"
        static let cancelButton = "invite_friends_cancel_button"
        static func friend(_ friendId: String) -> String { "invite_friend_\(friendId)" }
    }
}
