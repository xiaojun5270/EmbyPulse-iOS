import SwiftUI

@MainActor
final class UsersViewModel: ObservableObject {
    @Published var users: [ManagedUser] = []
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api: EmbyPulseAPI

    init(api: EmbyPulseAPI = .shared) {
        self.api = api
    }

    var filteredUsers: [ManagedUser] {
        guard !searchText.isEmpty else { return users }

        return users.filter { user in
            user.name.localizedCaseInsensitiveContains(searchText) ||
            user.id.localizedCaseInsensitiveContains(searchText)
        }
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            users = try await api.fetchUsers()
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggle(_ user: ManagedUser) async {
        do {
            try await api.updateUserStatus(userID: user.id, isDisabled: !user.isDisabled)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct UsersView: View {
    @StateObject private var viewModel = UsersViewModel()
    @EnvironmentObject private var sessionStore: SessionStore

    var body: some View {
        List {
            if viewModel.filteredUsers.isEmpty, !viewModel.isLoading {
                EmptyStateView(
                    title: "暂无用户",
                    subtitle: "用户列表会显示 Emby 账号、管理员标记和过期时间。",
                    symbol: "person.crop.circle.badge.questionmark"
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(viewModel.filteredUsers) { user in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 12) {
                            avatar(for: user)

                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(user.name)
                                        .font(.headline)

                                    if user.isAdmin {
                                        StatusPill(text: "管理员", tint: .purple)
                                    }

                                    if user.isDisabled {
                                        StatusPill(text: "已禁用", tint: .red)
                                    } else {
                                        StatusPill(text: "正常", tint: .green)
                                    }
                                }

                                Text(user.id)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)

                                if let expireDate = user.expireDate, !expireDate.isEmpty {
                                    Label("到期：\(expireDate)", systemImage: "calendar.badge.clock")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                if let lastLogin = user.lastLoginDate, !lastLogin.isEmpty {
                                    Label(
                                        "最近登录：\(AppFormatting.shortDateTime(lastLogin))",
                                        systemImage: "clock.arrow.circlepath"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Button(user.isDisabled ? "启用账号" : "禁用账号") {
                            Task { await viewModel.toggle(user) }
                        }
                        .buttonStyle(user.isDisabled ? .borderedProminent : .bordered)
                        .controlSize(.small)
                    }
                    .padding(.vertical, 8)
                    .swipeActions {
                        Button(user.isDisabled ? "启用" : "禁用") {
                            Task { await viewModel.toggle(user) }
                        }
                        .tint(user.isDisabled ? .green : .red)
                    }
                }
            }
        }
        .overlay {
            if viewModel.isLoading && viewModel.users.isEmpty {
                ProgressView("正在加载用户...")
            }
        }
        .navigationTitle("用户管理")
        .searchable(text: $viewModel.searchText, prompt: "搜索用户名或 User ID")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .task {
            if viewModel.users.isEmpty {
                await viewModel.refresh()
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
        .alert("操作失败", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { newValue in
                if !newValue {
                    viewModel.errorMessage = nil
                }
            }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private func avatar(for user: ManagedUser) -> some View {
        if let imageURL = sessionStore.assetURL(path: "/api/user/image/\(user.id)") {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .padding(10)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 52, height: 52)
            .background(Color.white.opacity(0.08))
            .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 52, height: 52)
                .foregroundStyle(.secondary)
        }
    }
}
