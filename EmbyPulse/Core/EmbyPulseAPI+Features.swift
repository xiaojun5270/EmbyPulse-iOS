import Foundation

extension EmbyPulseAPI {
    func requestCheckAuth() async throws -> RequestUser? {
        let response: RequestAuthCheckEnvelope = try await request(path: "/api/requests/check")
        guard response.status == "success" else { return nil }
        return response.user
    }

    func requestLogin(username: String, password: String) async throws {
        let response: StatusMessageResponse = try await request(
            path: "/api/requests/auth",
            method: .post,
            body: RequestAuthRequest(username: username, password: password)
        )
        guard response.status == "success" else {
            throw APIError.server(response.message ?? "求片登录失败")
        }
    }

    func requestLogout() async throws {
        let response: StatusMessageResponse = try await request(
            path: "/api/requests/logout",
            method: .post,
            body: EmptyRequest()
        )
        guard response.status == "success" else {
            throw APIError.server(response.message ?? "退出求片登录失败")
        }
    }

    func fetchRequestTrending() async throws -> RequestTrendingData {
        let response: RequestTrendingEnvelope = try await request(path: "/api/requests/trending")
        guard response.status == "success" else {
            throw APIError.server(response.message ?? "获取热门推荐失败")
        }
        return response.data
    }

    func searchRequestMedia(query: String) async throws -> [RequestMediaItem] {
        let response: RequestMediaSearchEnvelope = try await request(
            path: "/api/requests/search",
            query: [URLQueryItem(name: "query", value: query)]
        )
        guard response.status == "success" else {
            throw APIError.server(response.message ?? "搜索求片资源失败")
        }
        return response.data
    }

    func fetchRequestTVDetails(tmdbID: Int) async throws -> [RequestSeason] {
        let response: RequestTVDetailsEnvelope = try await request(path: "/api/requests/tv/\(tmdbID)")
        guard response.status == "success" else {
            throw APIError.server(response.message ?? "获取剧集季信息失败")
        }
        return response.seasons
    }

    func checkRequestLocalStatus(mediaType: String, tmdbID: Int) async throws -> Bool {
        let response: RequestLocalCheckEnvelope = try await request(path: "/api/requests/check/\(mediaType)/\(tmdbID)")
        guard response.status == "success" else {
            throw APIError.server("检查本地状态失败")
        }
        return response.exists
    }

    func submitRequest(_ item: RequestMediaItem, seasons: [Int]) async throws -> String {
        let response: StatusMessageResponse = try await request(
            path: "/api/requests/submit",
            method: .post,
            body: RequestSubmitRequest(
                tmdbID: item.tmdbID,
                mediaType: item.mediaType,
                title: item.title,
                year: item.year,
                posterPath: item.posterPath,
                overview: item.overview,
                seasons: seasons
            )
        )
        guard response.status == "success" else {
            throw APIError.server(response.message ?? "提交求片失败")
        }
        return response.message ?? "提交成功"
    }

    func fetchMyRequests() async throws -> [UserRequestItem] {
        let response: UserRequestsEnvelope = try await request(path: "/api/requests/my")
        guard response.status == "success" else {
            throw APIError.server(response.message ?? "获取我的求片失败")
        }
        return response.data
    }

    func submitFeedback(itemName: String, issueType: String, description: String, posterPath: String) async throws -> String {
        let response: StatusMessageResponse = try await request(
            path: "/api/requests/feedback/submit",
            method: .post,
            body: FeedbackSubmitRequest(itemName: itemName, issueType: issueType, description: description, posterPath: posterPath)
        )
        guard response.status == "success" else {
            throw APIError.server(response.message ?? "提交反馈失败")
        }
        return response.message ?? "提交成功"
    }

    func fetchMyFeedback() async throws -> [UserFeedbackItem] {
        let response: UserFeedbackEnvelope = try await request(path: "/api/requests/feedback/my")
        guard response.status == "success" else {
            throw APIError.server(response.message ?? "获取我的反馈失败")
        }
        return response.data
    }

    func fetchTopMovies(
        userID: String? = nil,
        category: ContentCategory = .all,
        sortBy: RankingSort = .count
    ) async throws -> [RankedItem] {
        var query = [
            URLQueryItem(name: "category", value: category.rawValue),
            URLQueryItem(name: "sort_by", value: sortBy.rawValue)
        ]
        if let userID, !userID.isEmpty, userID != "all" {
            query.append(URLQueryItem(name: "user_id", value: userID))
        }

        let response: RankedItemsEnvelope = try await request(path: "/api/stats/top_movies", query: query)
        guard response.status == "success" else {
            throw APIError.server("获取内容排行失败")
        }
        return response.data
    }

