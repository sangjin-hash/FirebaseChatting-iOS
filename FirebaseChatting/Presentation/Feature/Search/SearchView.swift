//
//  SearchView.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import SwiftUI
import ComposableArchitecture

struct SearchView: View {
    @Bindable var store: StoreOf<SearchFeature>

    var body: some View {
        VStack(spacing: 0) {
            // 검색 바
            HStack {
                TextField(Strings.Search.placeholder, text: $store.searchQuery)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .submitLabel(.search)
                    .onSubmit {
                        store.send(.searchButtonTapped)
                    }

                Button {
                    store.send(.searchButtonTapped)
                } label: {
                    Image(systemName: "magnifyingglass")
                        .padding(8)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()

            Divider()

            // 검색 결과
            if store.isSearching {
                Spacer()
                ProgressView(Strings.Search.searching)
                Spacer()
            } else if store.searchResults.isEmpty && store.hasSearched {
                Spacer()
                Text(Strings.Search.noResults)
                    .foregroundColor(.secondary)
                Spacer()
            } else if store.searchResults.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text(Strings.Search.searchPrompt)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                List(store.searchResults, id: \.id) { user in
                    let isMe = user.id == store.currentUserId
                    let isFriend = store.currentUserFriendIds.contains(user.id)
                    let isAdding = store.addingFriendId == user.id
                    let isDisabled = isMe || isFriend

                    UserRowComponent(
                        user: user,
                        caption: captionFor(isMe: isMe, isFriend: isFriend)
                    ) {
                        if isAdding {
                            ProgressView()
                                .frame(width: 36, height: 36)
                        } else {
                            CircleIconButtonComponent(
                                systemName: "person.badge.plus",
                                isDisabled: isDisabled,
                                action: {
                                    store.send(.addFriendButtonTapped(user))
                                }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(Strings.Search.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(Strings.Common.close) {
                    store.send(.dismissButtonTapped)
                }
            }
        }
        .alert(Strings.Common.error, isPresented: .constant(store.error != nil)) {
            Button(Strings.Common.confirm) {
                // 에러 상태 초기화
            }
        } message: {
            if let error = store.error {
                Text(error)
            }
        }
        .confirmDialog(
            isPresented: Binding(
                get: { store.addFriendConfirmTarget != nil },
                set: { if !$0 { store.send(.addFriendConfirmDismissed) } }
            ),
            message: Strings.Search.addFriendConfirmMessage(store.addFriendConfirmTarget?.nickname ?? ""),
            onConfirm: {
                store.send(.addFriendConfirmed)
            }
        )
    }

    private func captionFor(isMe: Bool, isFriend: Bool) -> String? {
        if isMe {
            return Strings.Common.me
        } else if isFriend {
            return Strings.Search.alreadyFriend
        }
        return nil
    }
}

#Preview {
    NavigationStack {
        SearchView(
            store: Store(initialState: SearchFeature.State(
                currentUserId: "me",
                currentUserFriendIds: ["friend1"]
            )) {
                SearchFeature()
            }
        )
    }
}
