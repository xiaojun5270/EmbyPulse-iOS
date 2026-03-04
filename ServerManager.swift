//
//  ServerManager.swift
//  EmbyPulse
//
//  Created by EmbyPulse Team on 2026/03/04.
//

import Foundation
import Combine

class ServerManager: ObservableObject {
    static let shared = ServerManager()
    
    private let userDefaults = UserDefaults.standard
    private let networkService = NetworkService.shared
    
    // 发布的属性
    @Published var servers: [Server] = []
    @Published var currentServer: Server?
    @Published var isLoading: Bool = false
    @Published var lastError: String?
    @Published var lastSyncTime: Date?
    
    init() {
        // 加载已保存的服务器列表
        loadServers()
    }
    
    // MARK: - 服务器管理
    
    func loadServers() {
        guard let serversData = userDefaults.data(forKey: "saved_servers") else { return }
        
        do {
            let decoder = JSONDecoder()
            let savedServers = try decoder.decode([Server].self, from: serversData)
            servers = savedServers
            
            // 尝试恢复当前选中的服务器
            if let currentServerId = userDefaults.integer(forKey: "current_server_id") as? Int,
               let server = servers.first(where: { $0.id == currentServerId }) {
                currentServer = server
                // 更新网络服务的 baseURL（如果服务器配置了URL）
                networkService.updateBaseURL(server.url)
            }
            
            log("已加载 \(servers.count) 个服务器")
        } catch {
            log("加载服务器列表失败: \(error)")
        }
    }
    
    func saveServers() {
        do {
            let encoder = JSONEncoder()
            let serversData = try encoder.encode(servers)
            userDefaults.set(serversData, forKey: "saved_servers")
            
            // 保存当前服务器ID
            if let currentServer = currentServer {
                userDefaults.set(currentServer.id, forKey: "current_server_id")
            }
            
            userDefaults.synchronize()
            log("已保存 \(servers.count) 个服务器")
        } catch {
            log("保存服务器列表失败: \(error)")
        }
    }
    
    func addServer(_ server: Server) {
        // 检查是否已存在相同ID或URL的服务器
        if servers.contains(where: { $0.id == server.id }) {
            updateServer(server)
        } else {
            servers.append(server)
            saveServers()
            log("已添加服务器: \(server.name)")
        }
    }
    
    func updateServer(_ server: Server) {
        if let index = servers.firstIndex(where: { $0.id == server.id }) {
            servers[index] = server
            saveServers()
            log("已更新服务器: \(server.name)")
        }
    }
    
    func removeServer(_ server: Server) {
        servers.removeAll { $0.id == server.id }
        saveServers()
        
        // 如果删除的是当前服务器，重置当前服务器
        if currentServer?.id == server.id {
            currentServer = servers.first
            if let newServer = currentServer {
                networkService.updateBaseURL(newServer.url)
            }
        }
        
        log("已删除服务器: \(server.name)")
    }
    
    func setCurrentServer(_ server: Server) {
        currentServer = server
        networkService.updateBaseURL(server.url)
        saveServers()
        
        log("已切换当前服务器: \(server.name)")
        
        // 触发数据刷新
        Task {
            await refreshServerStatus(server)
        }
    }
    
    // MARK: - 服务器测试
    
    func testServerConnection(url: String, apiKey: String) async throws -> ServerTestResponse {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await networkService.testServer(url: url, apiKey: apiKey)
            
            await MainActor.run {
                self.lastError = response.status == "success" ? nil : response.message
            }
            
            log("服务器测试: \(response.status) - \(response.message ?? "无消息")")
            return response
            
        } catch {
            log("服务器测试失败: \(error)")
            throw error
        }
    }
    
    // MARK: - 服务器状态同步
    
    func refreshAllServers() async {
        isLoading = true
        
        // 从服务器获取最新的服务器列表
        if let authManager = (NSClassFromString("AuthManager") as? AnyObject) as? AuthManager,
           let token = authManager.authToken {
            do {
                let remoteServers = try await networkService.getServers(token: token)
                
                await MainActor.run {
                    // 合并远程和本地服务器
                    for remoteServer in remoteServers {
                        if let localIndex = servers.firstIndex(where: { $0.id == remoteServer.id }) {
                            // 更新已有服务器
                            var updatedServer = remoteServer
                            // 保留本地的一些设置（如果需要的话）
                            servers[localIndex] = updatedServer
                        } else {
                            // 添加新服务器
                            servers.append(remoteServer)
                        }
                    }
                    
                    self.saveServers()
                    self.lastSyncTime = Date()
                    self.lastError = nil
                }
                
                log("已同步 \(remoteServers.count) 个服务器")
                
            } catch {
                await MainActor.run {
                    self.lastError = error.localizedDescription
                }
                log("同步服务器失败: \(error)")
            }
        }
        
        isLoading = false
    }
    
    func refreshServerStatus(_ server: Server? = nil) async {
        let targetServer = server ?? currentServer
        guard let server = targetServer else { return }
        
        do {
            let response = try await networkService.testServer(url: server.url, apiKey: server.api_key)
            
            await MainActor.run {
                // 更新服务器状态
                if let index = servers.firstIndex(where: { $0.id == server.id }) {
                    var updatedServer = server
                    updatedServer.is_online = response.online
                    updatedServer.version = response.version
                    servers[index] = updatedServer
                    
                    // 如果当前服务器被更新，也更新 currentServer
                    if currentServer?.id == server.id {
                        currentServer = updatedServer
                    }
                }
                
                self.saveServers()
                self.lastError = nil
            }
            
            log("服务器状态已更新: \(server.name)")
            
        } catch {
            log("刷新服务器状态失败: \(error)")
        }
    }
    
    // MARK: - 工具函数
    
    func getServerStats(serverId: Int? = nil) -> (total: Int, online: Int) {
        let targetServers = serverId == nil ? servers : servers.filter { $0.id == serverId }
        let onlineCount = targetServers.filter { $0.is_online == true }.count
        return (targetServers.count, onlineCount)
    }
    
    func getServerById(_ id: Int) -> Server? {
        servers.first(where: { $0.id == id })
    }
    
    private func log(_ message: String) {
        print("[ServerManager] \(message)")
    }
    
    func clearError() {
        lastError = nil
    }
    
    // MARK: - 服务器排序
    
    func sortServers(by criteria: SortCriteria = .name) {
        switch criteria {
        case .name:
            servers.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .addedDate:
            // 这里需要服务器有添加时间字段，暂时先按ID排序
            servers.sort { $0.id < $1.id }
        case .onlineStatus:
            servers.sort { ($0.is_online ?? false) && !($1.is_online ?? false) }
        }
        saveServers()
    }
    
    enum SortCriteria {
        case name
        case addedDate
        case onlineStatus
    }
}