//
//  AuthView.swift
//  EmbyPulse
//
//  Created by EmbyPulse Team on 2026/03/04.
//

import SwiftUI

struct AuthView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var serverManager: ServerManager
    
    @State private var selectedTab: AuthTab = .login
    @State private var serverConfig = ServerConfig()
    @State private var showingServerConfig = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 应用Logo和标题
                    appHeader
                    
                    // 服务器配置提示（如果没有配置）
                    if serverManager.servers.isEmpty {
                        serverConfigButton
                    }
                    
                    // 认证标签页
                    authTabs
                    
                    // 认证表单
                    Group {
                        switch selectedTab {
                        case .login:
                            LoginForm()
                        case .register:
                            RegisterForm()
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
                    
                    Spacer()
                }
                .padding()
            }
            .background(Color(.secondarySystemBackground))
            .navigationBarHidden(true)
            .sheet(isPresented: $showingServerConfig) {
                ServerConfigView(config: $serverConfig)
            }
            .alert("错误", isPresented: .constant(authManager.lastError != nil)) {
                Button("确定") {
                    authManager.clearError()
                }
            } message: {
                if let error = authManager.lastError {
                    Text(error)
                }
            }
        }
    }
    
    // MARK: - 子视图
    
    private var appHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 60))
                .foregroundStyle(LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            
            Text("Emby Pulse")
                .font(.largeTitle.bold())
                .foregroundColor(.primary)
            
            Text("Emby 服务器数据分析平台")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
        .padding(.bottom, 20)
    }
    
    private var authTabs: some View {
        Picker("认证方式", selection: $selectedTab) {
            Text("登录").tag(AuthTab.login)
            Text("注册").tag(AuthTab.register)
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 300)
    }
    
    private var serverConfigButton: some View {
        Button(action: { showingServerConfig = true }) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("请先配置 Emby Pulse 服务器")
                Image(systemName: "chevron.right")
                    .font(.caption)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(.orange.opacity(0.1))
            .foregroundColor(.orange)
            .clipShape(Capsule())
        }
    }
}

// MARK: - 登录表单

struct LoginForm: View {
    @EnvironmentObject var authManager: AuthManager
    
    @State private var username = ""
    @State private var password = ""
    @State private var rememberMe = true
    @FocusState private var focusedField: Field?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("登录到您的账户")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // 用户名输入
            VStack(alignment: .leading, spacing: 6) {
                Label("用户名", systemImage: "person.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("请输入用户名", text: $username)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .username)
            }
            
            // 密码输入
            VStack(alignment: .leading, spacing: 6) {
                Label("密码", systemImage: "key.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                SecureField("请输入密码", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .password)
            }
            
            // 记住我选项
            Toggle(isOn: $rememberMe) {
                Text("保持登录状态")
                    .font(.caption)
            }
            .toggleStyle(.switch)
            
            // 登录按钮
            Button(action: performLogin) {
                if authManager.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text("登录")
                        .fontWeight(.semibold)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(username.isEmpty || password.isEmpty || authManager.isLoading)
            .frame(maxWidth: .infinity)
            
            // 忘记密码链接
            Button("忘记密码？") {
                // TODO: 实现密码重置
            }
            .font(.caption)
            .foregroundColor(.blue)
        }
        .onSubmit {
            switch focusedField {
            case .username:
                focusedField = .password
            case .password:
                performLogin()
            default:
                break
            }
        }
    }
    
    private func performLogin() {
        guard !username.isEmpty && !password.isEmpty else { return }
        
        Task {
            do {
                try await authManager.login(username: username, password: password)
            } catch {
                // 错误已由 AuthManager 处理
            }
        }
    }
    
    enum Field {
        case username, password
    }
}

// MARK: - 注册表单

struct RegisterForm: View {
    @EnvironmentObject var authManager: AuthManager
    
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var inviteCode = ""
    @FocusState private var focusedField: RegisterField?
    
