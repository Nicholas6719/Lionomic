import SwiftUI

/// The Chat tab. Presents the transcript of the current session and an
/// input area pinned to the bottom. Conversation state lives in
/// `ChatViewModel` — this view is purely presentational.
struct ChatView: View {

    @State private var viewModel: ChatViewModel

    init(viewModel: ChatViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        @Bindable var vm = viewModel

        VStack(spacing: 0) {
            if let error = viewModel.errorMessage {
                errorBanner(error)
            }

            transcript

            inputArea(textBinding: $vm.inputText)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Lionomic Chat")
        .toolbar {
            if !viewModel.messages.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear") { viewModel.clearConversation() }
                }
            }
        }
    }

    // MARK: - Transcript

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: DesignSystem.Spacing.sm) {
                    if viewModel.messages.isEmpty && !viewModel.isLoading {
                        emptyState
                            .padding(.top, DesignSystem.Spacing.lg)
                    }

                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }

                    if viewModel.isLoading {
                        LoadingBubble()
                            .id(Self.loadingAnchorID)
                    }

                    // Sentinel we always scroll to so auto-scroll works
                    // whether the last item is a message or the loading
                    // bubble.
                    Color.clear
                        .frame(height: 1)
                        .id(Self.bottomAnchorID)
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
            }
            .onChange(of: viewModel.messages.count) {
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
                }
            }
            .onChange(of: viewModel.isLoading) {
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.largeTitle)
                .foregroundStyle(Color.lionomicAccent)
            Text("Ask about your portfolio")
                .font(.headline)
                .foregroundStyle(.primary)
            Text("Your profile, holdings, and watchlist are shared with the assistant to ground its answers in your portfolio. Not financial advice.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.md)
        }
    }

    // MARK: - Input area

    private func inputArea(textBinding: Binding<String>) -> some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .bottom, spacing: DesignSystem.Spacing.sm) {
                TextField("Ask about your portfolio…", text: textBinding, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                            .fill(Color(.systemBackground))
                    )

                Button {
                    Task { await viewModel.send() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title)
                        .foregroundStyle(sendEnabled ? Color.lionomicAccent : Color.secondary)
                }
                .disabled(!sendEnabled)
                .accessibilityLabel("Send message")
            }
            .padding(DesignSystem.Spacing.sm)
            .background(Color(.secondarySystemBackground))
        }
    }

    private var sendEnabled: Bool {
        !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !viewModel.isLoading
    }

    // MARK: - Error banner

    private func errorBanner(_ text: String) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color(.systemRed))
            Text(text)
                .font(.footnote)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
            Button {
                viewModel.dismissError()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Dismiss error")
        }
        .padding(DesignSystem.Spacing.sm)
        .background(Color(.systemRed).opacity(0.1))
    }

    // MARK: - Scroll anchors

    private static let bottomAnchorID = "__chat_bottom__"
    private static let loadingAnchorID = "__chat_loading__"
}

// MARK: - Bubbles

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top) {
            if message.role == .user {
                Spacer(minLength: DesignSystem.Spacing.lg)
            }
            Text(message.content)
                .font(.body)
                .foregroundStyle(message.role == .user ? .white : .primary)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                        .fill(message.role == .user ? Color.lionomicAccent : Color(.secondarySystemBackground))
                )
            if message.role == .assistant {
                Spacer(minLength: DesignSystem.Spacing.lg)
            }
        }
    }
}

private struct LoadingBubble: View {
    var body: some View {
        HStack {
            HStack(spacing: DesignSystem.Spacing.xs) {
                ProgressView()
                Text("Thinking…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            Spacer(minLength: DesignSystem.Spacing.lg)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Assistant is thinking")
    }
}
