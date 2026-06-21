import SwiftUI

struct DevWordleView: View {
    @State private var viewModel = DevWordleViewModel()
    @State private var showResultSheet = false
    @State private var showOnboarding = !RestGameOnboarding.hasSeen(.devWordle)

    var body: some View {
        @Bindable var viewModel = viewModel

        ZStack {
            RestGameBackground(animated: false)

            VStack(spacing: 0) {
                header

                Spacer(minLength: 16)

                DevWordleBoardView(
                    rows: viewModel.rows,
                    currentRowIndex: viewModel.currentRowIndex,
                    currentGuess: viewModel.currentGuess,
                    revealedRows: viewModel.revealedRows,
                    shakeRow: viewModel.shakeRow
                )
                .padding(.horizontal, 16)

                Spacer(minLength: 16)

                DevWordleKeyboardView(
                    keyboardStates: viewModel.keyboardStates,
                    onLetter: { viewModel.appendLetter($0) },
                    onDelete: { viewModel.deleteLetter() },
                    onSubmit: { viewModel.submitGuess() }
                )
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if showOnboarding {
                RestGameOnboardingOverlay.devWordle {
                    RestGameOnboarding.markSeen(.devWordle)
                    showOnboarding = false
                }
            }
        }
        .onAppear {
            RestFeedbackManager.shared.prepare()
            if viewModel.isCompletedToday {
                showResultSheet = true
            }
        }
        .onChange(of: viewModel.gameStatus) { _, status in
            if status != .playing {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    showResultSheet = true
                }
            }
        }
        .sheet(isPresented: $showResultSheet) {
            DevWordleResultSheet(viewModel: viewModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("DevWordle")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Termo dev de 5 letras · PT e EN")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(.top, 12)
    }
}

private struct DevWordleResultSheet: View {
    let viewModel: DevWordleViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var gameCenter = GameCenterManager.shared

    var body: some View {
        VStack(spacing: 20) {
            Text(viewModel.gameStatus == .won ? "Nice!" : "Foi quase")
                .font(.title.weight(.bold))

            if viewModel.gameStatus == .won, let attempt = viewModel.winningAttemptNumber {
                Text("Você acertou em \(attempt)/6")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("A palavra era \(viewModel.targetWord)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ShareLink(item: viewModel.shareText) {
                Text("Compartilhar resultado")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.primary.opacity(0.08), in: Capsule())
            }

            if viewModel.gameStatus == .won, gameCenter.isAuthenticated {
                Button("Ver ranking") {
                    gameCenter.showLeaderboard(.devWordle)
                }
                .font(.headline)
            }

            Button("Fechar") { dismiss() }
                .font(.headline)
        }
        .padding(24)
    }
}
