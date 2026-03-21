//
//  LoadingStates.swift
//  Moaiy
//
//  Skeleton loading states for better UX
//

import SwiftUI

// MARK: - Skeleton View

struct SkeletonView: View {
    let height: CGFloat
    var cornerRadius: CGFloat = 8

    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .controlBackgroundColor))
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shimmer()
    }
}

// MARK: - Shimmer Modifier

extension View {
    func shimmer() -> some View {
        self.modifier(ShimmerModifier())
    }
}

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        .clear,
                        Color.white.opacity(0.3),
                        .clear
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .rotationEffect(.degrees(30))
                .offset(x: phase)
            )
            .mask(content)
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 400
                }
            }
    }
}

// MARK: - Key Card Skeleton

struct KeyCardSkeleton: View {
    var body: some View {
        HStack(spacing: 16) {
            // Icon skeleton
            Circle()
                .fill(Color(nsColor: .controlBackgroundColor))
                .frame(width: 40, height: 40)
                .shimmer()

            VStack(alignment: .leading, spacing: 8) {
                // Title skeleton
                SkeletonView(height: 16)
                    .frame(width: 200)

                // Email skeleton
                SkeletonView(height: 14)
                    .frame(width: 150)

                // Metadata skeleton
                SkeletonView(height: 12)
                    .frame(width: 180)
            }

            Spacer()
        }
        .padding(12)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Key List Skeleton

struct KeyListSkeleton: View {
    let count: Int

    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<count, id: \.self) { _ in
                KeyCardSkeleton()
            }
        }
        .padding()
    }
}

// MARK: - Loading View with Message

struct LoadingView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text(message)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Error View with Retry

struct ErrorView: View {
    let message: String
    let retryAction: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.orange)

            Text("error_occurred")
                .font(.title2)
                .fontWeight(.semibold)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            Button(action: retryAction) {
                Label("action_retry", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview("Skeleton Loading") {
    VStack(spacing: 20) {
        KeyCardSkeleton()
        KeyCardSkeleton()
        KeyCardSkeleton()
    }
    .padding()
    .frame(width: 600, height: 400)
}

#Preview("Loading View") {
    LoadingView(message: "status_loading_keys")
}

#Preview("Error View") {
    ErrorView(message: "Failed to load keys") {
        print("Retry")
    }
}
