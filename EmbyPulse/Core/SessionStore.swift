import Foundation

@MainActor
final class SessionStore: ObservableObject {
    @Published var serverURL: String
    @Published var rememberedUsername: String
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api: EmbyPulseAPI
    private let defaults: UserDefaults

    private enum Keys {
        static let serverURL = "embypulse.serverURL"
        static let username = "embypulse.username"
    }

    init(api: EmbyPulseAPI = .shared, defaults: UserDefaults = .standard) {
        self.api = api
        self.defaults = defaults
        self.serverURL = defaults.string(forKey: Keys.serverURL) ?? ""
        self.rememberedUsername = defaults.string(forKey: Keys.username) ?? ""

        if !serverURL.isEmpty {
            try? api.configure(baseURLString: serverURL)
            if let url = URL(string: serverURL),
               let cookies = HTTPCookieStorage.shared.cookies(for: url),
               !cookies.isEmpty {
                isAuthenticated = true
            }
        }
    }

    func login(serverURL: String, username: String, password: String) async {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            try api.configure(baseURLString: serverURL)
            _ = try await api.login(username: username, password: password)

            self.serverURL = api.currentBaseURLString()
            self.rememberedUsername = username
            defaults.set(self.serverURL, forKey: Keys.serverURL)
            defaults.set(username, forKey: Keys.username)
            isAuthenticated = true
        } catch {
            api.clearSession()
            errorMessage = error.localizedDescription
            isAuthenticated = false
        }
    }

    func logout() {
        api.clearSession()
        isAuthenticated = false
        errorMessage = nil
    }

    func assetURL(path: String) -> URL? {
        api.absoluteURL(path: path)
    }
}
