import SwiftUI

@MainActor
final class TasksCenterViewModel: ObservableObject {
    @Published var groups: [TaskGroup] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var message: String?
    @Published var renamingTask: ScheduledTask?
    @Published var translatedName = ""

    private let api: EmbyPulseAPI

    init(api: EmbyPulseAPI = .shared) {
        self.api = api
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            groups = try await api.fetchTasks()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func start(_ task: ScheduledTask) async {
        do {
            try await api.startTask(taskID: task.id)
            message = "任务已启动"
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stop(_ task: ScheduledTask) async {
        do {
            try await api.stopTask(taskID: task.id)
            message = "任务已停止"
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveAlias() async {
        guard let renamingTask else { return }
        do {
            try await api.translateTask(originalName: renamingTask.originalName, translatedName: translatedName)
            message = "任务别名已保存"
            self.renamingTask = nil
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct TasksCenterView: View {
    @StateObject private var viewModel = TasksCenterViewModel()

    var body: some View {
        List {
            ForEach(viewModel.groups) { group in
                Section(group.title) {
                    ForEach(group.tasks) { task in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(task.name)
                                    .font(.headline)
                                Spacer()
                                if task.state == "Running" {
                                    StatusPill(text: "运行中", tint: .blue)
                                }
                            }

                            if let description = task.description, !description.isEmpty {
                                Text(description)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 10) {
                                if let status = task.lastExecutionResult?.status {
                                    Text("上次结果：\(status)")
                                }
                                if let endTime = task.lastExecutionResult?.endTimeUTC {
                                    Text(AppFormatting.shortDateTime(endTime))
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)

                            if let progress = task.currentProgressPercentage, task.state == "Running" {
                                ProgressView(value: progress, total: 100)
                            }

                            HStack {
                                if task.state == "Running" {
                                    Button("停止") {
                                        Task { await viewModel.stop(task) }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.red)
                                } else {
                                    Button("启动") {
                                        Task { await viewModel.start(task) }
                                    }
                                    .buttonStyle(.borderedProminent)
                                }

                                Button("设置别名") {
                                    viewModel.renamingTask = task
                                    viewModel.translatedName = task.name
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            if viewModel.groups.isEmpty, !viewModel.isLoading {
                Section {
                    EmptyStateView(
                        title: "暂无任务",
                        subtitle: "如果 Emby 返回为空，可能是计划任务接口不可用或当前账号无权限。",
                        symbol: "bolt.slash"
                    )
                }
            }
        }
        .navigationTitle("任务中心")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .task {
            await viewModel.refresh()
        }
        .refreshable {
            await viewModel.refresh()
        }
        .sheet(item: $viewModel.renamingTask) { task in
            NavigationStack {
                Form {
                    Section("原始任务名") {
                        Text(task.originalName)
                            .font(.footnote)
                    }
                    Section("显示名称") {
                        TextField("中文别名", text: $viewModel.translatedName)
                    }
                }
                .navigationTitle("任务别名")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") {
                            viewModel.renamingTask = nil
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            Task { await viewModel.saveAlias() }
                        }
                    }
                }
            }
        }
        .alert(alertTitle, isPresented: alertBinding) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? viewModel.message ?? "")
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
