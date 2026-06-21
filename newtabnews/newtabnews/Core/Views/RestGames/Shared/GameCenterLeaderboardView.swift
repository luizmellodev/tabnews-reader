import GameKit
import SwiftUI

struct RestGameLeaderboardsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var gameCenter = GameCenterManager.shared

    var body: some View {
        NavigationStack {
            Group {
                if gameCenter.isAuthenticated {
                    List(RestGameLeaderboard.allCases) { leaderboard in
                        Button {
                            gameCenter.showLeaderboard(leaderboard)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: leaderboard.icon)
                                    .font(.title3)
                                    .foregroundStyle(.purple)
                                    .frame(width: 32)

                                Text(leaderboard.displayName)
                                    .foregroundStyle(.primary)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                } else {
                    ContentUnavailableView {
                        Label("Game Center", systemImage: "person.crop.circle.badge.exclamationmark")
                    } description: {
                        Text("Entre no Game Center nas Ajustes do iPhone para ver e enviar rankings.")
                    }
                }
            }
            .navigationTitle("Rankings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
    }
}
