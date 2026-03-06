import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    let onOpenRequestPortal: (() -> Void)?

    @State private var serverURL = ""
    @State private var username = ""
    @State private var password = ""

    init(onOpenRequestPortal: (() -> Void)? = nil) {
        self.onOpenRequestPortal = onOpenRequestPortal
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [.black, Color.blue.opacity(0.35), Color.purple.opacity(0.35)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        header
                        loginCard
                        footerNote
                    }
                    .padding()
                    .padding(.top, 32)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                serverURL = sessionStore.serverURL
                username = sessionStore.rememberedUsername
            }
            .alert("登录失败", isPresented: Binding(
                get: { sessionStore.errorMessage != nil },
                set: { newValue in
                    if !newValue {
                        sessionStore.errorMessage = nil
                    }
                }
            )) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(sessionStore.errorMessage ?? "")
            }
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 58, weight: .bold))
                .foregroundStyle(.white, .purple)

            Text("EmbyPulse iOS")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)

            Text("根据 EmbyPulse 面板文档构建的移动端管理应用")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.78))
                .multilineTextAlignment(.center)
        }
    }

    private var loginCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("连接到面板")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("面板地址")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("http://127.0.0.1:10307", text: $serverURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Emby 管理员账号")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("请输入用户名", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("密码")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                SecureField("请输入密码", text: $password)
                    .textFieldStyle(.roundedBorder)
            }

            Button {
                Task {
                    await sessionStore.login(
                        serverURL: serverURL,
                        username: username,
                        password: password
                    )
                }
            } label: {
                HStack {
                    Spacer()
                    if sessionStore.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("登录")
                            .fontWeight(.semibold)
                    }
                    Spacer()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(serverURL.isEmpty || username.isEmpty || password.isEmpty || sessionStore.isLoading)

            VStack(alignment: .leading, spacing: 6) {
                Label("默认使用 Emby 管理员账号登录", systemImage: "person.crop.circle.badge.checkmark")
                Label("登录后依赖服务端 Session Cookie 保持状态", systemImage: "lock.shield")
                Label("建议填写公网可访问的 EmbyPulse 地址", systemImage: "network")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            if let onOpenRequestPortal {
                Divider()
                Button {
                    onOpenRequestPortal()
                } label: {
                    HStack {
                        Spacer()
                        Label("进入求片广场", systemImage: "sparkles")
                        Spacer()
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(22)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
    }

    private var footerNote: some View {
        Text("如果是首次部署，请先在 Web 端完成 Emby API Key、TMDB Key 和 Webhook 等基础配置。")
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.72))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
    }
}
