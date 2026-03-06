import SwiftUI

struct AdminHubView: View {
    var body: some View {
        List {
            Section("运营与审批") {
                NavigationLink {
                    RequestPortalView()
                } label: {
                    AdminHubRow(
                        title: "求片前台",
                        subtitle: "以普通 Emby 用户视角体验求片、反馈与个人画像",
                        symbol: "sparkles.rectangle.stack",
                        tint: .pink
                    )
                }

                NavigationLink {
                    RequestsAdminView()
                } label: {
                    AdminHubRow(
                        title: "求片中心",
                        subtitle: "处理媒体请求与资源报错工单",
                        symbol: "tray.full",
                        tint: .orange
                    )
                }

                NavigationLink {
                    TasksCenterView()
                } label: {
                    AdminHubRow(
                        title: "任务中心",
                        subtitle: "管理 Emby 计划任务和插件作业",
                        symbol: "bolt.horizontal.circle",
                        tint: .blue
                    )
                }

                NavigationLink {
                    ClientsManagementView()
                } label: {
                    AdminHubRow(
                        title: "客户端管理",
                        subtitle: "查看设备分布、黑名单并强制阻断违规客户端",
                        symbol: "desktopcomputer.and.iphone",
                        tint: .green
                    )
                }
            }

            Section("通知与配置") {
                NavigationLink {
                    BotManagementView()
                } label: {
                    AdminHubRow(
                        title: "机器人助手",
                        subtitle: "配置 Telegram / 企业微信推送和交互",
                        symbol: "paperplane.circle",
                        tint: .purple
                    )
                }

                NavigationLink {
                    SettingsView()
                } label: {
                    AdminHubRow(
                        title: "系统设置",
                        subtitle: "管理 Emby、TMDB、Webhook、MoviePilot 等配置",
                        symbol: "gearshape",
                        tint: .gray
                    )
                }
            }
        }
        .navigationTitle("管理中心")
    }
}

private struct AdminHubRow: View {
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
