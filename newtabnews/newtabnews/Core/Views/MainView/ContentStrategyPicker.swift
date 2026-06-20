//
//  ContentStrategyPicker.swift
//  newtabnews
//

import SwiftUI

struct ContentStrategyPicker: View {
    var selection: ContentStrategy
    var isLoading: Bool
    var onSelect: (ContentStrategy) -> Void

    @Namespace private var underlineNamespace

    var body: some View {
        HStack(spacing: 20) {
            ForEach(ContentStrategy.allCases, id: \.self) { strategy in
                Button {
                    guard !isLoading, selection != strategy else { return }
                    onSelect(strategy)
                } label: {
                    Text(strategy.displayName)
                        .font(.subheadline)
                        .fontWeight(selection == strategy ? .semibold : .regular)
                        .padding(.bottom, 6)
                        .overlay(alignment: .bottom) {
                            if selection == strategy {
                                Capsule()
                                    .fill(Color.primary.opacity(0.35))
                                    .frame(height: 2)
                                    .matchedGeometryEffect(id: "strategyUnderline", in: underlineNamespace)
                            }
                        }
                }
                .buttonStyle(.plain)
                .foregroundStyle(selection == strategy ? Color.primary : Color.secondary.opacity(0.7))
            }

            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .tint(.secondary)
            }

            Spacer(minLength: 0)
        }
        .animation(.snappy, value: selection)
    }
}
