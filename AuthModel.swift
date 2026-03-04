//
//  AuthModel.swift
//  EmbyPulse
//
//  Created by EmbyPulse Team on 2026/03/04.
//

import Foundation

// 认证模型
struct AuthResponse: Codable {
    let status: String
    let message: String?
    let token: String?
    let user: UserInfo?
    let servers: [Server]?
}

struct UserInfo: Codable, Identifiable {
    let id: String?
    let username: String
    let email: String?
    let role: String?
    let created_at: String?
    let last_login: String?
    let settings: UserSettings?
    
    var displayName: String {
        username
    }
}

struct UserSettings: Codable {
    let theme: String?
    let notification_enabled: Bool?
    let auto_refresh: Bool?
    let refresh_interval: Int?
}

struct Server: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let url: String
    let api_key: String
    let last_sync: String?
    let is_online: Bool?
    let version: String?
    
    static func == (lhs: Server, rhs: Server) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// 登录请求
struct LoginRequest: Codable {
    let username: String
    let password: String
}

// 注册请求
struct RegisterRequest: Codable {
    let username: String
    let password: String
    let email: String?
    let code: String  // 邀请码
}

// 服务器测试请求
struct ServerTestRequest: Codable {
    let url: String
    let api_key: String
}

// 服务器测试响应
struct ServerTestResponse: Codable {
    let status: String
    let message: String?
    let version: String?
    let name: String?
    let online: Bool?
}