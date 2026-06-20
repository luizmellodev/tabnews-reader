//
//  CommentRow.swift
//  newtabnews
//
//  Created by Luiz Mello on 04/01/26.
//

import SwiftUI

struct CommentRow: View {
    let comment: Comment
    let depth: Int
    @Binding var expandedThreadIDs: Set<String>
    var onReply: ((Comment) -> Void)?
    var onVote: ((Comment, String, @escaping (Bool) -> Void) -> Void)?

    @State private var isVoting: Bool = false
    @State private var hasVoted: Bool = false
    @State private var localTabcoins: Int? = nil
    @State private var showConfetti: Bool = false

    private let maxDepth = 5
    private let indentWidth: CGFloat = 16
    private let voteManager = VoteManager.shared

    private var displayTabcoins: Int {
        localTabcoins ?? comment.tabcoins ?? 0
    }

    private var replyCount: Int {
        comment.children?.count ?? 0
    }
    
    private var isRepliesExpanded: Bool {
        guard let id = comment.id else { return false }
        return expandedThreadIDs.contains(id)
    }

    init(
        comment: Comment,
        depth: Int,
        expandedThreadIDs: Binding<Set<String>>,
        onReply: ((Comment) -> Void)? = nil,
        onVote: ((Comment, String, @escaping (Bool) -> Void) -> Void)? = nil
    ) {
        self.comment = comment
        self.depth = depth
        self._expandedThreadIDs = expandedThreadIDs
        self.onReply = onReply
        self.onVote = onVote

        if let commentId = comment.id {
            _hasVoted = State(initialValue: VoteManager.shared.hasVoted(contentId: commentId))
        }
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 0) {
                    if depth > 0 {
                        HStack(spacing: indentWidth - 2) {
                            ForEach(0..<min(depth, maxDepth), id: \.self) { _ in
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 2)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        metadataLine

                        voteLine
                            .padding(.top, 6)

                        if let body = comment.body {
                            CommentBodyView(markdown: body)
                                .padding(.top, 10)
                        }

                        actionsLine
                            .padding(.top, 12)
                    }
                    .padding(.leading, depth > 0 ? 12 : 0)
                    .padding(.vertical, depth == 0 ? 20 : 12)
                }

                if isRepliesExpanded, let children = comment.children, !children.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(children) { childComment in
                            CommentRow(
                                comment: childComment,
                                depth: min(depth + 1, maxDepth),
                                expandedThreadIDs: $expandedThreadIDs,
                                onReply: onReply,
                                onVote: onVote
                            )
                        }
                    }
                    .padding(.top, 4)
                }
            }

            if showConfetti {
                GeometryReader { geometry in
                    ParticleSystemView(
                        configuration: ParticleSystemConfiguration(
                            particleCount: 50,
                            shapes: [.confetti],
                            colors: [.red, .blue, .green, .yellow, .purple, .orange, .pink],
                            minSize: 6,
                            maxSize: 12,
                            minVelocity: 200,
                            maxVelocity: 400,
                            gravity: 600,
                            lifetime: 2.0,
                            emissionAngle: -90...90
                        ),
                        origin: CGPoint(x: geometry.size.width / 2, y: 50)
                    )
                    .allowsHitTesting(false)
                }
            }
        }
    }

    // MARK: - Subviews

    private var metadataLine: some View {
        HStack(spacing: 6) {
            Text("@\(comment.ownerUsername ?? "Anônimo")")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("•")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(comment.formattedDate)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var voteLine: some View {
        HStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.caption2)
                Text("\(displayTabcoins)")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundStyle(displayTabcoins > 0 ? .orange : .secondary)

            if !hasVoted && !isVoting {
                Button {
                    handleVote(transactionType: "credit")
                } label: {
                    Image(systemName: "arrow.up.circle")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Marcar como relevante")

                Button {
                    handleVote(transactionType: "debit")
                } label: {
                    Image(systemName: "arrow.down.circle")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Marcar como irrelevante")
            } else if isVoting {
                ProgressView()
                    .controlSize(.mini)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Votado")
            }
        }
    }

    private var actionsLine: some View {
        HStack(spacing: 12) {
            Button {
                onReply?(comment)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrowshape.turn.up.left")
                        .font(.caption)
                    Text("Responder")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            if replyCount > 0 {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        toggleRepliesExpanded()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(replyCount == 1 ? "1 resposta" : "\(replyCount) respostas")
                            .font(.caption)
                        Image(systemName: isRepliesExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func toggleRepliesExpanded() {
        guard let id = comment.id else { return }
        if expandedThreadIDs.contains(id) {
            expandedThreadIDs.remove(id)
        } else {
            expandedThreadIDs.insert(id)
        }
    }

    // MARK: - Actions

    private func handleVote(transactionType: String) {
        guard comment.id != nil else { return }
        guard !hasVoted else { return }

        isVoting = true

        let currentTabcoins = localTabcoins ?? comment.tabcoins ?? 0
        localTabcoins = transactionType == "credit" ? currentTabcoins + 1 : currentTabcoins - 1

        onVote?(comment, transactionType) { success in
            isVoting = false

            if success {
                hasVoted = true

                if let commentId = comment.id {
                    voteManager.markAsVoted(contentId: commentId)
                }

                if transactionType == "credit" {
                    showConfetti = true

                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showConfetti = false
                    }
                }
            } else {
                localTabcoins = comment.tabcoins
            }
        }
    }
}

#Preview("Comentário Simples") {
    @Previewable @State var expandedIDs: Set<String> = []
    
    ScrollView {
        VStack(spacing: 0) {
            CommentRow(
                comment: Comment(
                    id: "1",
                    ownerUsername: "luizmellodev",
                    ownerID: "user-123",
                    slug: "comentario-teste",
                    title: nil,
                    body: "Este é um comentário de exemplo! 🚀\n\nPodemos usar **markdown** e `código`.",
                    status: "published",
                    sourceURL: nil,
                    createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600)),
                    updatedAt: nil,
                    publishedAt: nil,
                    deletedAt: nil,
                    tabcoins: 5,
                    tabcoinsCredit: 5,
                    tabcoinsDebit: 0,
                    childrenDeepCount: 0,
                    parentID: "post-123",
                    children: nil
                ),
                depth: 0,
                expandedThreadIDs: $expandedIDs,
                onReply: { _ in }
            )

            Divider()
        }
    }
}

#Preview("Comentário com Respostas") {
    @Previewable @State var expandedIDs: Set<String> = ["1"]
    
    ScrollView {
        VStack(spacing: 0) {
            CommentRow(
                comment: Comment.mockComment,
                depth: 0,
                expandedThreadIDs: $expandedIDs,
                onReply: { _ in }
            )
            Divider()
        }
    }
}
