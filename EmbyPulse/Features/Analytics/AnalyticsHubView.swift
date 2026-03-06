import SwiftUI

struct AnalyticsHubView: View {
    var body: some View {
        List {
            Section("核心分析") {
                NavigationLink {
                    ContentRankingsView()
                } label: {
                    HubRow(
                        title: "内容排行",
                        subtitle: "按播放次数或总时长查看热门电影 / 剧集",
                        symbol: "list.number",
                        tint: .orange
                    )
                }

                NavigationLink {
                    HistoryBrowserView()
                } label: {
                    HubRow(
                        title: "历史记录",
                        subtitle: "浏览播放历史，支持按用户和关键词检索",
                        symbol: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                        tint: .blue
                    )
                }

                NavigationLink {
                    UserInsightView()
                } label: {
                    HubRow(
                        title: "用户画像",
                        subtitle: "查看用户偏好、勋章、设备分布和最近行为",
                        symbol: "person.text.rectangle",
                        tint: .purple
                    )
                }

                NavigationLink {
                    QualityInsightsView()
                } label: {
                    HubRow(
                        title: "质量盘点",
                        subtitle: "扫描 4K / HDR / 编码分布并管理忽略列表",
                        symbol: "sparkles.tv",
                        tint: .green
                    )
                }

                NavigationLink {
                    ReportCenterView()
                } label: {
                    HubRow(
                        title: "映迹工坊",
                        subtitle: "生成观影报表预览并一键推送到 Bot",
                        symbol: "photo.on.rectangle.angled",
                        tint: .pink
                    )
                }
            }

            Section("搜索") {
                NavigationLink {
                    LibrarySearchView()
                } label: {
                    HubRow(
                        title: "全局资源搜索",
                        subtitle: "搜索 Emby 媒体库并直接打开 Emby 页面",
                        symbol: "magnifyingglass",
                        tint: .teal
                    )
                }
            }
        }
        .navigationTitle("数据分析")
    }
}

private struct HubRow: View {
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 34)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}
