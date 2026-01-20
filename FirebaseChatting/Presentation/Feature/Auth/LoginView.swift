//
//  LoginView.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import SwiftUI
import ComposableArchitecture

struct LoginView: View {
    let store: StoreOf<AuthFeature>

    var body: some View {
        VStack(alignment: .leading) {
            Text("로그인")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.bkText)
                .padding(.top, 80)
                .padding(.horizontal, 30)

            Spacer()

            Button {
                store.send(.googleLoginButtonTapped)
            } label: {
                Text("Google 로그인")
                    .font(.system(size: 14))
                    .foregroundColor(.bkText)
                    .frame(maxWidth: .infinity, maxHeight: 40)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.greyLight, lineWidth: 0.8)
            }
            .padding(.horizontal, 15)
        }
        .overlay {
            if store.isLoading {
                ProgressView()
            }
        }
    }
}

#Preview {
    LoginView(
        store: Store(initialState: AuthFeature.State()) {
            AuthFeature()
        } withDependencies: {
            $0.authClient = .mock()
        }
    )
}