    func fetchHistory(
        page: Int,
        limit: Int = 20,
        userID: String? = nil,
        keyword: String = ""
    ) async throws -> HistoryEnvelope {
        var query = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        if let userID, !userID.isEmpty, userID != "all" {
            query.append(URLQueryItem(name: "user_id", value: userID))
        }
        if !keyword.isEmpty {
            query.append(URLQueryItem(name: "keyword", value: keyword))
        }

        let response: HistoryEnvelope = try await request(path: "/api/history/list", query: query)
        guard response.status == "success" else {
            throw APIError.server(response.message ?? "获取历史记录失败")
        }
        return response
    }

    func fetchUserInsight(userID: String? = nil) async throws -> UserInsight {
        var query: [URLQueryItem] = []
        if let userID, !userID.isEmpty, userID != "all" {
            query.append(URLQueryItem(name: "user_id", value: userID))
        }

        let response: UserInsightEnvelope = try await request(path: "/api/stats/user_details", query: query)
        guard response.status == "success" else {
            throw APIError.server("获取用户画像失败")
        }
        return response.data
    }

    func fetchUserBadges(userID: String? = nil) async throws -> [UserBadge] {
        var query: [URLQueryItem] = []
        if let userID, !userID.isEmpty, userID != "all" {
            query.append(URLQueryItem(name: "user_id", value: userID))
        }

        let response: BadgesEnvelope = try await request(path: "/api/stats/badges", query: query)
        guard response.status == "success" else {
            throw APIError.server("获取趣味勋章失败")
        }
        return response.data
    }

    func fetchPosterData(userID: String? = nil, period: ReportPeriod = .all) async throws -> PosterData {
        var query = [URLQueryItem(name: "period", value: period.rawValue)]
        if let userID, !userID.isEmpty, userID != "all" {
            query.append(URLQueryItem(name: "user_id", value: userID))
        }

        let response: PosterDataEnvelope = try await request(path: "/api/stats/poster_data", query: query)
        guard response.status == "success" else {
            throw APIError.server("获取报表数据失败")
        }
        return response.data
    }

    func fetchTopUsers(period: ReportPeriod = .all) async throws -> [TopUserEntry] {
        let response: TopUsersEnvelope = try await request(
            path: "/api/stats/top_users_list",
            query: [URLQueryItem(name: "period", value: period.rawValue)]
        )
        guard response.status == "success" else {
            throw APIError.server("获取活跃用户排行失败")
        }
        return response.data
    }

    func fetchMonthlyStats(userID: String? = nil) async throws -> [TrendPoint] {
        var query: [URLQueryItem] = []
        if let userID, !userID.isEmpty, userID != "all" {
            query.append(URLQueryItem(name: "user_id", value: userID))
        }

        let response: TrendEnvelope = try await request(path: "/api/stats/monthly_stats", query: query)
        guard response.status == "success" else {
            throw APIError.server("获取月度统计失败")
        }
        return response.data
            .map { TrendPoint(label: $0.key, value: Double($0.value)) }
            .sorted { $0.label < $1.label }
    }

    func fetchQuality(forceRefresh: Bool = false) async throws -> QualityScanData {
        let query = forceRefresh ? [URLQueryItem(name: "force_refresh", value: "true")] : []
        let response: QualityEnvelope = try await request(path: "/api/insight/quality", query: query)
        guard response.status == "success" else {
            throw APIError.server(response.message ?? "质量盘点失败")
        }
        return response.data
    }

    func fetchIgnoredItems() async throws -> [IgnoredItem] {
        let response: IgnoredItemsEnvelope = try await request(path: "/api/insight/ignores")
        guard response.status == "success" else {
            throw APIError.server("获取忽略列表失败")
        }
        return response.data
    }

    func ignoreItem(itemID: String, itemName: String) async throws {
        let response: StatusMessageResponse = try await request(
            path: "/api/insight/ignore",
            method: .post,
            body: IgnoreItemRequest(itemID: itemID, itemName: itemName)
        )
        guard response.status == "success" else {
            throw APIError.server(response.message ?? "忽略失败")
        }
    }

    func unignoreItems(_ itemIDs: [String]) async throws {
        let response: StatusMessageResponse = try await request(
            path: "/api/insight/unignore_batch",
            method: .post,
            body: UnignoreBatchRequest(itemIDs: itemIDs)
        )
        guard response.status == "success" else {
            throw APIError.server(response.message ?? "恢复失败")
        }
    }

    func reportPreviewURL(userID: String? = nil, period: ReportPeriod = .day) -> URL? {
        var query = [URLQueryItem(name: "period", value: period.rawValue)]
        query.append(URLQueryItem(name: "user_id", value: userID?.isEmpty == false ? userID : "all"))
        return buildURL(path: "/api/report/preview", query: query)
    }

