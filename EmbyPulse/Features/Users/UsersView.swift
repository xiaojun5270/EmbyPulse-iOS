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

    func batchAction(userIDs: [String], action: String, value: String? = nil) async {
        do {
            try await api.batchUpdateUsers(userIDs: userIDs, action: action, value: value)
            message = "批量操作完成"
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

    func deleteInvite(_ code: String) async {
        do {
            try await api.deleteInvites(codes: [code])
            message = "邀请码已删除"
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
final class UserDetailViewModel: ObservableObject {
    @Published var detail: ManagedUserDetail?
    @Published var expireDate: String = ""
    @Published var password: String = ""
    @Published var isDisabled = false
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var message: String?

    let user: ManagedUser
    private let api: EmbyPulseAPI

    init(user: ManagedUser, api: EmbyPulseAPI = .shared) {
        self.user = user
        self.api = api
        self.expireDate = user.expireDate ?? ""
        self.isDisabled = user.isDisabled
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            detail = try await api.fetchUserDetail(userID: user.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            try await api.updateUserDetail(
                UserDetailUpdateRequest(
                    userID: user.id,
                    password: password.isEmpty ? nil : password,
                    isDisabled: isDisabled,
                    expireDate: expireDate,
                    enableAllFolders: detail?.enableAllFolders,
                    enabledFolders: detail?.enabledFolders,
                    excludedSubFolders: detail?.excludedSubFolders,
                    enableDownloading: detail?.enableDownloading,
                    enableVideoTranscoding: detail?.enableVideoTranscoding,
                    enableAudioTranscoding: detail?.enableAudioTranscoding,
                    maxParentalRating: detail?.maxParentalRating
                )
            )
            password = ""
            message = "用户详情已保存"
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct UsersView: View {
    @StateObject private var viewModel = UsersViewModel()
    @EnvironmentObject private var sessionStore: SessionStore

    @State private var activeSheet: UsersSheet?
    @State private var selectionMode = false
    @State private var selectedUserIDs: Set<String> = []

    var body: some View {
        List {
            if selectionMode {
                Section("批量操作") {
                    Text("已选择 \(selectedUserIDs.count) 个用户")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            Button("批量启用") {
                                Task { await performBatch(action: "enable") }
                            }
                            .buttonStyle(.bordered)
                            .disabled(selectedUserIDs.isEmpty)

                            Button("批量禁用") {
                                Task { await performBatch(action: "disable") }
                            }
                            .buttonStyle(.bordered)
                            .disabled(selectedUserIDs.isEmpty)

                            Button("续期 +30 天") {
                                Task { await performBatch(action: "renew", value: "+30") }
                            }
                            .buttonStyle(.bordered)
                            .disabled(selectedUserIDs.isEmpty)

                            Button("批量删除", role: .destructive) {
                                Task { await performBatch(action: "delete") }
                            }
                            .buttonStyle(.bordered)
                            .disabled(selectedUserIDs.isEmpty)
                        }
                    }
                }
            }

            if viewModel.filteredUsers.isEmpty, !viewModel.isLoading {
                EmptyStateView(
                    title: "暂无用户",
                    subtitle: "用户列表会显示 Emby 账号、管理员标记、禁用状态、到期时间、最近登录。",
                    symbol: "person.crop.circle.badge.questionmark"
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(viewModel.filteredUsers) { user in
                    Button {
                        if selectionMode {
                            toggleSelection(user.id)
                        } else {
                            activeSheet = .detail(user)
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            if selectionMode {
                                Image(systemName: selectedUserIDs.contains(user.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedUserIDs.contains(user.id) ? .blue : .secondary)
                            }

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

                            Spacer()

                            if !selectionMode {
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
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
                        activeSheet = .newUser
                    }
                    Button("邀请码") {
                        activeSheet = .invites
                    }
                } label: {
                    Image(systemName: "plus.circle")
                }
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(selectionMode ? "完成" : "批量") {
                    selectionMode.toggle()
                    if !selectionMode {
                        selectedUserIDs.removeAll()
                    }
                }

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
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .newUser:
                NewUserSheet(viewModel: viewModel)
            case .invites:
                InviteManagementSheet(viewModel: viewModel)
            case .detail(let user):
                UserDetailSheet(user: user)
            }
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

    private func toggleSelection(_ userID: String) {
        if selectedUserIDs.contains(userID) {
            selectedUserIDs.remove(userID)
        } else {
            selectedUserIDs.insert(userID)
        }
    }

    private func performBatch(action: String, value: String? = nil) async {
        guard !selectedUserIDs.isEmpty else { return }
        await viewModel.batchAction(userIDs: Array(selectedUserIDs), action: action, value: value)
        selectedUserIDs.removeAll()
        selectionMode = false
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

private enum UsersSheet: Identifiable {
    case newUser
    case invites
    case detail(ManagedUser)

    var id: String {
        switch self {
        case .newUser:
            return "new-user"
        case .invites:
            return "invites"
        case .detail(let user):
            return "detail-\(user.id)"
        }
    }
}

private struct UserDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: UserDetailViewModel

    init(user: ManagedUser) {
        _viewModel = StateObject(wrappedValue: UserDetailViewModel(user: user))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基础信息") {
                    LabeledContent("用户名", value: viewModel.user.name)
                    LabeledContent("User ID", value: viewModel.user.id)
                    Toggle("禁用账号", isOn: $viewModel.isDisabled)
                    TextField("到期日 YYYY-MM-DD", text: $viewModel.expireDate)
                        .textInputAutocapitalization(.never)
                }

                Section("密码") {
                    SecureField("重置密码（留空则不修改）", text: $viewModel.password)
                }

                if let detail = viewModel.detail {
                    Section("权限") {
                        Toggle("允许全部媒体库", isOn: Binding(
                            get: { detail.enableAllFolders },
                            set: { viewModel.detail?.enableAllFolders = $0 }
                        ))
                        Toggle("允许下载", isOn: Binding(
                            get: { detail.enableDownloading },
                            set: { viewModel.detail?.enableDownloading = $0 }
                        ))
                        Toggle("允许视频转码", isOn: Binding(
                            get: { detail.enableVideoTranscoding },
                            set: { viewModel.detail?.enableVideoTranscoding = $0 }
                        ))
                        Toggle("允许音频转码", isOn: Binding(
                            get: { detail.enableAudioTranscoding },
                            set: { viewModel.detail?.enableAudioTranscoding = $0 }
                        ))
                        Stepper(
                            "家长分级：\(detail.maxParentalRating ?? -1)",
                            value: Binding(
                                get: { detail.maxParentalRating ?? -1 },
                                set: { viewModel.detail?.maxParentalRating = $0 == -1 ? nil : $0 }
                            ),
                            in: -1 ... 18
                        )
                    }
                }
            }
            .navigationTitle("用户详情")
            .overlay {
                if viewModel.isLoading {
                    ProgressView("正在加载详情...")
                }
            }
            .task {
                await viewModel.load()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task { await viewModel.save() }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
            .alert(viewModel.errorMessage == nil ? "操作提示" : "操作失败", isPresented: Binding(
                get: { viewModel.errorMessage != nil || viewModel.message != nil },
                set: { newValue in
                    if !newValue {
                        viewModel.errorMessage = nil
                        viewModel.message = nil
                    }
                }
            )) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? viewModel.message ?? "")
            }
        }
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
                            .swipeActions {
                                Button("删除", role: .destructive) {
                                    Task { await viewModel.deleteInvite(invite.code) }
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
