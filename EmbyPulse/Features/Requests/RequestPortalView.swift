import SwiftUI

@MainActor
final class RequestPortalViewModel: ObservableObject {
    enum Tab: String, CaseIterable, Identifiable {
        case discover
        case queue
        case profile

        var id: String { rawValue }

        var title: String {
            switch self {
            case .discover: return "发现"
            case .queue: return "队列"
            case .profile: return "我的"
            }
        }
    }

    @Published var requestUser: RequestUser?
    @Published var username = ""
    @Published var password = ""
    @Published var searchQuery = ""
    @Published var selectedTab: Tab = .discover
    @Published var trending: RequestTrendingData?
    @Published var searchResults: [RequestMediaItem] = []
    @Published var myRequests: [UserRequestItem] = []
    @Published var myFeedback: [UserFeedbackItem] = []
    @Published var insight: UserInsight?
    @Published var badges: [UserBadge] = []
    @Published var isLoading = false
    @Published var isLoggingIn = false
    @Published var message: String?
    @Published var errorMessage: String?

    private let api: EmbyPulseAPI

    init(api: EmbyPulseAPI = .shared) {
        self.api = api
    }

    func bootstrap() async {
        do {
            requestUser = try await api.requestCheckAuth()
            if requestUser != nil {
                await loadCurrentTabData()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func login() async {
        guard !username.isEmpty, !password.isEmpty else { return }
        isLoggingIn = true
        errorMessage = nil
        defer { isLoggingIn = false }

        do {
            try await api.requestLogin(username: username, password: password)
            requestUser = try await api.requestCheckAuth()
            message = "登录成功"
            await loadCurrentTabData(force: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func logout() async {
        do {
            try await api.requestLogout()
            requestUser = nil
            trending = nil
            searchResults = []
            myRequests = []
            myFeedback = []
            insight = nil
            badges = []
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadCurrentTabData(force: Bool = false) async {
        guard requestUser != nil else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            switch selectedTab {
            case .discover:
                if trending == nil || force {
                    trending = try await api.fetchRequestTrending()
                }
            case .queue:
                async let reqs = api.fetchMyRequests()
                async let feedback = api.fetchMyFeedback()
                myRequests = try await reqs
                myFeedback = try await feedback
            case .profile:
                guard let user = requestUser else { return }
                async let insightData = api.fetchUserInsight(userID: user.id)
                async let badgeData = api.fetchUserBadges(userID: user.id)
                insight = try await insightData
                badges = try await badgeData
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func search() async {
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            searchResults = try await api.searchRequestMedia(query: searchQuery)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func submitRequest(item: RequestMediaItem, seasons: [Int]) async {
        do {
            message = try await api.submitRequest(item, seasons: seasons)
            await loadCurrentTabData(force: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func submitFeedback(itemName: String, issueType: String, description: String, posterPath: String) async {
        do {
            message = try await api.submitFeedback(
                itemName: itemName,
                issueType: issueType,
                description: description,
                posterPath: posterPath
            )
            await loadCurrentTabData(force: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct RequestPortalView: View {
    @StateObject private var viewModel = RequestPortalViewModel()
    @EnvironmentObject private var sessionStore: SessionStore
    let onExit: (() -> Void)?

    @State private var activeItem: RequestMediaItem?

    init(onExit: (() -> Void)? = nil) {
        self.onExit = onExit
    }

    var body: some View {
        Group {
            if viewModel.requestUser == nil {
                loginView
            } else {
                contentView
            }
        }
        .task {
            await viewModel.bootstrap()
        }
        .alert(alertTitle, isPresented: alertBinding) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? viewModel.message ?? "")
        }
        .sheet(item: $activeItem) { item in
            RequestSubmitSheet(item: item, viewModel: viewModel)
                .environmentObject(sessionStore)
        }
    }

    private var loginView: some View {
        NavigationStack {
            Form {
                Section("求片系统登录") {
                    TextField("Emby 用户名", text: $viewModel.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("密码", text: $viewModel.password)
                }

                Section {
                    Button {
                        Task { await viewModel.login() }
                    } label: {
                        if viewModel.isLoggingIn {
                            ProgressView()
                        } else {
                            Text("登录求片系统")
                        }
                    }
                    .disabled(viewModel.username.isEmpty || viewModel.password.isEmpty || viewModel.isLoggingIn)

                    if let onExit {
                        Button("返回后台登录") {
                            onExit()
                        }
                    }
                }

                Section("说明") {
                    Text("这里使用 Emby 普通用户或管理员账号登录，与后台管理登录独立。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("求片广场")
        }
    }

    private var contentView: some View {
        NavigationStack {
            List {
                Section {
                    Picker("标签页", selection: $viewModel.selectedTab) {
                        ForEach(RequestPortalViewModel.Tab.allCases) { tab in
                            Text(tab.title).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                switch viewModel.selectedTab {
                case .discover:
                    discoverSections
                case .queue:
                    queueSections
                case .profile:
                    profileSections
                }
            }
            .navigationTitle("求片广场")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if let onExit {
                        Button("关闭") { onExit() }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("刷新") {
                            Task { await viewModel.loadCurrentTabData(force: true) }
                        }
                        Button("退出求片登录", role: .destructive) {
                            Task { await viewModel.logout() }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .refreshable {
                await viewModel.loadCurrentTabData(force: true)
            }
            .onChange(of: viewModel.selectedTab) { _ in
                Task { await viewModel.loadCurrentTabData(force: false) }
            }
        }
    }

    private var discoverSections: some View {
        Group {
            Section("搜索") {
                TextField("搜索电影或剧集", text: $viewModel.searchQuery)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("搜索") {
                    Task { await viewModel.search() }
                }
            }

            if !viewModel.searchResults.isEmpty {
                Section("搜索结果") {
                    ForEach(viewModel.searchResults) { item in
                        requestMediaRow(item)
                    }
                }
            }

            if let trending = viewModel.trending {
                Section("本周热门电影") {
                    ForEach(trending.movies.prefix(8)) { item in
                        requestMediaRow(item)
                    }
                }
                Section("本周热门剧集") {
                    ForEach(trending.tv.prefix(8)) { item in
                        requestMediaRow(item)
                    }
                }
                Section("高分电影") {
                    ForEach(trending.topMovies.prefix(8)) { item in
                        requestMediaRow(item)
                    }
                }
                Section("高分剧集") {
                    ForEach(trending.topTV.prefix(8)) { item in
                        requestMediaRow(item)
                    }
                }
            } else if viewModel.isLoading {
                Section {
                    ProgressView("正在加载热门推荐...")
                }
            }
        }
    }

    private var queueSections: some View {
        Group {
            Section("我的求片") {
                if viewModel.myRequests.isEmpty {
                    Text("暂无求片记录")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.myRequests) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.title)
                                .font(.headline)
                            HStack(spacing: 10) {
                                Text(requestStatusTitle(item.status))
                                if let year = item.year { Text(year) }
                                Text(AppFormatting.shortDateTime(item.requestedAt))
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            if let reason = item.rejectReason, !reason.isEmpty {
                                Text("拒绝原因：\(reason)")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }
            }

            Section("我的反馈") {
                if viewModel.myFeedback.isEmpty {
                    Text("暂无报错记录")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.myFeedback) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.itemName)
                                .font(.headline)
                            Text(item.issueType)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let description = item.description, !description.isEmpty {
                                Text(description)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private var profileSections: some View {
        Group {
            if let user = viewModel.requestUser {
                Section("当前用户") {
                    LabeledContent("用户名", value: user.name)
                    LabeledContent("User ID", value: user.id)
                }
            }

            if let insight = viewModel.insight {
                Section("数据概览") {
                    LabeledContent("总播放", value: "\(insight.overview.totalPlays)")
                    LabeledContent("累计时长", value: AppFormatting.durationText(seconds: insight.overview.totalDuration))
                    LabeledContent("平均单次", value: AppFormatting.durationText(seconds: insight.overview.averageDuration))
                }

                Section("趣味勋章") {
                    if viewModel.badges.isEmpty {
                        Text("暂无勋章")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.badges) { badge in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(badge.name)
                                    .font(.headline)
                                Text(badge.description ?? "")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("观看偏好") {
                    LabeledContent("电影播放", value: "\(insight.preference.moviePlays)")
                    LabeledContent("剧集播放", value: "\(insight.preference.episodePlays)")
                }
            } else if viewModel.isLoading {
                Section {
                    ProgressView("正在加载个人画像...")
                }
            }
        }
    }

    @ViewBuilder
    private func requestMediaRow(_ item: RequestMediaItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            requestPoster(for: item)

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.headline)
                HStack(spacing: 10) {
                    Text(item.mediaType == "movie" ? "电影" : "剧集")
                    if let year = item.year { Text(year) }
                    if let vote = item.voteAverage { Text(String(format: "★ %.1f", vote)) }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Text(item.overview ?? "暂无简介")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Button("发起求片") {
                    activeItem = item
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func requestPoster(for item: RequestMediaItem) -> some View {
        if let url = imageURL(for: item.posterPath) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.08))
                        .overlay { Image(systemName: "film") }
                }
            }
            .frame(width: 56, height: 82)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func imageURL(for path: String?) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            return URL(string: path)
        }
        return sessionStore.assetURL(path: path)
    }

    private func requestStatusTitle(_ status: Int) -> String {
        switch status {
        case 0: return "待处理"
        case 1: return "已推送"
        case 2: return "已完成"
        case 3: return "已拒绝"
        case 4: return "手动处理"
        default: return "未知"
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

private struct RequestSubmitSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sessionStore: SessionStore
    let item: RequestMediaItem
    @ObservedObject var viewModel: RequestPortalViewModel

    @State private var seasons: [RequestSeason] = []
    @State private var selectedSeasons: Set<Int> = []
    @State private var isLoading = false
    @State private var issueType = "缺少字幕"
    @State private var issueDescription = ""

    private let issueTypes = ["缺少字幕", "资源失效", "音画不同步", "画质过低", "其他"]

    var body: some View {
        NavigationStack {
            List {
                Section("资源信息") {
                    Text(item.title)
                        .font(.headline)
                    Text(item.overview ?? "暂无简介")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if item.mediaType == "tv" {
                    Section("选择季度") {
                        if isLoading {
                            ProgressView("正在读取季信息...")
                        } else {
                            ForEach(seasons) { season in
                                MultipleSelectionRow(
                                    title: "\(season.name) · \(season.episodeCount) 集",
                                    subtitle: season.existsLocally ? "已在本地" : "可请求",
                                    isSelected: selectedSeasons.contains(season.seasonNumber),
                                    disabled: season.existsLocally
                                ) {
                                    if selectedSeasons.contains(season.seasonNumber) {
                                        selectedSeasons.remove(season.seasonNumber)
                                    } else {
                                        selectedSeasons.insert(season.seasonNumber)
                                    }
                                }
                            }
                        }
                    }
                }

                Section("操作") {
                    Button("提交求片") {
                        Task {
                            let seasonsToSubmit = item.mediaType == "tv" ? Array(selectedSeasons).sorted() : [0]
                            await viewModel.submitRequest(item: item, seasons: seasonsToSubmit)
                            dismiss()
                        }
                    }
                    .disabled(item.mediaType == "tv" && selectedSeasons.isEmpty)
                }

                Section("资源报错") {
                    Picker("问题类型", selection: $issueType) {
                        ForEach(issueTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }

                    TextField("补充说明", text: $issueDescription, axis: .vertical)
                        .lineLimit(2 ... 4)

                    Button("提交报错") {
                        Task {
                            await viewModel.submitFeedback(
                                itemName: item.title,
                                issueType: issueType,
                                description: issueDescription,
                                posterPath: item.posterPath ?? ""
                            )
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("提交请求")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task {
                guard item.mediaType == "tv" else { return }
                isLoading = true
                defer { isLoading = false }
                do {
                    let loaded = try await EmbyPulseAPI.shared.fetchRequestTVDetails(tmdbID: item.tmdbID)
                    seasons = loaded
                    selectedSeasons = Set(loaded.filter { !$0.existsLocally }.map(\.seasonNumber))
                } catch {
                    // rely on parent alert path after action attempts
                }
            }
        }
    }
}

private struct MultipleSelectionRow: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .foregroundStyle(disabled ? .secondary : .primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(disabled ? .gray : .blue)
            }
        }
        .disabled(disabled)
    }
}
