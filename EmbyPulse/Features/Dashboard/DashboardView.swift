import Charts
import SwiftUI

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var snapshot: DashboardSnapshot?
    @Published var trend: [TrendPoint] = []
    @Published var liveSessions: [LiveSession] = []
    @Published var recentActivity: [RecentActivity] = []
    @Published var latestMedia: [LatestMedia] = []
    @Published var selectedDimension: TrendDimension = .day
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api: EmbyPulseAPI

    init(api: EmbyPulseAPI = .shared) {
        self.api = api
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            async let dashboard = api.fetchDashboard()
            async let trendData = api.fetchTrend(dimension: selectedDimension)
            async let live = api.fetchLiveSessions()
            async let recent = api.fetchRecentActivity()
            async let latest = api.fetchLatestMedia(limit: 8)

            snapshot = try await dashboard
            trend = try await trendData
            liveSessions = try await live
            recentActivity = try await recent
            latestMedia = try await latest
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()

    private let metrics = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                if let snapshot = viewModel.snapshot {
                    LazyVGrid(columns: metrics, spacing: 14) {
                        MetricCard(
                            title: "总播放次数",
                            value: "\(snapshot.totalPlays)",
                            symbol: "play.circle.fill",
                            accent: .blue
                        )
                        MetricCard(
                            title: "活跃用户",
                            value: "\(snapshot.activeUsers)",
                            symbol: "person.2.fill",
                            accent: .green
                        )
                        MetricCard(
                            title: "累计时长",
                            value: AppFormatting.durationText(seconds: snapshot.totalDuration),
                            symbol: "clock.fill",
                            accent: .orange
                        )
                        MetricCard(
                            title: "媒体总量",
                            value: "\(snapshot.library.movie + snapshot.library.series + snapshot.library.episode)",
                            symbol: "film.stack.fill",
                            accent: .purple
                        )
                    }

                    trendSection
                    liveSection
                    latestMediaSection
                    recentActivitySection
                } else if viewModel.isLoading {
                    ProgressView("正在加载仪表盘...")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 80)
                } else {
                    EmptyStateView(
                        title: "暂无数据",
                        subtitle: "请确认面板地址、登录状态以及 EmbyPulse 服务是否正常运行。",
                        symbol: "chart.bar.xaxis"
                    )
                }
            }
            .padding()
        }
        .navigationTitle("仪表盘")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .task {
            if viewModel.snapshot == nil {
                await viewModel.refresh()
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
        .alert("加载失败", isPresented: Binding(
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

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeaderView(title: "播放趋势", subtitle: "按日 / 周 / 月查看总播放时长")

            Picker("趋势维度", selection: $viewModel.selectedDimension) {
                ForEach(TrendDimension.allCases) { dimension in
                    Text(dimension.title).tag(dimension)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.selectedDimension) { _ in
                Task { await viewModel.refresh() }
            }

            if viewModel.trend.isEmpty {
                EmptyStateView(
                    title: "暂无趋势数据",
                    subtitle: "Playback Reporting 数据库可能还没有足够样本。",
                    symbol: "waveform.path.ecg"
                )
            } else {
                Chart(viewModel.trend) { point in
                    LineMark(
                        x: .value("时间", point.label),
                        y: .value("时长", point.value)
                    )
                    .foregroundStyle(.blue)

                    AreaMark(
                        x: .value("时间", point.label),
                        y: .value("时长", point.value)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            colors: [.blue.opacity(0.35), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .frame(height: 220)
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
            }
        }
    }

    private var liveSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeaderView(title: "实时播放", subtitle: "当前活跃中的播放会话")

            if viewModel.liveSessions.isEmpty {
                EmptyStateView(
                    title: "现在没人看片",
                    subtitle: "当有会话开始播放时，这里会展示当前媒体、客户端和转码状态。",
                    symbol: "tv"
                )
            } else {
                ForEach(viewModel.liveSessions) { session in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(session.title)
                                    .font(.headline)

                                Text(session.userName)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                if !session.subtitle.isEmpty {
                                    Text(session.subtitle)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            if session.isTranscoding {
                                StatusPill(text: "转码中", tint: .orange)
                            } else {
                                StatusPill(text: "直连", tint: .green)
                            }
                        }

                        ProgressView(value: session.progress)
                            .tint(session.isTranscoding ? .orange : .green)

                        if let address = session.remoteEndPoint, !address.isEmpty {
                            Text(address)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                }
            }
        }
    }

    private var latestMediaSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeaderView(title: "最近入库", subtitle: "来自 /api/stats/latest")

            if viewModel.latestMedia.isEmpty {
                EmptyStateView(
                    title: "暂无最近入库内容",
                    subtitle: "面板还没有拉取到最新媒体信息。",
                    symbol: "shippingbox"
                )
            } else {
                ForEach(viewModel.latestMedia) { item in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.name)
                                .font(.headline)

                            if let seriesName = item.seriesName, !seriesName.isEmpty {
                                Text(seriesName)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 10) {
                                if let type = item.type {
                                    Text(type)
                                }
                                if let year = item.year {
                                    Text(String(year))
                                }
                                if let rating = item.rating {
                                    Text(String(format: "★ %.1f", rating))
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(AppFormatting.shortDate(item.dateCreated))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                }
            }
        }
    }

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeaderView(title: "最近活动", subtitle: "最近 50 条播放记录中的最新条目")

            if viewModel.recentActivity.isEmpty {
                EmptyStateView(
                    title: "暂无最近活动",
                    subtitle: "Playback Reporting 还没有同步到最近播放记录。",
                    symbol: "clock.arrow.circlepath"
                )
            } else {
                ForEach(viewModel.recentActivity.prefix(10)) { item in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.displayName)
                                .font(.headline)

                            Text(item.userName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            if let type = item.itemType, !type.isEmpty {
                                Text(type)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Text(AppFormatting.shortDateTime(item.dateCreated))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                }
            }
        }
        .padding(.bottom, 20)
    }
}
