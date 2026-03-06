import SwiftUI

@main
struct EmbyPulseApp: App {
    @StateObject private var sessionStore = SessionStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(sessionStore)
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @State private var showingRequestPortal = false

    var body: some View {
        Group {
            if sessionStore.isAuthenticated {
                MainTabView()
            } else if showingRequestPortal {
                RequestPortalView {
                    showingRequestPortal = false
                }
            } else {
                LoginView {
                    showingRequestPortal = true
                }
            }
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                DashboardView()
            }
            .tabItem {
                Label("仪表盘", systemImage: "chart.xyaxis.line")
            }

            NavigationStack {
                AnalyticsHubView()
            }
            .tabItem {
                Label("分析", systemImage: "chart.bar.doc.horizontal")
            }

            NavigationStack {
                CalendarView()
            }
            .tabItem {
                Label("日历", systemImage: "calendar")
            }

            NavigationStack {
                UsersView()
            }
            .tabItem {
                Label("用户", systemImage: "person.3")
            }

            NavigationStack {
                AdminHubView()
            }
            .tabItem {
                Label("管理", systemImage: "gearshape")
            }
        }
    }
}