    func pushReport(userID: String? = nil, period: ReportPeriod, theme: String) async throws {
        let response: StatusMessageResponse = try await request(
            path: "/api/report/push",
            method: .post,
            body: ReportPushRequest(userID: userID?.isEmpty == false ? userID! : "all", period: period.rawValue, theme: theme)
        )
        guard response.status == "success" else {
            throw APIError.server(response.message ?? "推送报表失败")
        }
    }

    func fetchTasks() async throws -> [TaskGroup] {
        let response: TaskGroupsEnvelope = try await request(path: "/api/tasks")
        guard response.status == "success" else {
            throw APIError.server("获取任务列表失败")
        }
        return response.data
    }

    func startTask(taskID: String) async throws {
        let response: StatusMessageResponse = try await request(
            path: "/api/tasks/\(taskID)/start",
            method: .post,
            body: EmptyRequest()
        )
        guard response.status == "success" else {
            throw APIError.server(response.message ?? "启动任务失败")
        }
    }

    func stopTask(taskID: String) async throws {
        let response: StatusMessageResponse = try await request(
            path: "/api/tasks/\(taskID)/stop",
            method: .post,
            body: EmptyRequest()
        )
        guard response.status == "success" else {
            throw APIError.server(response.message ?? "停止任务失败")
        }
    }

    func translateTask(originalName: String, translatedName: String) async throws {
        let response: StatusMessageResponse = try await request(
            path: "/api/tasks/translate",
            method: .post,
            body: TaskTranslationRequest(originalName: originalName, translatedName: translatedName)
        )
        guard response.status == "success" else {
            throw APIError.server(response.message ?? "保存任务别名失败")
        }
    }

    func fetchBotSettings() async throws -> BotSettings {
        let response: BotSettingsEnvelope = try await request(path: "/api/bot/settings")
        guard response.status == "success" else {
            throw APIError.server("获取机器人配置失败")
        }
        return response.data
    }

    func saveBotSettings(_ settings: BotSettings) async throws {
        let response: StatusMessageResponse = try await request(
            path: "/api/bot/settings",
            method: .post,
            body: settings
        )
        guard response.status == "success" else {
            throw APIError.server(response.message ?? "保存机器人配置失败")
        }
    }

    func testTelegramBot() async throws -> String {
        let response: StatusMessageResponse = try await request(
            path: "/api/bot/test",
            method: .post,
            body: EmptyRequest()
        )
        guard response.status == "success" else {
            throw APIError.server(response.message ?? "Telegram 测试失败")
        }
        return response.message ?? "Telegram 测试成功"
    }

    func testWeComBot() async throws -> String {
        let response: StatusMessageResponse = try await request(
            path: "/api/bot/test_wecom",
            method: .post,
            body: EmptyRequest()
        )
        guard response.status == "success" else {
            throw APIError.server(response.message ?? "企业微信测试失败")
        }
        return response.message ?? "企业微信测试成功"
    }

    func fetchAdminRequests() async throws -> [AdminRequestItem] {
        let response: AdminRequestsEnvelope = try await request(path: "/api/manage/requests")
        guard response.status == "success" else {
            throw APIError.server("获取求片列表失败")
        }
        return response.data
    }

    func updateRequests(
        items: [RequestActionItem],
        action: String,
        rejectReason: String? = nil
    ) async throws {
        let response: StatusMessageResponse = try await request(
            path: "/api/manage/requests/batch",
            method: .post,
            body: RequestBatchActionRequest(items: items, action: action, rejectReason: rejectReason)
        )
        guard response.status == "success" else {
            throw APIError.server(response.message ?? "更新求片状态失败")
        }
    }

    func fetchAdminFeedback() async throws -> [AdminFeedbackItem] {
        let response: AdminFeedbackEnvelope = try await request(path: "/api/manage/feedback")
        guard response.status == "success" else {
            throw APIError.server("获取反馈工单失败")
        }
        return response.data
    }

    func updateFeedback(id: Int, action: String) async throws {
        let response: StatusMessageResponse = try await request(
            path: "/api/manage/feedback/action",
            method: .post,
            body: FeedbackActionRequest(id: id, action: action)
        )
        guard response.status == "success" else {
            throw APIError.server(response.message ?? "更新反馈状态失败")
        }
    }

    func batchFeedback(ids: [Int], action: String) async throws {
        let response: StatusMessageResponse = try await request(
            path: "/api/manage/feedback/batch",
            method: .post,
            body: FeedbackBatchActionRequest(items: ids, action: action)
        )
        guard response.status == "success" else {
            throw APIError.server(response.message ?? "批量处理反馈失败")
        }
    }

