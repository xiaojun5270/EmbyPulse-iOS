import SwiftUI

@MainActor
final class HistoryBrowserViewModel: ObservableObject {
    @Published var users: [UserSelectionOption] = [.all]
    @Published var selectedUserID = UserSelectionOption.all.id
    @Published var searchKeyword = ""
    @Published var entries: [HistoryEntry] = []
    @Published var pagination: PaginationInfo?
    @Published var currentPage = 1
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api: EmbyPulseAPI

    init(api: EmbyPulseAPI = .shared) {
        self.api = api
    }

    func loadUsersIfNeeded() async {
        guard users.count == 1 else { return }
        do {
            let remoteUsers = try await api.fetchUsers()
            users = [.all] + remoteUsers.map { UserSelectionOption(id: $0.id, name: $0.name) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refresh(resetPage: Bool = false) async {
        if resetPage { currentPage = 1 }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await api.fetchHistory(
                page: currentPage,
                limit: 15,
                userID: selectedUserID,
                keyword: searchKeyword
            )
            entries = response.data
            pagination = response.pagination
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func nextPage() async {
        guard let pagination, currentPage < pagination.totalPages else { return }
        currentPage += 1
        await refresh()
    }

    func previousPage() async {
        guard currentPage > 1 else { return }
        currentPage -= 1
        await refresh()
    }
}

struct HistoryBrowserView: View {
    @StateObject private var viewModel = HistoryBrowserViewModel()

    var body: some View {
        List {
            Section("筛选") {
                Picker("用户", selection: $viewModel.selectedUserID) {
                    ForEach(viewModel.users) { user in
                        Text(user.name).tag(user.id)
                    }
                }

                TextField("按片名检索", text: $viewModel.searchKeyword)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button("搜索") {
                    Task { await viewModel.refresh(resetPage: true) }
                }
            }

            Section("播放历史") {
                if viewModel.entries.isEmpty, !viewModel.isLoading {
                    EmptyStateView(
                        title: "暂无播放历史",
                        subtitle: "可以尝试更换用户、清空关键词或等待更多播放数据。",
                        symbol: "clock.badge.questionmark"
                    )
                } else {
                    ForEach(viewModel.entries) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(entry.itemName)
                                .font(.headline)

                            Text(entry.userName ?? "未知用户")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 10) {
                                if let itemType = entry.itemType {
                                    Text(itemType)
                                }
                                Text(entry.durationText ?? AppFormatting.durationText(seconds: entry.playDuration ?? 0))
                                if let clientName = entry.clientName, !clientName.isEmpty {
                                    Text(clientName)
                                }
                                if let deviceName = entry.deviceName, !deviceName.isEmpty {
                                    Text(deviceName)
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)

                            Text(entry.dateText ?? AppFormatting.shortDateTime(entry.dateCreated))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            if let pagination {
                Section("分页") {
                    HStack {
                        Button("上一页") {
                            Task { await viewModel.previousPage() }
                        }
                        .disabled(viewModel.currentPage <= 1)

                        Spacer()

                        Text("第 \(viewModel.currentPage) / \(max(pagination.totalPages, 1)) 页")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button("下一页") {
                            Task { await viewModel.nextPage() }
                        }
                        .disabled(viewModel.currentPage >= pagination.totalPages)
                    }

                    Text("共 \(pagination.total) 条记录")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("历史记录")
        .overlay {
            if viewModel.isLoading && viewModel.entries.isEmpty {
                ProgressView("正在加载历史...")
            }
        }
        .task {
            await viewModel.loadUsersIfNeeded()
            await viewModel.refresh()
        }
        .refreshable {
            await viewModel.refresh()
        }
        .onChange(of: viewModel.selectedUserID) { _ in
            Task { await viewModel.refresh(resetPage: true) }
        }
        .alert("加载失败", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { newValue in if !newValue { viewModel.errorMessage = nil } }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}
