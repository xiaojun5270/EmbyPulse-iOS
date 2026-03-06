import Charts
import SwiftUI

@MainActor
final class ReportCenterViewModel: ObservableObject {
    @Published var users: [UserSelectionOption] = [.all]
    @Published var selectedUserID = UserSelectionOption.all.id
    @Published var selectedPeriod: ReportPeriod = .week
    @Published var selectedTheme = "black-gold"
    @Published var posterData: PosterData?
    @Published var topUsers: [TopUserEntry] = []
    @Published var monthlyTrend: [TrendPoint] = []
    @Published var isLoading = false
    @Published var message: String?
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
            async let poster = api.fetchPosterData(userID: selectedUserID, period: selectedPeriod)
            async let users = api.fetchTopUsers(period: selectedPeriod)
            async let monthly = api.fetchMonthlyStats(userID: selectedUserID)

            posterData = try await poster
            topUsers = try await users
            monthlyTrend = try await monthly
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func pushReport() async {
        do {
            try await api.pushReport(userID: selectedUserID, period: selectedPeriod, theme: selectedTheme)
            message = "报表已提交到 Bot 推送通道"
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ReportCenterView: View {
    @StateObject private var viewModel = ReportCenterViewModel()
    @EnvironmentObject private var sessionStore: SessionStore

    private let themes = ["black-gold", "cyber", "aurora", "sunset"]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                controlsSection

                if let previewURL = EmbyPulseAPI.shared.reportPreviewURL(userID: viewModel.selectedUserID, period: viewModel.selectedPeriod) {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeaderView(title: "报表预览", subtitle: "由服务端动态生成长图")
                        AsyncImage(url: previewURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                            case .failure:
                                EmptyStateView(title: "报表生成失败", subtitle: "请检查 Pillow、Bot 和统计数据是否完整。", symbol: "photo.badge.exclamationmark")
                            default:
                                ProgressView()
                                    .frame(maxWidth: .infinity, minHeight: 240)
                            }
                        }
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                    }
                }

                if let posterData = viewModel.posterData {
                    HStack(spacing: 14) {
                        MetricCard(title: "播放次数", value: "\(posterData.plays)", symbol: "play.rectangle", accent: .blue)
                        MetricCard(title: "观看小时", value: "\(posterData.hours)", symbol: "clock.arrow.2.circlepath", accent: .orange)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeaderView(title: "月度趋势", subtitle: "最近 12 个月播放时长")
                        if viewModel.monthlyTrend.isEmpty {
                            EmptyStateView(title: "暂无月度趋势", subtitle: "数据不足时这里会为空。", symbol: "chart.bar.xaxis")
                        } else {
                            Chart(viewModel.monthlyTrend) { point in
                                BarMark(
                                    x: .value("月份", point.label),
                                    y: .value("时长", point.value)
                                )
                                .foregroundStyle(.pink.gradient)
                            }
                            .frame(height: 220)
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeaderView(title: "海报墙 TOP", subtitle: "本周期内最常播放的内容")
                        ForEach(posterData.topList) { item in
                            HStack(spacing: 12) {
                                if let itemID = item.itemID, let imageURL = sessionStore.assetURL(path: "/api/library/image/\(itemID)") {
                                    AsyncImage(url: imageURL) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image.resizable().scaledToFill()
                                        default:
                                            RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.08))
                                        }
                                    }
                                    .frame(width: 50, height: 70)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(item.itemName)
                                        .font(.headline)
                                    Text("播放 \(item.count) 次 · \(AppFormatting.durationText(seconds: item.duration))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeaderView(title: "活跃用户排行", subtitle: "当前周期内的全站 TOP 用户")
                    if viewModel.topUsers.isEmpty {
                        EmptyStateView(title: "暂无排行", subtitle: "还没有足够的播放数据。", symbol: "person.2.slash")
                    } else {
                        ForEach(viewModel.topUsers) { user in
                            HStack {
                                Text(user.userName)
                                    .font(.headline)
                                Spacer()
                                Text("\(user.plays) 次")
                                    .font(.subheadline.monospacedDigit())
                                Text(AppFormatting.durationText(seconds: user.totalTime))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("映迹工坊")
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
        .onChange(of: viewModel.selectedPeriod) { _ in
            Task { await viewModel.refresh() }
        }
        .alert(alertTitle, isPresented: alertBinding) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? viewModel.message ?? "")
        }
    }

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(title: "报表参数", subtitle: "选择用户、周期和主题后可预览或推送")
            Picker("用户", selection: $viewModel.selectedUserID) {
                ForEach(viewModel.users) { user in
                    Text(user.name).tag(user.id)
                }
            }
            .pickerStyle(.menu)

            Picker("周期", selection: $viewModel.selectedPeriod) {
                ForEach(ReportPeriod.allCases) { period in
                    Text(period.title).tag(period)
                }
            }
            .pickerStyle(.segmented)

            Picker("主题", selection: $viewModel.selectedTheme) {
                ForEach(themes, id: \.self) { theme in
                    Text(theme).tag(theme)
                }
            }
            .pickerStyle(.menu)

            Button("推送到 Bot") {
                Task { await viewModel.pushReport() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
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
