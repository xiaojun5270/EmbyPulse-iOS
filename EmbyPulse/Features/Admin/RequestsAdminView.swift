import SwiftUI

@MainActor
final class RequestsAdminViewModel: ObservableObject {
    enum Mode: String, CaseIterable, Identifiable {
        case requests
        case feedback

        var id: String { rawValue }

        var title: String {
            switch self {
            case .requests: return "求片"
            case .feedback: return "报错"
            }
        }
    }

    @Published var mode: Mode = .requests
    @Published var requestFilter: RequestStatusFilter = .all
    @Published var feedbackFilter: FeedbackStatusFilter = .all
    @Published var requests: [AdminRequestItem] = []
    @Published var feedbacks: [AdminFeedbackItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var message: String?

    private let api: EmbyPulseAPI

    init(api: EmbyPulseAPI = .shared) {
        self.api = api
    }

    var filteredRequests: [AdminRequestItem] {
        guard requestFilter != .all else { return requests }
        return requests.filter { $0.status == requestFilter.rawValue }
    }

    var filteredFeedbacks: [AdminFeedbackItem] {
        guard feedbackFilter != .all else { return feedbacks }
        return feedbacks.filter { $0.status == feedbackFilter.rawValue }
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let requestData = api.fetchAdminRequests()
            async let feedbackData = api.fetchAdminFeedback()
            requests = try await requestData
            feedbacks = try await feedbackData
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func actOnRequest(_ item: AdminRequestItem, action: String, rejectReason: String? = nil) async {
        do {
            try await api.updateRequests(
                items: [RequestActionItem(tmdbID: item.tmdbID, season: item.season)],
                action: action,
                rejectReason: rejectReason
            )
            message = "操作成功"
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func actOnFeedback(_ item: AdminFeedbackItem, action: String) async {
        do {
            try await api.updateFeedback(id: item.id, action: action)
            message = "操作成功"
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct RequestsAdminView: View {
    @StateObject private var viewModel = RequestsAdminViewModel()

    var body: some View {
        List {
            Section {
                Picker("模式", selection: $viewModel.mode) {
                    ForEach(RequestsAdminViewModel.Mode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            if viewModel.mode == .requests {
                requestsSection
            } else {
                feedbackSection
            }
        }
        .navigationTitle("求片中心")
        .overlay {
            if viewModel.isLoading && viewModel.requests.isEmpty && viewModel.feedbacks.isEmpty {
                ProgressView("正在加载工单...")
            }
        }
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

    private var requestsSection: some View {
        Section {
            Picker("状态", selection: $viewModel.requestFilter) {
                ForEach(RequestStatusFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.menu)

            if viewModel.filteredRequests.isEmpty {
                EmptyStateView(title: "暂无求片工单", subtitle: "当前筛选条件下没有数据。", symbol: "tray")
            } else {
                ForEach(viewModel.filteredRequests) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.title)
                            .font(.headline)

                        Text(item.requestedBy ?? "未知用户")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 10) {
                            Text(statusTitle(for: item.status))
                            if let year = item.year { Text(year) }
                            Text(item.mediaType == "tv" ? "剧集" : "电影")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        if let rejectReason = item.rejectReason, !rejectReason.isEmpty {
                            Text("拒绝原因：\(rejectReason)")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.vertical, 4)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("通过") {
                            Task { await viewModel.actOnRequest(item, action: "approve") }
                        }
                        .tint(.green)

                        Button("完成") {
                            Task { await viewModel.actOnRequest(item, action: "finish") }
                        }
                        .tint(.blue)

                        Button("拒绝") {
                            Task { await viewModel.actOnRequest(item, action: "reject", rejectReason: "未找到可用资源") }
                        }
                        .tint(.red)
                    }
                    .contextMenu {
                        Button("手动接单") {
                            Task { await viewModel.actOnRequest(item, action: "manual") }
                        }
                        Button("删除") {
                            Task { await viewModel.actOnRequest(item, action: "delete") }
                        }
                    }
                }
            }
        } header: {
            Text("求片审批")
        }
    }

    private var feedbackSection: some View {
        Section {
            Picker("状态", selection: $viewModel.feedbackFilter) {
                ForEach(FeedbackStatusFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.menu)

            if viewModel.filteredFeedbacks.isEmpty {
                EmptyStateView(title: "暂无反馈工单", subtitle: "当前筛选条件下没有数据。", symbol: "exclamationmark.bubble")
            } else {
                ForEach(viewModel.filteredFeedbacks) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.itemName)
                            .font(.headline)
                        Text(item.username)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(item.issueType)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let description = item.description, !description.isEmpty {
                            Text(description)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("修复中") {
                            Task { await viewModel.actOnFeedback(item, action: "fix") }
                        }
                        .tint(.orange)

                        Button("完成") {
                            Task { await viewModel.actOnFeedback(item, action: "done") }
                        }
                        .tint(.green)

                        Button("忽略") {
                            Task { await viewModel.actOnFeedback(item, action: "reject") }
                        }
                        .tint(.red)
                    }
                    .contextMenu {
                        Button("删除") {
                            Task { await viewModel.actOnFeedback(item, action: "delete") }
                        }
                    }
                }
            }
        } header: {
            Text("资源报错")
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

    private func statusTitle(for status: Int) -> String {
        switch status {
        case 0: return "待处理"
        case 1: return "已推送"
        case 2: return "已完成"
        case 3: return "已拒绝"
        case 4: return "手动处理"
        default: return "未知"
        }
    }
}
