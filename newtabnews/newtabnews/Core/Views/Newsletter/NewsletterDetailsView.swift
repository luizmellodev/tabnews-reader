//
//  NewsletterDetailsView.swift
//  newtabnews
//
//  Created by Luiz Mello on 11/03/25.
//

import SwiftUI

struct NewsletterDetailsView: View {
    let nw: PostRequest?
    @Binding var isViewInApp: Bool
    @Binding var currentTheme: Theme
    
    @Environment(MainViewModel.self) private var viewModel
    
    var body: some View {
        Group {
            if let post = nw {
                ListDetailView(
                    isViewInApp: $isViewInApp,
                    currentTheme: $currentTheme,
                    post: post
                )
                .environment(viewModel)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
