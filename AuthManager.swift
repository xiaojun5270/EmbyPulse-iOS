//
//  AuthManager.swift
//  EmbyPulse
//
//  Created by EmbyPulse Team on 2026/03/04.
//

import Foundation
import KeychainAccess
import Combine

class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    private let keychain = Keychain(service: "com.embypulse.token")
    private let userDefaults = UserDefaults.standard
    
    // 发布认证状态变化
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: UserInfo?
    @Published var authToken: String?
    @Published var isLoading: Bool = false
    @Published var lastError: String?
    
    private let networkService = NetworkService.shared
    
    init() {
        // 从 Keychain 恢复 token
        restoreAuth()
    }
    
    // MARK: - 认证操作
    
    func login(username: String, password: String) async throws {
        isLoading = true
        lastError = nil
        
        defer { isLoading = false }
        
        do {
            let response = try await networkService.login(username: username, password: password)
            
            guard response.status == "success" else {
                throw AuthError.loginFailed(response.message ?? "登录失败")
            }
            
            guard let token = response.token else {
                throw AuthError.invalidResponse("缺少认证令牌")
            }
            
            // 保存认证信息
            saveAuth(token: token, user: response.user)
            
            // 更新状态
            await MainActor.run {
                self.authToken = token
                self.currentUser = response.user
                self.isAuthenticated = true
                self.lastError = nil
            }
            
            // 记录登录成功
            log("用户登录成功: \(username)")
            
        } catch {
            await MainActor.run {
                self.lastError = error.localizedDescription
            }
            log("登录失败: \(error)")
            throw error
        }
    }
    
    func logout() async {
        guard let token = authToken else { return }
        
        isLoading = true
        
        do {
            // 通知服务器登出（可选）
            _ = try await networkService.logout(token: token)
        } catch {
            log("服务器登出失败: \(error)")
        }
        
        // 清除本地认证信息
        clearAuth()
        
        await MainActor.run {
            self.authToken = nil
            self.currentUser = nil
            self.isAuthenticated = false
            self.isLoading = false
        }
        
        log("用户登出成功")
    }
    
    func register(username: String, password: String, email: String?, code: String) async throws {
        isLoading = true
        lastError = nil
        
        defer { isLoading = false }
        
        do {
            let response = try await networkService.register(username: username, password: password, email: email, code: code)
            
            guard response.status == "success" else {
                throw AuthError.registrationFailed(response.message ?? "注册失败")
            }
            
            guard let token = response.token else {
                throw AuthError.invalidResponse("缺少认证令牌")
            }
            
            // 保存认证信息
            saveAuth(token: token, user: response.user)
            
            // 更新状态
            await MainActor.run {
                self.authToken = token
                self.currentUser = response.user
                self.isAuthenticated = true
                self.lastError = nil
            }
            
            // 记录注册成功
            log("用户注册成功: \(username)")
            
        } catch {
            await MainActor.run {
                self.lastError = error.localizedDescription
            }
            log("注册失败: \(error)")
            throw error
        }
    }
    
    // MARK: - 认证持久化
    
    private func saveAuth(token: String, user: UserInfo?) {
        // 将 Token 保存在 Keychain 中
        try? keychain.set(token, key: "auth_token")
        
        // 将用户信息保存在 UserDefaults 中
        if let user = user {
            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(user) {
                userDefaults.set(encoded, forKey: "current_user")
            }
        }
        
        userDefaults.set(true, forKey: "is_authenticated")
        userDefaults.synchronize()
    }
    
    private func restoreAuth() {
        // 从 Keychain 恢复 Token
        if let token = try? keychain.getString("auth_token") {
            self.authToken = token
            
            // 从 UserDefaults 恢复用户信息
            if let userData = userDefaults.data(forKey: "current_user"),
               let user = try? JSONDecoder().decode(UserInfo.self, from: userData) {
                self.currentUser = user
            }
            
            // 检查是否需要自动认证
            let wasAuthenticated = userDefaults.bool(forKey: "is_authenticated")
            self.isAuthenticated = wasAuthenticated && token.isEmpty == false
            
            log("认证状态已恢复: \(isAuthenticated ? "已登录" : "未登录")")
        }
    }
    
    private func clearAuth() {
        // 清除 Keychain 中的 Token
        try? keychain.remove("auth_token")
        
        // 清除 UserDefaults 中的用户信息
        userDefaults.removeObject(forKey: "current_user")
        userDefaults.removeObject(forKey: "is_authenticated")
        userDefaults.synchronize()
    }
    
    // MARK: - Token 验证和刷新
    
    func validateToken() async -> Bool {
        guard let token = authToken, !token.isEmpty else {
            isAuthenticated = false
            return false
        }
        
        // 这里可以添加 Token 验证逻辑
        // 例如：向服务器发送简单的验证请求
        
        // 暂时直接返回 true，假设 Token 有效
        // 在实际应用中，可能需要:
        // 1. 检查 Token 过期时间
        // 2. 向服务器验证 Token
        // 3. 自动刷新 Token
        
        return true
    }
    
    // MARK: - 工具函数
    
    private func log(_ message: String) {
        print("[AuthManager] \(message)")
    }
    
    func clearError() {
        lastError = nil
    }
}

// MARK: - 认证错误定义
enum AuthError: Error, LocalizedError {
    case loginFailed(String)
    case registrationFailed(String)
    case invalidResponse(String)
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .loginFailed(let message):
            return "登录失败: \(message)"
        case .registrationFailed(let message):
            return "注册失败: \(message)"
        case .invalidResponse(let message):
            return "服务器响应异常: \(message)"
        case .networkError(let message):
            return "网络连接失败: \(message)"
        }
    }
}