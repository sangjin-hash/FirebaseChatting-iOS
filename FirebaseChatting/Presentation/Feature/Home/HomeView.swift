//
//  HomeView.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import SwiftUI
import ComposableArchitecture

struct HomeView: View {
    @Bindable var store: StoreOf<HomeFeature>

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    myProfileSection
                    Divider()
                    friendsHeader
                    friendsList
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        store.send(.logoutButtonTapped)
                    } label: {
                        Text(Strings.Auth.logout)
                            .foregroundColor(.red)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        store.send(.searchButtonTapped)
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }
            }
            .sheet(item: $store.scope(state: \.searchDestination, action: \.searchDestination)) { searchStore in
                NavigationStack {
                    SearchView(store: searchStore)
                }
            }
            .errorAlert(error: store.error)
            .confirmDialog(
                isPresented: Binding(
                    get: { store.chatConfirmTarget != nil },
                    set: { if !$0 { store.send(.chatConfirmDismissed) } }
                ),
                message: Strings.Home.chatConfirmMessage(store.chatConfirmTarget?.nickname ?? ""),
                onConfirm: {
                    store.send(.chatConfirmed)
                }
            )
            .confirmDialog(
                isPresented: Binding(
                    get: { store.showLogoutConfirm },
                    set: { if !$0 { store.send(.logoutConfirmDismissed) } }
                ),
                message: Strings.Auth.logoutConfirmMessage,
                onConfirm: {
                    store.send(.logoutConfirmed)
                }
            )
            .navigationDestination(
                item: $store.scope(state: \.chatRoomDestination, action: \.chatRoomDestination)
            ) { chatRoomStore in
                ChatRoomView(store: chatRoomStore)
            }
        }
    }
}

// MARK: - Subviews

private extension HomeView {
    var myProfileSection: some View {
        Group {
            if let user = store.currentUser {
                UserRowComponent<EmptyView>(
                    profile: user.profile,
                    imageSize: 60,
                    caption: Strings.Common.me
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
        }
    }

    var friendsHeader: some View {
        Text(Strings.Home.friendsTitle)
            .font(.subheadline)
            .fontWeight(.bold)
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.vertical, 8)
    }

    @ViewBuilder
    var friendsList: some View {
        if !store.hasFriendsLoaded {
            Color.clear
                .frame(height: 100)
        } else if store.friends.isEmpty {
            VStack(spacing: 12) {
                Text(Strings.Home.noFriends)
                    .foregroundColor(.secondary)
                Text(Strings.Home.noFriendsDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 100)
        } else {
            ForEach(store.friends, id: \.id) { friend in
                UserRowComponent(profile: friend) {
                    CircleIconButtonComponent(
                        systemName: "bubble.right",
                        action: {
                            store.send(.chatButtonTapped(friend))
                        }
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()
                    .padding(.leading, 68)
            }
        }
    }
}

#Preview {
    HomeView(
        store: Store(initialState: HomeFeature.State(
            currentUser: User(id: "1", nickname: "테스트 유저"),
            friends: [
                Profile(id: "2", nickname: "친구1"),
                Profile(id: "3", nickname: "친구2"),
                Profile(id: "4", nickname: "친구3"),
                Profile(id: "5", nickname: "친구4"),
                Profile(id: "6", nickname: "친구5"),
                Profile(id: "7", nickname: "친구6"),
                Profile(id: "8", nickname: "친구7"),
                Profile(id: "9", nickname: "친구8"),
                Profile(id: "10", nickname: "친구9"),
                Profile(id: "11", nickname: "친구10"),
                Profile(id: "12", nickname: "친구11"),
                Profile(id: "13", nickname: "친구12"),
                Profile(id: "14", nickname: "친구13")
            ]
        )) {
            HomeFeature()
        }
    )
}
