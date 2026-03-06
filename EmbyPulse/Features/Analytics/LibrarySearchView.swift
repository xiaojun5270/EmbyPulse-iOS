import SwiftUI

@MainActor
final class LibrarySearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var results: [LibrarySearchResult] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api: EmbyPulseAPI

    init(api: EmbyPulseAPI = .shared) {
        self.api = api
    }

    func search() async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            results = []
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            results = try await api.searchLibrary(query: query)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct LibrarySearchView: View {
    @StateObject private var viewModel = LibrarySearchViewModel()
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            Section("搜索") {
                TextField("搜索电影或剧集", text: $viewModel.query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button("开始搜索") {
                    Task { await viewModel.search() }
                }
            }

            Section("结果") {
                if viewModel.results.isEmpty, !viewModel.isLoading {
                    EmptyStateView(
                        title: "暂无搜索结果",
                        subtitle: "输入关键词后可搜索整个 Emby 媒体库。",
                        symbol: "magnifyingglass"
                    )
                } else {
                    ForEach(viewModel.results) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.name)
                                .font(.headline)

                            HStack(spacing: 10) {
                                Text(item.type == "movie" ? "电影" : "剧集")
                                Text(item.yearText)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)

                            if !item.badges.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack {
                                        ForEach(item.badges) { badge in
                                            StatusPill(text: badge.text, tint: .blue)
                                        }
                                    }
                                }
                            }

                            Text(item.overview)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)

                            if let url = URL(string: item.embyURL), !item.embyURL.isEmpty {
                                Button("在 Emby 中打开") {
                                    openURL(url)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("全局搜索")
        .overlay {
            if viewModel.isLoading {
                ProgressView("正在搜索资源...")
            }
        }
        .alert("搜索失败", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { newValue in if !newValue { viewModel.errorMessage = nil } }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}
