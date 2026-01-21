//
//  ConfirmDialogModifier.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import SwiftUI

struct ConfirmDialogModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String
    let onConfirm: () -> Void

    func body(content: Content) -> some View {
        content
            .alert(Strings.Common.confirm, isPresented: $isPresented) {
                Button(Strings.Common.cancel, role: .cancel) {}
                Button(Strings.Common.confirm) {
                    onConfirm()
                }
            } message: {
                Text(message)
            }
    }
}

extension View {
    func confirmDialog(
        isPresented: Binding<Bool>,
        message: String,
        onConfirm: @escaping () -> Void
    ) -> some View {
        modifier(ConfirmDialogModifier(
            isPresented: isPresented,
            message: message,
            onConfirm: onConfirm
        ))
    }
}
