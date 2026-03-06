import Charts
import SwiftUI

@MainActor
final class UserInsightViewModel: ObservableObject {
    @Published var users: [UserSelectionOption] = [.all]
    @Published var selectedUserID = UserSelectionOption.all.id
    @Published var insight: UserInsight?
    @Published var badges: [UserBadge] = []
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
            async let insightData = api.fetchUserInsight(userID: selectedUserID)
            async let badgeData = api.fetchUserBadges(userID: selectedUserID)
            insight = try await insightData
            badges = try await badgeData
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct UserInsightView: View {
    @StateObject private var viewModel = UserInsightViewModel()
    @EnvironmentObject private var sessionStore: SessionStore

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                Picker("用户", selection: $viewModel.selectedUserID) {
                    ForEach(viewModel.users) { user in
                        Text(user.name).tag(user.id)
                    }
                }
                .pickerStyle(.menu)

                if let insight = viewModel.insight {
                    overviewSection(insight)
                    badgesSection
                    hourlySection(insight)
                    preferenceSection(insight)
                    devicesSection(title: "常用设备", data: insight.devices)
                    devicesSection(title: "播放器分布", data: insight.clients)
                    topFavoriteSection(insight)
                    recentLogsSection(insight)
                } else if viewModel.isLoading {
                    ProgressView("正在生成用户画像...")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 60)
                } else {
                    EmptyStateView(
                        title: "暂无画像数据",
                        subtitle: "请选择用户并确保 Playback Reporting 已积累足够数据。",
                        symbol: "person.crop.circle.badge.questionmark"
                    )
                }
            }
            .padding()
        }
        .navigationTitle("用户画像")
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
        .alert("加载失败", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { newValue in if !newValue { viewModel.errorMessage = nil } }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private func overviewSection(_ insight: UserInsight) -> some View {
        let overview = insight.overview
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            MetricCard(title: "总播放", value: "\(overview.totalPlays)", symbol: "play.square", accent: .blue)
            MetricCard(title: "累计时长", value: AppFormatting.durationText(seconds: overview.totalDuration), symbol: "clock", accent: .orange)
            MetricCard(title: "平均单次", value: AppFormatting.durationText(seconds: overview.averageDuration), symbol: "timer", accent: .green)
            MetricCard(title: "账号天数", value: "\(overview.accountAgeDays)", symbol: "calendar", accent: .purple)
        }
    }

    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(title: "趣味勋章", subtitle: "根据观看习惯生成的标签")
            if viewModel.badges.isEmpty {
                EmptyStateView(title: "暂无勋章", subtitle: "再多看片一阵子就会触发更丰富的成就。", symbol: "medal")
            } else {
                ForEach(viewModel.badges) { badge in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(badge.name)
                            .font(.headline)
                        Text(badge.description ?? "")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    private func hourlySection(_ insight: UserInsight) -> some View {
        let points = insight.hourly.keys.sorted().map {
            TrendPoint(label: $0, value: Double(insight.hourly[$0] ?? 0))
        }

        return VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(title: "24 小时热力", subtitle: "不同时间段的看片频率")
            Chart(points) { point in
                BarMark(
                    x: .value("小时", point.label),
                    y: .value("次数", point.value)
                )
                .foregroundStyle(.blue.gradient)
            }
            .frame(height: 220)
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func preferenceSection(_ insight: UserInsight) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(title: "内容偏好", subtitle: "电影与剧集偏好比例")
            HStack(spacing: 14) {
                MetricCard(title: "电影播放", value: "\(insight.preference.moviePlays)", symbol: "film", accent: .cyan)
                MetricCard(title: "剧集播放", value: "\(insight.preference.episodePlays)", symbol: "tv", accent: .pink)
            }
        }
    }

    private func devicesSection(title: String, data: [LabelCount]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(title: title, subtitle: nil)
            if data.isEmpty {
                EmptyStateView(title: "暂无数据", subtitle: "这里会显示播放设备与客户端排行。", symbol: "switch.2")
            } else {
                ForEach(data) { entry in
                    HStack {
                        Text(entry.label)
                            .font(.headline)
                        Spacer()
                        Text("\(entry.plays)")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    private func topFavoriteSection(_ insight: UserInsight) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(title: "最爱内容", subtitle: "按总观看时长计算")

            if let favorite = insight.topFavorite {
                HStack(spacing: 12) {
                    if let itemID = favorite.itemID, let imageURL = sessionStore.assetURL(path: "/api/library/image/\(itemID)") {
                        AsyncImage(url: imageURL) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            default:
                                RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08))
                            }
                        }
                        .frame(width: 72, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(favorite.itemName)
                            .font(.headline)
                        Text("观看次数：\(favorite.count)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("累计时长：\(AppFormatting.durationText(seconds: favorite.duration))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            } else {
                EmptyStateView(title: "暂无最爱内容", subtitle: "随着播放数据累积，这里会自动生成。", symbol: "heart.text.square")
            }
        }
    }

    private func recentLogsSection(_ insight: UserInsight) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(title: "最近行为", subtitle: "最近 100 条用户记录中的最新条目")
            ForEach(insight.logs.prefix(15)) { log in
                VStack(alignment: .leading, spacing: 6) {
                    Text(log.itemName)
                        .font(.headline)
                    HStack(spacing: 10) {
                        if let device = log.device {
                            Text(device)
                        }
                        Text(AppFormatting.durationText(seconds: log.playDuration ?? 0))
                        Text(AppFormatting.shortDateTime(log.dateCreated))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }
}
