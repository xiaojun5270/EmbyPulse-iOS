import Foundation

enum APIError: LocalizedError {
    case missingBaseURL
    case invalidBaseURL
    case invalidResponse
    case unauthorized
    case server(String)
    case decoding(Error)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .missingBaseURL:
            return "请先填写 EmbyPulse 面板地址。"
        case .invalidBaseURL:
            return "面板地址格式不正确。"
        case .invalidResponse:
            return "服务器返回了无法识别的数据。"
        case .unauthorized:
            return "登录状态已失效，请重新登录。"
        case .server(let message):
            return message
        case .decoding:
            return "客户端解析数据失败，请确认面板版本是否兼容。"
        case .transport(let error):
            return error.localizedDescription
        }
    }
}

enum HTTPVerb: String {
    case get = "GET"
    case post = "POST"
}

final class EmbyPulseAPI {
    static let shared = EmbyPulseAPI()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private var baseURL: URL?

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.httpCookieStorage = HTTPCookieStorage.shared
        configuration.httpShouldSetCookies = true
        configuration.httpCookieAcceptPolicy = .always
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 20

        session = URLSession(configuration: configuration)
        decoder = JSONDecoder()
        encoder = JSONEncoder()
    }

    func configure(baseURLString: String) throws {
        let normalized = baseURLString
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/+$", with: "", options: .regularExpression)

        guard !normalized.isEmpty else {
            throw APIError.missingBaseURL
        }

        let candidate: String
        if normalized.hasPrefix("http://") || normalized.hasPrefix("https://") {
            candidate = normalized
        } else {
            candidate = "http://\(normalized)"
        }

        guard let parsed = URL(string: candidate) else {
            throw APIError.invalidBaseURL
        }

        baseURL = parsed
    }

    func currentBaseURLString() -> String {
        baseURL?.absoluteString ?? ""
    }

    func absoluteURL(path: String) -> URL? {
        guard let baseURL else { return nil }

        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        let suffix = path.hasPrefix("/") ? String(path.dropFirst()) : path
        components?.path = baseURL.path + "/" + suffix
        return components?.url
    }

    func clearSession() {
        HTTPCookieStorage.shared.cookies?.forEach {
            HTTPCookieStorage.shared.deleteCookie($0)
        }
    }

    func login(username: String, password: String) async throws -> StatusMessageResponse {
        let response: StatusMessageResponse = try await request(
            path: "/api/login",
            method: .post,
            body: LoginRequest(username: username, password: password)
        )

        guard response.status == "success" else {
            throw APIError.server(response.message ?? "登录失败")
        }

        return response
    }

    func fetchDashboard() async throws -> DashboardSnapshot {
        let response: DashboardEnvelope = try await request(path: "/api/stats/dashboard")
        guard response.status == "success" else {
            throw APIError.server("获取仪表盘失败")
        }
        return response.data
    }

    func fetchTrend(dimension: TrendDimension) async throws -> [TrendPoint] {
        let response: TrendEnvelope = try await request(
            path: "/api/stats/trend",
            query: [URLQueryItem(name: "dimension", value: dimension.rawValue)]
        )

        guard response.status == "success" else {
            throw APIError.server("获取趋势图失败")
        }

        return response.data
            .map { TrendPoint(label: $0.key, value: Double($0.value)) }
            .sorted { $0.label < $1.label }
    }

    func fetchLiveSessions() async throws -> [LiveSession] {
        let response: LiveSessionsEnvelope = try await request(path: "/api/stats/live")
        guard response.status == "success" else {
            throw APIError.server("获取实时会话失败")
        }
        return response.data
    }

    func fetchRecentActivity() async throws -> [RecentActivity] {
        let response: RecentActivityEnvelope = try await request(path: "/api/stats/recent")
        guard response.status == "success" else {
            throw APIError.server("获取最近活动失败")
        }
        return response.data
    }

    func fetchLatestMedia(limit: Int = 10) async throws -> [LatestMedia] {
        let response: LatestMediaEnvelope = try await request(
            path: "/api/stats/latest",
            query: [URLQueryItem(name: "limit", value: String(limit))]
        )

        guard response.status == "success" else {
            throw APIError.server("获取最近入库失败")
        }
        return response.data
    }

    func fetchCalendarWeek(offset: Int, refresh: Bool) async throws -> CalendarWeekResponse {
        let response: CalendarWeekResponse = try await request(
            path: "/api/calendar/weekly",
            query: [
                URLQueryItem(name: "offset", value: String(offset)),
                URLQueryItem(name: "refresh", value: refresh ? "true" : "false")
            ]
        )

        if let error = response.error, !error.isEmpty {
            throw APIError.server(error)
        }

        return response
    }

    func updateCalendarTTL(_ ttl: CalendarTTL) async throws {
        let response: StatusMessageResponse = try await request(
            path: "/api/calendar/config",
            method: .post,
            body: CalendarTTLRequest(ttl: ttl.rawValue)
        )

        guard response.status == "success" else {
            throw APIError.server(response.message ?? "更新缓存时间失败")
        }
    }

    func fetchUsers() async throws -> [ManagedUser] {
        let response: UsersEnvelope = try await request(path: "/api/manage/users")
        guard response.status == "success" else {
            throw APIError.server("获取用户列表失败")
        }
        return response.data
    }

    func updateUserStatus(userID: String, isDisabled: Bool) async throws {
        let response: StatusMessageResponse = try await request(
            path: "/api/manage/user/update",
            method: .post,
            body: UserStatusUpdateRequest(userID: userID, isDisabled: isDisabled)
        )

        guard response.status == "success" else {
            throw APIError.server(response.message ?? "更新用户状态失败")
        }
    }

    func fetchSettings() async throws -> AppSettings {
        let response: SettingsEnvelope = try await request(path: "/api/settings")
        guard response.status == "success" else {
            throw APIError.server("获取设置失败")
        }
        return response.data
    }

    func saveSettings(_ settings: AppSettings) async throws {
        let response: StatusMessageResponse = try await request(
            path: "/api/settings",
            method: .post,
            body: settings
        )

        guard response.status == "success" else {
            throw APIError.server(response.message ?? "保存设置失败")
        }
    }

    func testTMDB() async throws -> String {
        let response: StatusMessageResponse = try await request(
            path: "/api/settings/test_tmdb",
            method: .post,
            body: EmptyRequest()
        )

        guard response.status == "success" else {
            throw APIError.server(response.message ?? "TMDB 测试失败")
        }

        return response.message ?? "TMDB 连通成功"
    }

    private func request<T: Decodable>(
        path: String,
        method: HTTPVerb = .get,
        query: [URLQueryItem] = [],
        body: some Encodable = EmptyRequest()
    ) async throws -> T {
        guard let url = buildURL(path: path, query: query) else {
            throw APIError.missingBaseURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if method != .get {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(body)
        }

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? ""
            if contentType.contains("text/html") && path != "/api/login" {
                throw APIError.unauthorized
            }

            guard (200 ..< 300).contains(httpResponse.statusCode) else {
                throw decodeServerError(from: data, statusCode: httpResponse.statusCode)
            }

            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decoding(error)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.transport(error)
        }
    }

    private func buildURL(path: String, query: [URLQueryItem]) -> URL? {
        guard let baseURL else {
            return nil
        }

        let suffix = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let composedPath = baseURL.path.isEmpty ? "/\(suffix)" : "\(baseURL.path)/\(suffix)"
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.path = composedPath.replacingOccurrences(of: "//", with: "/")
        components?.queryItems = query.isEmpty ? nil : query
        return components?.url
    }

    private func decodeServerError(from data: Data, statusCode: Int) -> APIError {
        if statusCode == 401 || statusCode == 403 {
            return .unauthorized
        }

        if let payload = try? decoder.decode(StatusMessageResponse.self, from: data) {
            return .server(payload.message ?? "请求失败")
        }

        return .server("请求失败 (\(statusCode))")
    }
}

private struct EmptyRequest: Encodable {}
