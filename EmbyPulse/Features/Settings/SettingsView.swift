import SwiftUI

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var settings = AppSettings()
    @Published var hiddenUsersText = ""
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var message: String?
    @Published var errorMessage: String?

    private let api: EmbyPulseAPI

    init(api: EmbyPulseAPI = .shared) {
        self.api = api
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            settings = try await api.fetchSettings()
            hiddenUsersText = settings.hiddenUsers.joined(separator: ",")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func save() async {
        isSaving = true
        errorMessage = nil
        message = nil

        defer { isSaving = false }

        settings.hiddenUsers = hiddenUsersText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        do {
            try await api.saveSettings(settings)
            message = "配置已保存"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func testTMDB() async {
        do {
            message = try await api.testTMDB()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func testMoviePilot() async {
        do {
            message = try await api.testMoviePilot(
                url: settings.moviePilotURL,
                token: settings.moviePilotToken
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @EnvironmentObject private var sessionStore: SessionStore

    var body: some View {
        Form {
            Section("Emby 连接") {
                TextField("Emby Host", text: $viewModel.settings.embyHost)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()

                TextField("Emby API Key", text: $viewModel.settings.embyAPIKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                TextField("Emby Public URL", text: $viewModel.settings.embyPublicURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
            }

            Section("第三方服务") {
                TextField("TMDB API Key", text: $viewModel.settings.tmdbAPIKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                TextField("Proxy URL", text: $viewModel.settings.proxyURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()

                TextField("MoviePilot URL", text: $viewModel.settings.moviePilotURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()

                TextField("MoviePilot Token", text: $viewModel.settings.moviePilotToken)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section("通知与文案") {
                TextField("Webhook Token", text: $viewModel.settings.webhookToken)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                TextField("欢迎语", text: $viewModel.settings.welcomeMessage, axis: .vertical)
                    .lineLimit(3 ... 6)

                TextField("客户端下载地址", text: $viewModel.settings.clientDownloadURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()

                TextField("面板外链地址", text: $viewModel.settings.pulseURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
            }

            Section("高级") {
                TextField("隐藏用户 ID（逗号分隔）", text: $viewModel.hiddenUsersText, axis: .vertical)
                    .lineLimit(2 ... 5)

                Button("测试 TMDB 连通性") {
                    Task { await viewModel.testTMDB() }
                }

                Button("测试 MoviePilot 连通性") {
                    Task { await viewModel.testMoviePilot() }
                }

                Button {
                    Task { await viewModel.save() }
                } label: {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Text("保存配置")
                    }
                }
                .disabled(viewModel.isSaving)
            }

            Section("账户") {
                LabeledContent("当前面板", value: sessionStore.serverURL)

                Button("退出登录", role: .destructive) {
                    sessionStore.logout()
                }
            }
        }
        .navigationTitle("系统设置")
        .overlay {
            if viewModel.isLoading {
                ProgressView("正在读取设置...")
            }
        }
        .task {
            if viewModel.settings == AppSettings() {
                await viewModel.load()
            }
        }
        .refreshable {
            await viewModel.load()
        }
        .alert(alertTitle, isPresented: alertBinding) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.message != nil || viewModel.errorMessage != nil },
            set: { newValue in
                if !newValue {
                    viewModel.message = nil
                    viewModel.errorMessage = nil
                }
            }
        )
    }

    private var alertTitle: String {
        viewModel.errorMessage == nil ? "操作提示" : "操作失败"
    }

    private var alertMessage: String {
        viewModel.errorMessage ?? viewModel.message ?? ""
    }
}
