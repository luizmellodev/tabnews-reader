import SwiftUI

struct DevLeetView: View {
    @State private var weekKey = DevLeetSchedule.weekKey()
    @State private var isSolved = DevLeetStorage.shared.isSolved(weekKey: DevLeetSchedule.weekKey())
    @State private var showHonorSheet = false
    @State private var showOnboarding = !RestGameOnboarding.hasSeen(.devLeet)

    private let problem = DevLeetCatalog.shared.weeklyProblem()

    var body: some View {
        ZStack {
            RestGameBackground(animated: false)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    paperCallout
                    problemCard
                    examplesSection
                    constraintsSection

                    if isSolved {
                        solvedBanner
                    } else {
                        markSolvedButton
                    }

                    if isSolved {
                        DevLeetCountdownLabel()
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }

            if showOnboarding {
                RestGameOnboardingOverlay.devLeet {
                    RestGameOnboarding.markSeen(.devLeet)
                    showOnboarding = false
                }
            }
        }
        .onAppear {
            RestFeedbackManager.shared.prepare()
            refreshState()
        }
        .sheet(isPresented: $showHonorSheet) {
            DevLeetHonorSheet(
                onConfirm: {
                    DevLeetStorage.shared.markSolved(weekKey: weekKey)
                    RestFeedbackManager.shared.confirm()
                    isSolved = true
                    showHonorSheet = false
                },
                onCancel: {
                    showHonorSheet = false
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DevLeet")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Weekly challenge · paper & pen only")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))

            HStack(spacing: 10) {
                difficultyBadge
                Text("#\(problem.leetcodeNumber)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .padding(.top, 12)
    }

    private var difficultyBadge: some View {
        Text(problem.difficulty.rawValue)
            .font(.caption2.weight(.bold))
            .foregroundStyle(problem.difficulty.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(problem.difficulty.color.opacity(0.15), in: Capsule())
    }

    private var paperCallout: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "pencil.and.outline")
                .font(.title3)
                .foregroundStyle(.orange)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 6) {
                Text("Grab paper and a pen")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Text("Write your solution by hand — that's how it works at Google, Meta, and Amazon. No IDE. No autocomplete. Just you and the problem.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.orange.opacity(0.25), lineWidth: 1)
        }
    }

    private var problemCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(problem.title)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            Text(problem.description)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)

            if !problem.topics.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(problem.topics, id: \.self) { topic in
                            Text(topic)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.7))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(.white.opacity(0.08), in: Capsule())
                        }
                    }
                }
            }

            if let url = problem.leetcodeURL {
                Link(destination: url) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.right.square")
                        Text("View on LeetCode")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.cyan)
                }
                .padding(.top, 4)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        }
    }

    private var examplesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Examples")

            ForEach(Array(problem.examples.enumerated()), id: \.element.id) { index, example in
                VStack(alignment: .leading, spacing: 8) {
                    Text("Example \(index + 1)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.45))

                    exampleBlock("Input", example.input)
                    exampleBlock("Output", example.output)

                    if let explanation = example.explanation {
                        exampleBlock("Explanation", explanation)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private var constraintsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Constraints")

            VStack(alignment: .leading, spacing: 6) {
                ForEach(problem.constraints, id: \.self) { constraint in
                    Text("• \(constraint)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var markSolvedButton: some View {
        Button {
            RestFeedbackManager.shared.tap()
            showHonorSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                Text("Mark as Solved")
            }
            .font(.headline.weight(.semibold))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(.white, in: Capsule())
            .shadow(color: .white.opacity(0.15), radius: 16, y: 8)
        }
        .buttonStyle(RestGameScaleButtonStyle())
    }

    private var solvedBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title2)
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 4) {
                Text("Marked as solved")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("See you next week for a new challenge.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer()
        }
        .padding(16)
        .background(.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.green.opacity(0.25), lineWidth: 1)
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption.weight(.bold))
            .tracking(1.5)
            .foregroundStyle(.white.opacity(0.45))
    }

    private func exampleBlock(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.4))
            Text(value)
                .font(.caption.monospaced())
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func refreshState() {
        weekKey = DevLeetSchedule.weekKey()
        isSolved = DevLeetStorage.shared.isSolved(weekKey: weekKey)
    }
}

private struct DevLeetHonorSheet: View {
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
                .frame(width: 72, height: 72)
                .background(.orange.opacity(0.12), in: Circle())

            VStack(spacing: 10) {
                Text("Be honest with yourself")
                    .font(.title3.weight(.bold))

                Text("You're only fooling yourself if you tap solved without actually working it out.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text("Did you grab paper, write the code, and trace through your solution?")
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Button(action: onConfirm) {
                    Text("Yes, I solved it")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.green, in: Capsule())
                }

                Button(action: onCancel) {
                    Text("Not yet — back to the problem")
                        .font(.headline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
        }
        .padding(24)
    }
}

struct DevLeetCountdownLabel: View {
    var prefix: String = "Next challenge in"
    var onDarkBackground = true

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text("\(prefix) \(DevLeetSchedule.formattedRemaining(from: context.date))")
                .font(onDarkBackground ? .caption2.weight(.semibold) : .subheadline)
                .monospacedDigit()
                .foregroundStyle(onDarkBackground ? .white.opacity(0.5) : .secondary)
        }
    }
}
