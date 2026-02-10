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
            titleLabel
            Spacer()
            googleLoginButton
        }
        .overlay {
            if store.isLoading {
                ProgressView()
            }
        }
    }
}

// MARK: - Subviews

private extension LoginView {
    var titleLabel: some View {
        Text(Strings.Auth.login)
            .font(.system(size: 28, weight: .bold))
            .foregroundColor(.bkText)
            .padding(.top, 80)
            .padding(.horizontal, 30)
    }

    var googleLoginButton: some View {
        Button {
            store.send(.googleLoginButtonTapped)
        } label: {
            Text(Strings.Auth.googleLogin)
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
}

#Preview {
    LoginView(
        store: Store(initialState: AuthFeature.State()) {
            AuthFeature()
        }
    )
}
