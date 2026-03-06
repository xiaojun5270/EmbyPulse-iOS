import SwiftUI

@MainActor
final class ContentRankingsViewModel: ObservableObject {
    @Published var users: [UserSelectionOption] = [.all]
    @Published var selectedUserID = UserSelectionOption.all.id
    @Published var selectedCategory: ContentCategory = .all
    @Published var selectedSort: RankingSort = .count
    @Published var items: [RankedItem] = []
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

    func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            items = try await api.fetchTopMovies(
                userID: selectedUserID,
                category: selectedCategory,
                sortBy: selectedSort
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ContentRankingsView: View {
    @StateObject private var viewModel = ContentRankingsViewModel()
    @EnvironmentObject private var sessionStore: SessionStore

    var body: some View {
        List {
            Section {
                Picker("用户", selection: $viewModel.selectedUserID) {
                    ForEach(viewModel.users) { user in
                        Text(user.name).tag(user.id)
                    }
                }

                Picker("类型", selection: $viewModel.selectedCategory) {
                    ForEach(ContentCategory.allCases) { category in
                        Text(category.title).tag(category)
                    }
                }
                .pickerStyle(.segmented)

                Picker("排序", selection: $viewModel.selectedSort) {
                    ForEach(RankingSort.allCases) { sort in
                        Text(sort.title).tag(sort)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("筛选条件")
            }

            if viewModel.items.isEmpty, !viewModel.isLoading {
                Section {
                    EmptyStateView(
                        title: "暂无排行数据",
                        subtitle: "Playback Reporting 里还没有足够的播放样本。",
                        symbol: "list.number"
                    )
                }
            } else {
                Section("TOP 50") {
                    ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
                        HStack(alignment: .top, spacing: 12) {
                            rankBadge(index + 1)

                            cover(for: item)

                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.itemName)
                                    .font(.headline)

                                HStack(spacing: 10) {
                                    Label("\(item.playCount) 次", systemImage: "play.circle")
                                    Label(AppFormatting.durationText(seconds: item.totalTime), systemImage: "clock")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("内容排行")
        .overlay {
            if viewModel.isLoading && viewModel.items.isEmpty {
                ProgressView("正在载入排行...")
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
            Task { await viewModel.refresh() }
        }
        .onChange(of: viewModel.selectedCategory) { _ in
            Task { await viewModel.refresh() }
        }
        .onChange(of: viewModel.selectedSort) { _ in
            Task { await viewModel.refresh() }
        }
        .alert("加载失败", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { newValue in
                if !newValue { viewModel.errorMessage = nil }
            }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private func cover(for item: RankedItem) -> some View {
        if let itemID = item.itemID, let imageURL = sessionStore.assetURL(path: "/api/library/image/\(itemID)") {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    placeholderCover
                }
            }
            .frame(width: 52, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            placeholderCover
        }
    }

    private var placeholderCover: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.white.opacity(0.08))
            .frame(width: 52, height: 72)
            .overlay {
                Image(systemName: "film")
                    .foregroundStyle(.secondary)
            }
    }

    private func rankBadge(_ rank: Int) -> some View {
        Text("#\(rank)")
            .font(.caption.bold())
            .foregroundStyle(rank <= 3 ? .yellow : .secondary)
            .frame(width: 34, alignment: .leading)
    }
}
