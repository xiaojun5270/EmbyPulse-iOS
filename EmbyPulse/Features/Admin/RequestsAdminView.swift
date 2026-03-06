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

    func actOnRequest(_ items: [AdminRequestItem], action: String, rejectReason: String? = nil) async {
        do {
            let payload = items.map { RequestActionItem(tmdbID: $0.tmdbID, season: $0.season) }
            try await api.updateRequests(items: payload, action: action, rejectReason: rejectReason)
            message = "操作成功"
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func actOnFeedback(_ items: [AdminFeedbackItem], action: String) async {
        do {
            if items.count == 1, let item = items.first {
                try await api.updateFeedback(id: item.id, action: action)
            } else {
                try await api.batchFeedback(ids: items.map(\.id), action: action)
            }
            message = "操作成功"
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct RequestsAdminView: View {
    @StateObject private var viewModel = RequestsAdminViewModel()
    @State private var selectionMode = false
    @State private var selectedRequestIDs: Set<String> = []
    @State private var selectedFeedbackIDs: Set<Int> = []

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

            if selectionMode {
                batchActionSection
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(selectionMode ? "完成" : "批量") {
                    selectionMode.toggle()
                    if !selectionMode {
                        selectedRequestIDs.removeAll()
                        selectedFeedbackIDs.removeAll()
                    }
                }
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

    private var batchActionSection: some View {
        Section("批量操作") {
            if viewModel.mode == .requests {
                Text("已选择 \(selectedRequestIDs.count) 个求片工单")
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        Button("批量通过") {
                            Task { await batchRequestAction("approve") }
                        }
                        .buttonStyle(.bordered)
                        .disabled(selectedRequestIDs.isEmpty)

                        Button("批量完成") {
                            Task { await batchRequestAction("finish") }
                        }
                        .buttonStyle(.bordered)
                        .disabled(selectedRequestIDs.isEmpty)

                        Button("批量手动") {
                            Task { await batchRequestAction("manual") }
                        }
                        .buttonStyle(.bordered)
                        .disabled(selectedRequestIDs.isEmpty)

                        Button("批量拒绝") {
                            Task { await batchRequestAction("reject", reason: "未找到可用资源") }
                        }
                        .buttonStyle(.bordered)
                        .disabled(selectedRequestIDs.isEmpty)

                        Button("批量删除", role: .destructive) {
                            Task { await batchRequestAction("delete") }
                        }
                        .buttonStyle(.bordered)
                        .disabled(selectedRequestIDs.isEmpty)
                    }
                }
            } else {
                Text("已选择 \(selectedFeedbackIDs.count) 个反馈工单")
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        Button("批量修复中") {
                            Task { await batchFeedbackAction("fix") }
                        }
                        .buttonStyle(.bordered)
                        .disabled(selectedFeedbackIDs.isEmpty)

                        Button("批量完成") {
                            Task { await batchFeedbackAction("done") }
                        }
                        .buttonStyle(.bordered)
                        .disabled(selectedFeedbackIDs.isEmpty)

                        Button("批量忽略") {
                            Task { await batchFeedbackAction("reject") }
                        }
                        .buttonStyle(.bordered)
                        .disabled(selectedFeedbackIDs.isEmpty)

                        Button("批量删除", role: .destructive) {
                            Task { await batchFeedbackAction("delete") }
                        }
                        .buttonStyle(.bordered)
                        .disabled(selectedFeedbackIDs.isEmpty)
                    }
                }
            }
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
                    Button {
                        if selectionMode {
                            toggleRequestSelection(item)
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            if selectionMode {
                                Image(systemName: selectedRequestIDs.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedRequestIDs.contains(item.id) ? .blue : .secondary)
                            }

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
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("通过") {
                            Task { await viewModel.actOnRequest([item], action: "approve") }
                        }
                        .tint(.green)

                        Button("完成") {
                            Task { await viewModel.actOnRequest([item], action: "finish") }
                        }
                        .tint(.blue)

                        Button("拒绝") {
                            Task { await viewModel.actOnRequest([item], action: "reject", rejectReason: "未找到可用资源") }
                        }
                        .tint(.red)
                    }
                    .contextMenu {
                        Button("手动接单") {
                            Task { await viewModel.actOnRequest([item], action: "manual") }
                        }
                        Button("删除") {
                            Task { await viewModel.actOnRequest([item], action: "delete") }
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
                    Button {
                        if selectionMode {
                            toggleFeedbackSelection(item)
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            if selectionMode {
                                Image(systemName: selectedFeedbackIDs.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedFeedbackIDs.contains(item.id) ? .blue : .secondary)
                            }

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
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("修复中") {
                            Task { await viewModel.actOnFeedback([item], action: "fix") }
                        }
                        .tint(.orange)

                        Button("完成") {
                            Task { await viewModel.actOnFeedback([item], action: "done") }
                        }
                        .tint(.green)

                        Button("忽略") {
                            Task { await viewModel.actOnFeedback([item], action: "reject") }
                        }
                        .tint(.red)
                    }
                    .contextMenu {
                        Button("删除") {
                            Task { await viewModel.actOnFeedback([item], action: "delete") }
                        }
                    }
                }
            }
        } header: {
            Text("资源报错")
        }
    }

    private func toggleRequestSelection(_ item: AdminRequestItem) {
        if selectedRequestIDs.contains(item.id) {
            selectedRequestIDs.remove(item.id)
        } else {
            selectedRequestIDs.insert(item.id)
        }
    }

    private func toggleFeedbackSelection(_ item: AdminFeedbackItem) {
        if selectedFeedbackIDs.contains(item.id) {
            selectedFeedbackIDs.remove(item.id)
        } else {
            selectedFeedbackIDs.insert(item.id)
        }
    }

    private func batchRequestAction(_ action: String, reason: String? = nil) async {
        let items = viewModel.filteredRequests.filter { selectedRequestIDs.contains($0.id) }
        guard !items.isEmpty else { return }
        await viewModel.actOnRequest(items, action: action, rejectReason: reason)
        selectedRequestIDs.removeAll()
        selectionMode = false
    }

    private func batchFeedbackAction(_ action: String) async {
        let items = viewModel.filteredFeedbacks.filter { selectedFeedbackIDs.contains($0.id) }
        guard !items.isEmpty else { return }
        await viewModel.actOnFeedback(items, action: action)
        selectedFeedbackIDs.removeAll()
        selectionMode = false
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
