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
            searchBar
            Divider()
            searchResultsContent
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
        .errorAlert(error: store.error)
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
}

// MARK: - Subviews

private extension SearchView {
    var searchBar: some View {
        HStack(spacing: 12) {
            TextField(Strings.Search.placeholder, text: $store.searchQuery)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.3), .white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                }
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .submitLabel(.search)
                .onSubmit {
                    store.send(.searchButtonTapped)
                }

            CircleIconButtonComponent(
                systemName: "magnifyingglass",
                isDisabled: store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                action: {
                    store.send(.searchButtonTapped)
                }
            )
        }
        .padding()
    }

    @ViewBuilder
    var searchResultsContent: some View {
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
            EmptyStateComponent(
                systemImageName: "magnifyingglass",
                title: Strings.Search.searchPrompt
            )
            Spacer()
        } else {
            searchResultsList
        }
    }

    var searchResultsList: some View {
        List(store.searchResults, id: \.id) { profile in
            let isMe = profile.id == store.currentUserId
            let isFriend = store.currentUserFriendIds.contains(profile.id)
            let isAdding = store.addingFriendId == profile.id
            let isDisabled = isMe || isFriend

            UserRowComponent(
                profile: profile,
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
                            store.send(.addFriendButtonTapped(profile))
                        }
                    )
                }
            }
            .padding(.vertical, 4)
        }
        .listStyle(.plain)
    }

    func captionFor(isMe: Bool, isFriend: Bool) -> String? {
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
