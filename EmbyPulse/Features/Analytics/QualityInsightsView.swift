import SwiftUI

@MainActor
final class QualityInsightsViewModel: ObservableObject {
    @Published var quality: QualityScanData?
    @Published var ignoredItems: [IgnoredItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api: EmbyPulseAPI

    init(api: EmbyPulseAPI = .shared) {
        self.api = api
    }

    func refresh(forceRefresh: Bool = false) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let qualityData = api.fetchQuality(forceRefresh: forceRefresh)
            async let ignored = api.fetchIgnoredItems()
            quality = try await qualityData
            ignoredItems = try await ignored
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func ignore(_ movie: QualityMovie) async {
        do {
            try await api.ignoreItem(itemID: movie.id, itemName: movie.name)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func unignore(_ item: IgnoredItem) async {
        do {
            try await api.unignoreItems([item.itemID])
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct QualityInsightsView: View {
    @StateObject private var viewModel = QualityInsightsViewModel()

    private let categoryTitles: [QualityCategory] = [
        .init(key: "4k", title: "4K"),
        .init(key: "1080p", title: "1080P"),
        .init(key: "720p", title: "720P"),
        .init(key: "sd", title: "低画质"),
        .init(key: "hevc", title: "HEVC"),
        .init(key: "h264", title: "H.264"),
        .init(key: "av1", title: "AV1"),
        .init(key: "dolby_vision", title: "杜比视界"),
        .init(key: "hdr10", title: "HDR"),
        .init(key: "sdr", title: "SDR")
    ]

    var body: some View {
        List {
            if let quality = viewModel.quality {
                Section("扫描概览") {
                    LabeledContent("总电影数", value: "\(quality.totalCount)")
                    LabeledContent("最近扫描", value: quality.scanTime)
                    Button("强制重新扫描") {
                        Task { await viewModel.refresh(forceRefresh: true) }
                    }
                }

                ForEach(categoryTitles) { category in
                    if let movies = quality.movies[category.key], !movies.isEmpty {
                        Section("\(category.title) · \(movies.count)") {
                            ForEach(movies.prefix(8)) { movie in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(movie.name)
                                        .font(.headline)
                                    HStack(spacing: 10) {
                                        if let year = movie.year {
                                            Text(String(year))
                                        }
                                        if let resolution = movie.resolution {
                                            Text(resolution)
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                                .swipeActions {
                                    Button("忽略") {
                                        Task { await viewModel.ignore(movie) }
                                    }
                                    .tint(.orange)
                                }
                            }
                        }
                    }
                }

                Section("已忽略") {
                    if viewModel.ignoredItems.isEmpty {
                        Text("当前没有忽略项")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.ignoredItems) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.itemName ?? item.itemID)
                                    .font(.headline)
                                if let ignoredAt = item.ignoredAt {
                                    Text(ignoredAt)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .swipeActions {
                                Button("恢复") {
                                    Task { await viewModel.unignore(item) }
                                }
                                .tint(.green)
                            }
                        }
                    }
                }
            } else if viewModel.isLoading {
                ProgressView("正在扫描媒体库质量...")
                    .frame(maxWidth: .infinity)
            } else {
                Section {
                    EmptyStateView(
                        title: "暂无质量盘点数据",
                        subtitle: "请确认 Emby 已配置并且服务端可以访问媒体流信息。",
                        symbol: "sparkles.tv"
                    )
                }
            }
        }
        .navigationTitle("质量盘点")
        .task {
            if viewModel.quality == nil {
                await viewModel.refresh()
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
        .alert("操作失败", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { newValue in if !newValue { viewModel.errorMessage = nil } }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

private struct QualityCategory: Identifiable {
    let key: String
    let title: String

    var id: String { key }
}
