import SwiftUI

@MainActor
final class BotManagementViewModel: ObservableObject {
    @Published var settings = BotSettings()
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
            settings = try await api.fetchBotSettings()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            try await api.saveBotSettings(settings)
            message = "机器人配置已保存"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func testTelegram() async {
        do {
            message = try await api.testTelegramBot()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func testWeCom() async {
        do {
            message = try await api.testWeComBot()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct BotManagementView: View {
    @StateObject private var viewModel = BotManagementViewModel()

    var body: some View {
        Form {
            Section("Telegram") {
                TextField("Bot Token", text: $viewModel.settings.tgBotToken)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Chat ID", text: $viewModel.settings.tgChatID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section("企业微信") {
                TextField("Corp ID", text: $viewModel.settings.wecomCorpid)
                TextField("Corp Secret", text: $viewModel.settings.wecomCorpsecret)
                TextField("Agent ID", text: $viewModel.settings.wecomAgentid)
                TextField("To User", text: $viewModel.settings.wecomTouser)
                TextField("Proxy URL", text: $viewModel.settings.wecomProxyURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                TextField("Token", text: $viewModel.settings.wecomToken)
                TextField("AES Key", text: $viewModel.settings.wecomAESKey)
            }

            Section("开关") {
                Toggle("启用机器人", isOn: $viewModel.settings.enableBot)
                Toggle("启用通知", isOn: $viewModel.settings.enableNotify)
                Toggle("启用入库通知", isOn: $viewModel.settings.enableLibraryNotify)
            }

            Section("操作") {
                Button("保存配置") {
                    Task { await viewModel.save() }
                }
                .disabled(viewModel.isSaving)

                Button("测试 Telegram") {
                    Task { await viewModel.testTelegram() }
                }

                Button("测试企业微信") {
                    Task { await viewModel.testWeCom() }
                }
            }
        }
        .navigationTitle("机器人助手")
        .overlay {
            if viewModel.isLoading {
                ProgressView("正在读取 Bot 配置...")
            }
        }
        .task {
            if viewModel.settings == BotSettings() {
                await viewModel.load()
            }
        }
        .refreshable {
            await viewModel.load()
        }
        .alert(alertTitle, isPresented: alertBinding) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? viewModel.message ?? "")
        }
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil || viewModel.message != nil },
            set: { newValue in
                if !newValue {
                    viewModel.errorMessage = nil
                    viewModel.message = nil
                }
            }
        )
    }

    private var alertTitle: String {
        viewModel.errorMessage == nil ? "操作提示" : "操作失败"
    }
}
