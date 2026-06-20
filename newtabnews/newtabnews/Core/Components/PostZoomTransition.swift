//
//  PostZoomTransition.swift
//  newtabnews
//

import SwiftUI

extension View {
    @ViewBuilder
    func postZoomSource(id: String, namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }

    @ViewBuilder
    func postZoomDestination(id: String, namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
    }
}