    func fetchClientsData() async throws -> ClientsDataEnvelope {
        let response: ClientsDataEnvelope = try await request(path: "/api/clients/data")
        guard response.status == "success" else {
            throw APIError.server(response.message ?? "获取客户端数据失败")
        }
        return response
    }

    func fetchBlacklist() async throws -> [BlacklistedApp] {
        let response: BlacklistEnvelope = try await request(path: "/api/clients/blacklist")
        guard response.status == "success" else {
            throw APIError.server(response.message ?? "获取黑名单失败")
        }
        return response.data
    }

    func addBlacklist(appName: String) async throws {
        let response: StatusMessageResponse = try await request(
            path: "/api/clients/blacklist",
            method: .post,
            body: BlacklistRequest(appName: appName)
        )
        guard response.status == "success" else {
            throw APIError.server(response.message ?? "添加黑名单失败")
        }
    }

    func deleteBlacklist(appName: String) async throws {
        let response: StatusMessageResponse = try await request(
            path: "/api/clients/blacklist/\(appName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? appName)",
            method: .delete
        )
        guard response.status == "success" else {
            throw APIError.server(response.message ?? "删除黑名单失败")
        }
    }

    func executeClientBlock() async throws -> String {
        let response: StatusMessageResponse = try await request(
            path: "/api/clients/execute_block",
            method: .post,
            body: EmptyRequest()
        )
        guard response.status == "success" else {
            throw APIError.server(response.message ?? "执行封禁失败")
        }
        return response.message ?? "执行成功"
    }

    func searchLibrary(query text: String) async throws -> [LibrarySearchResult] {
        let response: LibrarySearchEnvelope = try await request(
            path: "/api/library/search",
            query: [URLQueryItem(name: "query", value: text)]
        )
        guard response.status == "success" else {
            throw APIError.server(response.message ?? "搜索失败")
        }
        return response.data
    }

    func fetchInvites() async throws -> [InviteCode] {
        let response: InviteListEnvelope = try await request(path: "/api/manage/invites")
        guard response.status == "success" else {
            throw APIError.server(response.message ?? "获取邀请码失败")
        }
        return response.data
    }

    func deleteInvites(codes: [String]) async throws {
        let response: StatusMessageResponse = try await request(
            path: "/api/manage/invites/batch",
            method: .post,
            body: InviteBatchActionRequest(codes: codes, action: "delete")
        )
        guard response.status == "success" else {
            throw APIError.server(response.message ?? "删除邀请码失败")
        }
    }

    func generateInvites(days: Int, count: Int) async throws -> [String] {
        let response: InviteGenerateResponse = try await request(
            path: "/api/manage/invite/gen",
            method: .post,
            body: InviteGenerateRequest(days: days, templateUserID: nil, count: count)
        )
        guard response.status == "success" else {
            throw APIError.server(response.message ?? "生成邀请码失败")
        }
        return response.codes ?? []
    }

    func createUser(name: String, password: String, expireDate: String?) async throws {
        let response: StatusMessageResponse = try await request(
            path: "/api/manage/user/new",
            method: .post,
            body: NewUserRequest(
                name: name,
                password: password.isEmpty ? nil : password,
                expireDate: expireDate?.isEmpty == true ? nil : expireDate,
                templateUserID: nil,
                copyLibrary: true,
                copyPolicy: true,
                copyParental: true
            )
        )
        guard response.status == "success" else {
            throw APIError.server(response.message ?? "创建用户失败")
        }
    }

    func fetchUserDetail(userID: String) async throws -> ManagedUserDetail {
        let response: ManagedUserDetailEnvelope = try await request(path: "/api/manage/user/\(userID)")
        guard response.status == "success", let detail = response.data else {
            throw APIError.server("获取用户详情失败")
        }
        return detail
    }

    func updateUserDetail(_ requestBody: UserDetailUpdateRequest) async throws {
        let response: StatusMessageResponse = try await request(
            path: "/api/manage/user/update",
            method: .post,
            body: requestBody
        )
        guard response.status == "success" else {
            throw APIError.server(response.message ?? "更新用户失败")
        }
    }

    func batchUpdateUsers(userIDs: [String], action: String, value: String? = nil) async throws {
        let response: StatusMessageResponse = try await request(
            path: "/api/manage/users/batch",
            method: .post,
            body: BatchUserActionRequest(
                userIDs: userIDs,
                action: action,
                value: value,
                copyLibrary: false,
                copyPolicy: false,
                copyParental: false
            )
        )
        guard response.status == "success" else {
            throw APIError.server(response.message ?? "批量操作用户失败")
        }
    }

    func deleteUser(userID: String) async throws {
        let response: StatusMessageResponse = try await request(
            path: "/api/manage/user/\(userID)",
            method: .delete
        )
        guard response.status == "success" else {
            throw APIError.server(response.message ?? "删除用户失败")
        }
    }
}
