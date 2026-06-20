//
//  SkeletonListView.swift
//  newtabnews
//
//  Created by Luiz Mello on 24/11/25.
//

import SwiftUI

struct SkeletonListView: View {
    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { index in
                SkeletonCard()
                    .transition(.opacity)
                    .animation(
                        .easeOut(duration: 0.3)
                            .delay(Double(index) * 0.1),
                        value: index
                    )
            }
        }
        .padding(.top, 5)
    }
}

#Preview {
    SkeletonListView()
        .preferredColorScheme(.dark)
}

