//
//  ErrorAlertModifier.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import SwiftUI

struct ErrorAlertModifier: ViewModifier {
    let error: String?
    var onDismiss: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .alert(Strings.Common.error, isPresented: .constant(error != nil)) {
                Button(Strings.Common.confirm) {
                    onDismiss?()
                }
            } message: {
                if let error {
                    Text(error)
                }
            }
    }
}

extension View {
    func errorAlert(error: String?, onDismiss: (() -> Void)? = nil) -> some View {
        modifier(ErrorAlertModifier(error: error, onDismiss: onDismiss))
    }
}
