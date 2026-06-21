import GameKit
import SwiftUI

struct RestGameLeaderboardsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var gameCenter = GameCenterManager.shared

    var body: some View {
        NavigationStack {
            Group {
                if gameCenter.isAuthenticated {
                    List {
                        Section("Rankings") {
                            ForEach(RestGameLeaderboard.allCases) { leaderboard in
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
                        }

                        Section("Conquistas") {
                            if GameCenterManager.achievementsEnabled {
                                Button {
                                    gameCenter.showAchievements()
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "trophy.fill")
                                            .font(.title3)
                                            .foregroundStyle(.yellow)
                                            .frame(width: 32)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("DevWordle & DevLeet")
                                                .foregroundStyle(.primary)
                                            Text("\(RestGameAchievement.allCases.count) conquistas disponíveis")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            } else {
                                HStack(spacing: 12) {
                                    Image(systemName: "trophy.fill")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 32)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("DevWordle & DevLeet")
                                            .foregroundStyle(.secondary)
                                        Text("Em breve")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }

                                    Spacer()
                                }
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
            .navigationTitle("Game Center")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
    }
}
