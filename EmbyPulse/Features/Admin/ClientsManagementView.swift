import Charts
import SwiftUI

@MainActor
final class ClientsManagementViewModel: ObservableObject {
    @Published var devices: [ClientDevice] = []
    @Published var charts: ClientCharts?
    @Published var blacklist: [BlacklistedApp] = []
    @Published var newBlockedApp = ""
    @Published var isLoading = false
    @Published var message: String?
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
            async let clientData = api.fetchClientsData()
            async let blacklistData = api.fetchBlacklist()
            let result = try await clientData
            devices = result.devices
            charts = result.charts
            blacklist = try await blacklistData
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addBlacklist() async {
        guard !newBlockedApp.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        do {
            try await api.addBlacklist(appName: newBlockedApp)
            newBlockedApp = ""
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeBlacklist(_ item: BlacklistedApp) async {
        do {
            try await api.deleteBlacklist(appName: item.appName)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func executeBlock() async {
        do {
            message = try await api.executeClientBlock()
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ClientsManagementView: View {
    @StateObject private var viewModel = ClientsManagementViewModel()

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                summarySection
                chartsSection
                blacklistSection
                devicesSection
            }
            .padding()
        }
        .navigationTitle("客户端管理")
        .task {
            await viewModel.refresh()
        }
        .refreshable {
            await viewModel.refresh()
        }
        .alert(alertTitle, isPresented: alertBinding) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? viewModel.message ?? "")
        }
    }

    private var summarySection: some View {
        let online = viewModel.devices.filter { $0.isActive }.count
        let blocked = viewModel.devices.filter { $0.isBlocked }.count

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            MetricCard(title: "历史设备总数", value: "\(viewModel.devices.count)", symbol: "server.rack", accent: .blue)
            MetricCard(title: "当前在线设备", value: "\(online)", symbol: "dot.radiowaves.left.and.right", accent: .green)
            MetricCard(title: "已拦截设备", value: "\(blocked)", symbol: "hand.raised.slash", accent: .red)
            VStack(alignment: .leading, spacing: 12) {
                Text("一键阻断")
                    .font(.headline)
                Button("执行黑名单封禁") {
                    Task { await viewModel.executeBlock() }
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        }
    }

    private var chartsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(title: "客户端分布", subtitle: "按历史播放数据统计客户端与设备热度")
            if let charts = viewModel.charts {
                let barPoints = Array(zip(charts.bar.labels, charts.bar.data)).map {
                    TrendPoint(label: $0.0, value: Double($0.1))
                }
                let piePoints = Array(zip(charts.pie.labels, charts.pie.data)).map {
                    TrendPoint(label: $0.0, value: Double($0.1))
                }

                Chart(barPoints) { point in
                    BarMark(
                        x: .value("设备", point.label),
                        y: .value("次数", point.value)
                    )
                    .foregroundStyle(.orange.gradient)
                }
                .frame(height: 220)
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))

                ForEach(piePoints) { point in
                    HStack {
                        Text(point.label)
                            .font(.headline)
                        Spacer()
                        Text("\(Int(point.value))")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
            } else {
                EmptyStateView(title: "暂无统计图表", subtitle: "设备分布会在获取到 Emby 数据后显示。", symbol: "chart.pie")
            }
        }
    }

    private var blacklistSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(title: "黑名单", subtitle: "命中黑名单的 App 会被一键强制注销")

            HStack {
                TextField("例如 Infuse / VidHub", text: $viewModel.newBlockedApp)
                    .textFieldStyle(.roundedBorder)

                Button("添加") {
                    Task { await viewModel.addBlacklist() }
                }
                .buttonStyle(.borderedProminent)
            }

            if viewModel.blacklist.isEmpty {
                EmptyStateView(title: "暂无黑名单", subtitle: "你可以先添加需要限制的播放器 App 名称。", symbol: "shield")
            } else {
                ForEach(viewModel.blacklist) { item in
                    HStack {
                        Text(item.appName)
                            .font(.headline)
                        Spacer()
                        Button("移除") {
                            Task { await viewModel.removeBlacklist(item) }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    private var devicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(title: "设备列表", subtitle: "最近活跃用户、App 和授权状态")
            ForEach(viewModel.devices) { device in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(device.name)
                            .font(.headline)
                        Spacer()
                        StatusPill(text: device.isBlocked ? "已拦截" : (device.isActive ? "在线" : "正常"), tint: device.isBlocked ? .red : (device.isActive ? .green : .gray))
                    }
                    Text(device.lastUser)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        Text(device.appName)
                        Text(device.lastActive)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
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