    var body: some View {
        VStack(spacing: 16) {
            Text("创建新账户")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // 用户名
            inputField(label: "用户名", icon: "person.fill", placeholder: "请输入用户名", text: $username, field: .username)
            
            // 邮箱（可选）
            inputField(label: "邮箱（可选）", icon: "envelope.fill", placeholder: "请输入邮箱地址", text: $email, field: .email)
            
            // 密码
            passwordField(label: "密码", icon: "key.fill", placeholder: "请输入密码", text: $password, field: .password)
            
            // 确认密码
            passwordField(label: "确认密码", icon: "key.fill", placeholder: "请再次输入密码", text: $confirmPassword, field: .confirmPassword)
            
            // 邀请码
            inputField(label: "邀请码", icon: "ticket.fill", placeholder: "请输入邀请码", text: $inviteCode, field: .inviteCode)
            
            // 注册按钮
            Button(action: performRegistration) {
                if authManager.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text("注册账户")
                        .fontWeight(.semibold)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isFormValid || authManager.isLoading)
            .frame(maxWidth: .infinity)
            
            // 密码规则提示
            passwordRules
        }
    }
    
    private func inputField(label: String, icon: String, placeholder: String, text: Binding<String>, field: RegisterField) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(label, systemImage: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: field)
        }
    }
    
    private func passwordField(label: String, icon: String, placeholder: String, text: Binding<String>, field: RegisterField) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(label, systemImage: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            
            SecureField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: field)
        }
    }
    
    private var passwordRules: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("密码要求：")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            ForEach(passwordRequirements) { requirement in
                HStack(spacing: 6) {
                    Image(systemName: requirement.isMet ? "checkmark.circle.fill" : "circle")
                        .font(.caption2)
                        .foregroundColor(requirement.isMet ? .green : .secondary)
                    Text(requirement.text)
                        .font(.caption2)
                        .foregroundColor(requirement.isMet ? .green : .secondary)
                }
            }
        }
        .padding(.top, 8)
    }
    
    private var passwordRequirements: [PasswordRequirement] {
        [
            PasswordRequirement(id: 0, text: "至少8个字符", isMet: password.count >= 8),
            PasswordRequirement(id: 1, text: "包含大写字母", isMet: password.rangeOfCharacter(from: .uppercaseLetters) != nil),
            PasswordRequirement(id: 2, text: "包含小写字母", isMet: password.rangeOfCharacter(from: .lowercaseLetters) != nil),
            PasswordRequirement(id: 3, text: "包含数字", isMet: password.rangeOfCharacter(from: .decimalDigits) != nil),
            PasswordRequirement(id: 4, text: "密码匹配", isMet: !password.isEmpty && password == confirmPassword),
        ]
    }
    
    private var isFormValid: Bool {
        !username.isEmpty &&
        password.count >= 8 &&
        password == confirmPassword &&
        !inviteCode.isEmpty
    }
    
    private func performRegistration() {
        guard isFormValid else { return }
        
        Task {
            do {
                try await authManager.register(username: username, password: password, email: email.isEmpty ? nil : email, code: inviteCode)
            } catch {
                // 错误已由 AuthManager 处理
            }
        }
    }
    
    struct PasswordRequirement: Identifiable {
        let id: Int
        let text: String
        let isMet: Bool
    }
    
    enum RegisterField {
        case username, email, password, confirmPassword, inviteCode
    }
}

// MARK: - 服务器配置

struct ServerConfigView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var config: ServerConfig
    
    var body: some View {
        NavigationStack {
            Form {
                Section("服务器信息") {
                    TextField("服务器地址", text: $config.url)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    
                    TextField("API密钥", text: $config.apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                
                Section {
                    Button("测试连接") {
                        // TODO: 实现连接测试
                    }
                    
                    Button("保存配置", action: saveConfig)
                        .disabled(config.url.isEmpty || config.apiKey.isEmpty)
                }
            }
            .navigationTitle("配置服务器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func saveConfig() {
        // TODO: 保存服务器配置
        dismiss()
    }
}

// MARK: - 辅助类型

enum AuthTab {
    case login
    case register
}

struct ServerConfig {
    var url: String = ""
    var apiKey: String = ""
}

#Preview {
    AuthView()
        .environmentObject(AuthManager())
        .environmentObject(ServerManager())
}