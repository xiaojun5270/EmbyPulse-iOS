//
//  EmbyPulseApp.swift
//  EmbyPulse
//
//  Created by EmbyPulse Team on 2026/03/04.
//

import SwiftUI

@main
struct EmbyPulseApp: App {
    @StateObject private var authManager = AuthManager()
    @StateObject private var serverManager = ServerManager()
    
    init() {
        // 配置网络请求缓存
        URLCache.shared.memoryCapacity = 20_000_000 // 20MB
        URLCache.shared.diskCapacity = 100_000_000 // 100MB
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(serverManager)
                .preferredColorScheme(.dark)
                .tint(.accentColor)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                MainTabView()
            } else {
                AuthView()
            }
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthManager())
        .environmentObject(ServerManager())
}