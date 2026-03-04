//
//  NetworkService.swift
//  EmbyPulse
//
//  Created by EmbyPulse Team on 2026/03/04.
//

import Foundation
import Alamofire

class NetworkService {
    static let shared = NetworkService()
    
    private let baseURL: String
    private let session: Session
    private let logger = NetworkLogger()
    private var headers: HTTPHeaders = [
        "User-Agent": "EmbyPulse-iOS/1.0",
        "Accept": "application/json",
        "Content-Type": "application/json"
    ]
    
    private init() {
        self.baseURL = "http://localhost:8000"  // 默认值
        self.session = Session(
            configuration: .default,
            eventMonitors: [logger]
        )
    }
    
    func updateBaseURL(_ url: String) {
        // 移除末尾的斜杠
        var cleanURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanURL.hasSuffix("/") {
            cleanURL = String(cleanURL.dropLast())
        }
        UserDefaults.standard.set(cleanURL, forKey: "base_url")
        
        // 更新实例的 baseURL
        let _self = self
        _self.baseURL = cleanURL
    }
    
    func getBaseURL() -> String {
        return baseURL
    }
    
    // MARK: - 认证相关
    
    func login(username: String, password: String) async throws -> AuthResponse {
        return try await request(
            endpoint: "/auth/login",
            method: .post,
            parameters: ["username": username, "password": password]
        )
    }
    
    func register(username: String, password: String, email: String?, code: String) async throws -> AuthResponse {
        return try await request(
            endpoint: "/auth/register",
            method: .post,
            parameters: [
                "username": username,
                "password": password,
                "email": email ?? "",
                "code": code
            ]
        )
    }
    
    func logout(token: String) async throws -> AuthResponse {
        return try await request(
            endpoint: "/auth/logout",
            method: .post,
            headers: ["Authorization": "Bearer \(token)"]
        )
    }
    
    // MARK: - 服务器相关
    
    func testServer(url: String, apiKey: String) async throws -> ServerTestResponse {
        return try await request(
            endpoint: "/servers/test",
            method: .post,
            parameters: ["url": url, "api_key": apiKey]
        )
    }
    
    func getServers(token: String) async throws -> [Server] {
        let response: ServersResponse = try await request(
            endpoint: "/servers/list",
            method: .get,
            headers: ["Authorization": "Bearer \(token)"]
        )
        return response.servers
    }
    
    struct ServersResponse: Codable {
        let servers: [Server]
    }
    
    // MARK: - 仪表盘数据
    
    func getDashboardStats(token: String, serverId: Int?) async throws -> DashboardStats {
        var endpoint = "/stats/dashboard"
        if let serverId = serverId {
            endpoint += "?server_id=\(serverId)"
        }
        return try await request(
            endpoint: endpoint,
            method: .get,
            headers: ["Authorization": "Bearer \(token)"]
        )
    }
    
    func getOnlineUsers(token: String, serverId: Int?) async throws -> OnlineUsersResponse {
        var endpoint = "/stats/online"
        if let serverId = serverId {
            endpoint += "?server_id=\(serverId)"
        }
        return try await request(
            endpoint: endpoint,
            method: .get,
            headers: ["Authorization": "Bearer \(token)"]
        )
    }
    
    func getPlayActivities(token: String, serverId: Int?, page: Int = 1, pageSize: Int = 20) async throws -> PlayActivitiesResponse {
        var endpoint = "/stats/activities?page=\(page)&page_size=\(pageSize)"
        if let serverId = serverId {
            endpoint += "&server_id=\(serverId)"
        }
        return try await request(
            endpoint: endpoint,
            method: .get,
            headers: ["Authorization": "Bearer \(token)"]
        )
    }
    
    // MARK: - 通用请求方法
    
    private func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod,
        parameters: Parameters? = nil,
        headers: HTTPHeaders? = nil,
        encoding: ParameterEncoding = JSONEncoding.default
    ) async throws -> T {
        
        let url = baseURL + endpoint
        var requestHeaders = self.headers
        if let additionalHeaders = headers {
            additionalHeaders.forEach { requestHeaders.update($0) }
        }
        
        let task = session.request(
            url,
            method: method,
            parameters: parameters,
            encoding: encoding,
            headers: requestHeaders
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            task.responseDecodable(of: T.self) { response in
                switch response.result {
                case .success(let value):
                    continuation.resume(returning: value)
                case .failure(let error):
                    if let data = response.data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMessage = json["detail"] as? String {
                        continuation.resume(throwing: NetworkError.serverError(errorMessage))
                    } else {
                        continuation.resume(throwing: NetworkError.networkError(error))
                    }
                }
            }
        }
    }
}

// MARK: - 网络错误定义
enum NetworkError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case serverError(String)
    case unauthorized
    case notFound
    case rateLimit
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的URL地址"
        case .networkError(let error):
            return "网络连接失败: \(error.localizedDescription)"
        case .serverError(let message):
            return message
        case .unauthorized:
            return "认证失败，请重新登录"
        case .notFound:
            return "请求的资源不存在"
        case .rateLimit:
            return "请求过于频繁，请稍后重试"
        case .unknown:
            return "未知错误，请稍后重试"
        }
    }
}

// MARK: - 网络日志
class NetworkLogger: EventMonitor {
    let queue = DispatchQueue(label: "com.embypulse.networklogger", qos: .background)
    
    func request(_ request: Request, didCompleteTask task: URLSessionTask, with error: Error?) {
        #if DEBUG
        if let error = error {
            print("🔴 请求失败: \(request.request?.url?.absoluteString ?? "unknown") - \(error)")
        } else {
            print("✅ 请求完成: \(request.request?.url?.absoluteString ?? "unknown")")
        }
        #endif
    }
    
    func request<Value>(_ request: DataRequest, didParseResponse response: DataResponse<Value, AFError>) {
        #if DEBUG
        if let statusCode = response.response?.statusCode {
            let emoji = (200..<300).contains(statusCode) ? "✅" : "🔴"
            print("\(emoji) [\(statusCode)] \(request.request?.url?.absoluteString ?? "unknown")")
        }
        #endif
    }
}