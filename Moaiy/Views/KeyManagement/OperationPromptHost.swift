//
//  OperationPromptHost.swift
//  Moaiy
//
//  Shared prompt host for key-management operation feedback.
//

import SwiftUI

struct PromptAlertContent {
    let title: LocalizedStringKey
    let message: String
    var actionTitle: LocalizedStringKey = "action_ok"
    var actionRole: ButtonRole? = .cancel
    var onAcknowledge: (() -> Void)? = nil
    var secondaryActionTitle: LocalizedStringKey? = nil
    var secondaryActionRole: ButtonRole? = nil
    var onSecondaryAction: (() -> Void)? = nil
    var onDismiss: (() -> Void)? = nil
}

extension PromptAlertContent {
    static func success(
        message: String,
        title: LocalizedStringKey = "operation_success",
        onAcknowledge: (() -> Void)? = nil
    ) -> PromptAlertContent {
        PromptAlertContent(
            title: title,
            message: message,
            actionTitle: "action_ok",
            actionRole: .cancel,
            onAcknowledge: onAcknowledge
        )
    }

    static func failure(
        context: UserFacingErrorContext,
        error: Error,
        onAcknowledge: (() -> Void)? = nil
    ) -> PromptAlertContent {
        PromptAlertContent(
            title: LocalizedStringKey(UserFacingErrorMapper.alertTitleKey(for: context)),
            message: UserFacingErrorMapper.message(for: error, context: context),
            actionTitle: "action_ok",
            actionRole: .cancel,
            onAcknowledge: onAcknowledge
        )
    }

    static func failure(
        title: LocalizedStringKey,
        message: String,
        onAcknowledge: (() -> Void)? = nil
    ) -> PromptAlertContent {
        PromptAlertContent(
            title: title,
            message: message,
            actionTitle: "action_ok",
            actionRole: .cancel,
            onAcknowledge: onAcknowledge
        )
    }

    static func retryableFailure(
        title: LocalizedStringKey,
        message: String,
        onRetry: @escaping () -> Void,
        onCancel: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) -> PromptAlertContent {
        PromptAlertContent(
            title: title,
            message: message,
            actionTitle: "action_retry",
            actionRole: nil,
            onAcknowledge: onRetry,
            secondaryActionTitle: "action_cancel",
            secondaryActionRole: .cancel,
            onSecondaryAction: onCancel,
            onDismiss: onDismiss
        )
    }

    static func destructiveConfirmation(
        title: LocalizedStringKey,
        message: String,
        confirmTitle: LocalizedStringKey = "action_confirm",
        onConfirm: @escaping () -> Void,
        onCancel: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) -> PromptAlertContent {
        PromptAlertContent(
            title: title,
            message: message,
            actionTitle: confirmTitle,
            actionRole: .destructive,
            onAcknowledge: onConfirm,
            secondaryActionTitle: "action_cancel",
            secondaryActionRole: .cancel,
            onSecondaryAction: onCancel,
            onDismiss: onDismiss
        )
    }

    static func info(
        title: LocalizedStringKey,
        message: String,
        onAcknowledge: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) -> PromptAlertContent {
        PromptAlertContent(
            title: title,
            message: message,
            actionTitle: "action_ok",
            actionRole: .cancel,
            onAcknowledge: onAcknowledge,
            onDismiss: onDismiss
        )
    }
}

private struct PromptAlertHostModifier: ViewModifier {
    @Binding var alert: PromptAlertContent?

    private var isAlertPresented: Binding<Bool> {
        Binding(
            get: { alert != nil },
            set: { isPresented in
                if !isPresented {
                    let dismissAction = alert?.onDismiss
                    alert = nil
                    dismissAction?()
                }
            }
        )
    }

    func body(content: Content) -> some View {
        content.alert(alert?.title ?? "operation_success", isPresented: isAlertPresented) {
            if let secondaryActionTitle = alert?.secondaryActionTitle {
                Button(secondaryActionTitle, role: alert?.secondaryActionRole) {
                    let secondaryAction = alert?.onSecondaryAction
                    alert = nil
                    secondaryAction?()
                }
            }
            Button(alert?.actionTitle ?? "action_ok", role: alert?.actionRole) {
                let action = alert?.onAcknowledge
                alert = nil
                action?()
            }
        } message: {
            Text(alert?.message ?? "")
        }
    }
}

private struct OperationPromptHostModifier: ViewModifier {
    @Binding var alert: PromptAlertContent?
    @Binding var operationResults: [OperationResult]
    @Binding var preferredOperation: OperationType?
    @Binding var isShowingOperationResults: Bool
    let onOpenInFinder: ((URL) -> Void)?

    func body(content: Content) -> some View {
        content
            .modifier(PromptAlertHostModifier(alert: $alert))
            .sheet(isPresented: $isShowingOperationResults) {
                OperationResultOverlay(
                    results: operationResults,
                    preferredOperation: preferredOperation,
                    onDismiss: {
                        isShowingOperationResults = false
                        operationResults = []
                        preferredOperation = nil
                    },
                    onOpenInFinder: onOpenInFinder
                )
            }
    }
}

extension View {
    func moaiyPromptAlertHost(alert: Binding<PromptAlertContent?>) -> some View {
        modifier(PromptAlertHostModifier(alert: alert))
    }

    func moaiyOperationPromptHost(
        alert: Binding<PromptAlertContent?>,
        operationResults: Binding<[OperationResult]>,
        preferredOperation: Binding<OperationType?> = .constant(nil),
        isShowingOperationResults: Binding<Bool>,
        onOpenInFinder: ((URL) -> Void)? = nil
    ) -> some View {
        modifier(
            OperationPromptHostModifier(
                alert: alert,
                operationResults: operationResults,
                preferredOperation: preferredOperation,
                isShowingOperationResults: isShowingOperationResults,
                onOpenInFinder: onOpenInFinder
            )
        )
    }
}
