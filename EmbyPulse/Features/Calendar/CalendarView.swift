import SwiftUI
import UIKit

@MainActor
final class CalendarViewModel: ObservableObject {
    @Published var week: CalendarWeekResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var weekOffset = 0
    @Published var selectedTTL: CalendarTTL = .oneDay

    private let api: EmbyPulseAPI

    init(api: EmbyPulseAPI = .shared) {
        self.api = api
    }

    func refresh(forceRefresh: Bool = false) async {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let response = try await api.fetchCalendarWeek(offset: weekOffset, refresh: forceRefresh)
            week = response
            selectedTTL = CalendarTTL(rawValue: response.currentTTL) ?? .oneDay
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func move(offset: Int) async {
        weekOffset += offset
        await refresh()
    }

    func saveTTL() async {
        do {
            try await api.updateCalendarTTL(selectedTTL)
            await refresh(forceRefresh: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct CalendarView: View {
    @StateObject private var viewModel = CalendarViewModel()
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                controlsSection

                if let week = viewModel.week {
                    ForEach(week.days) { day in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(day.isToday && viewModel.weekOffset == 0 ? "今天" : day.weekdayCN)
                                        .font(.headline)
                                    Text(day.date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if day.isToday && viewModel.weekOffset == 0 {
                                    StatusPill(text: "今日更新", tint: .blue)
                                }
                            }

                            if day.items.isEmpty {
                                EmptyStateView(
                                    title: "今日无排期",
                                    subtitle: "该日期没有抓取到待播或已播剧集。",
                                    symbol: "moon.zzz"
                                )
                            } else {
                                ForEach(day.items) { item in
                                    calendarCard(item: item, week: week)
                                }
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                    }
                } else if viewModel.isLoading {
                    ProgressView("正在同步本周追剧日历...")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 80)
                } else {
                    EmptyStateView(
                        title: "未获取到日历数据",
                        subtitle: "请确认 TMDB Key 已在 EmbyPulse 中配置完成，并且媒体库中存在连载剧集。",
                        symbol: "calendar.badge.exclamationmark"
                    )
                }
            }
            .padding()
        }
        .navigationTitle("追剧日历")
        .task {
            if viewModel.week == nil {
                await viewModel.refresh()
            }
        }
        .refreshable {
            await viewModel.refresh(forceRefresh: true)
        }
        .alert("日历加载失败", isPresented: Binding(
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

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeaderView(
                title: "本周热播",
                subtitle: viewModel.week.map { "时间范围：\($0.dateRange)" } ?? "支持查看上周 / 本周 / 下周排期"
            )

            HStack {
                Button {
                    Task { await viewModel.move(offset: -1) }
                } label: {
                    Label("上周", systemImage: "chevron.left")
                }
                .buttonStyle(.bordered)

                Button {
                    Task { await viewModel.move(offset: 1) }
                } label: {
                    Label("下周", systemImage: "chevron.right")
                }
                .buttonStyle(.bordered)

                Spacer()

                Button {
                    viewModel.weekOffset = 0
                    Task { await viewModel.refresh(forceRefresh: true) }
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
            }

            HStack {
                Picker("缓存时间", selection: $viewModel.selectedTTL) {
                    ForEach(CalendarTTL.allCases) { ttl in
                        Text(ttl.title).tag(ttl)
                    }
                }
                .pickerStyle(.menu)

                Spacer()

                Button("保存缓存") {
                    Task { await viewModel.saveTTL() }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder
    private func calendarCard(item: CalendarEntry, week: CalendarWeekResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.seriesName)
                        .font(.headline)

                    Text(item.episodeDisplay)
                        .font(.subheadline.monospaced())
                        .foregroundStyle(.secondary)

                    if let episodeName = item.episodeName, !episodeName.isEmpty {
                        Text(episodeName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                StatusPill(text: statusTitle(for: item.status), tint: statusColor(for: item.status))
            }

            Text(item.summaryText)
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack {
                Label(AppFormatting.shortDate(item.airDate), systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if let url = embyURL(for: item, week: week), item.status == "ready" {
                    Button("打开 Emby") {
                        openURL(url)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                } else {
                    Button("复制剧集信息") {
                        UIPasteboard.general.string = "\(item.seriesName) \(item.episodeDisplay)"
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
    }

    private func statusTitle(for status: String) -> String {
        switch status {
        case "ready":
            return "已入库"
        case "missing":
            return "待补货"
        case "today":
            return "今日更新"
        case "upcoming":
            return "待播出"
        default:
            return "未知"
        }
    }

    private func statusColor(for status: String) -> Color {
        switch status {
        case "ready":
            return .green
        case "missing":
            return .red
        case "today":
            return .orange
        case "upcoming":
            return .blue
        default:
            return .gray
        }
    }

    private func embyURL(for item: CalendarEntry, week: CalendarWeekResponse) -> URL? {
        guard
            !week.embyURL.isEmpty,
            !week.serverID.isEmpty,
            let seriesID = item.seriesID
        else {
            return nil
        }

        let rawURL = "\(week.embyURL)/web/index.html#!/details?id=\(seriesID)&serverId=\(week.serverID)"
        return URL(string: rawURL)
    }
}
