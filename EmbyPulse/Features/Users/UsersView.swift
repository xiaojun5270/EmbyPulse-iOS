import SwiftUI

@MainActor
final class UsersViewModel: ObservableObject {
    @Published var users: [ManagedUser] = []
    @Published var invites: [InviteCode] = []
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var message: String?

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
            async let usersTask = api.fetchUsers()
            async let invitesTask = api.fetchInvites()
            users = try await usersTask
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            invites = try await invitesTask
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

    func createUser(name: String, password: String, expireDate: String?) async {
        do {
            try await api.createUser(name: name, password: password, expireDate: expireDate)
            message = "用户已创建"
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ user: ManagedUser) async {
        do {
            try await api.deleteUser(userID: user.id)
            message = "用户已删除"
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func generateInvites(days: Int, count: Int) async {
        do {
            let codes = try await api.generateInvites(days: days, count: count)
            message = "已生成邀请码：\(codes.joined(separator: ", "))"
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct UsersView: View {
    @StateObject private var viewModel = UsersViewModel()
    @EnvironmentObject private var sessionStore: SessionStore
    @State private var showingCreateUser = false
    @State private var showingInvites = false

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

                        Button("删除", role: .destructive) {
                            Task { await viewModel.delete(user) }
                        }
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
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Button("新建用户") {
                        showingCreateUser = true
                    }
                    Button("邀请码") {
                        showingInvites = true
                    }
                } label: {
                    Image(systemName: "plus.circle")
                }
            }
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
        .sheet(isPresented: $showingCreateUser) {
            NewUserSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showingInvites) {
            InviteManagementSheet(viewModel: viewModel)
        }
        .alert(alertTitle, isPresented: alertBinding) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? viewModel.message ?? "")
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

private struct NewUserSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: UsersViewModel
    @State private var name = ""
    @State private var password = ""
    @State private var expireDate = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("用户名", text: $name)
                SecureField("密码（可选）", text: $password)
                TextField("到期日 YYYY-MM-DD（可选）", text: $expireDate)
                    .textInputAutocapitalization(.never)
            }
            .navigationTitle("新建用户")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        Task {
                            await viewModel.createUser(name: name, password: password, expireDate: expireDate)
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

private struct InviteManagementSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: UsersViewModel
    @State private var days = 30
    @State private var count = 1

    var body: some View {
        NavigationStack {
            List {
                Section("生成邀请码") {
                    Stepper("有效期 \(days) 天", value: $days, in: 1 ... 365)
                    Stepper("数量 \(count)", value: $count, in: 1 ... 20)

                    Button("生成") {
                        Task { await viewModel.generateInvites(days: days, count: count) }
                    }
                    .buttonStyle(.borderedProminent)
                }

                Section("现有邀请码") {
                    if viewModel.invites.isEmpty {
                        Text("暂无邀请码")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.invites) { invite in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(invite.code)
                                    .font(.headline.monospaced())
                                HStack(spacing: 10) {
                                    if let days = invite.days { Text("\(days) 天") }
                                    if let usedCount = invite.usedCount { Text("已用 \(usedCount)") }
                                    if let maxUses = invite.maxUses { Text("上限 \(maxUses)") }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                if let usedBy = invite.usedBy, !usedBy.isEmpty {
                                    Text("使用者：\(usedBy)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("邀请码")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}
