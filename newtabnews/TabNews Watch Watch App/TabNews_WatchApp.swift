//
//  TabNews_WatchApp.swift
//  TabNews Watch Watch App
//
//  Created by Luiz Mello on 20/11/25.
//

import SwiftUI

@main
struct TabNews_Watch_Watch_AppApp: App {
    
    init() {
        _ = WatchSyncManager.shared
        WatchNotificationManager.shared.setup()
        print("⌚ App iniciado, WatchSync e notificações ativos")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
