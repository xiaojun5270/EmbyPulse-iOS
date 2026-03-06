import Foundation

struct RankedItemsEnvelope: Decodable {
    let status: String
    let data: [RankedItem]
}

struct RankedItem: Decodable, Identifiable {
    let itemName: String
    let itemID: String?
    let playCount: Int
    let totalTime: Int

    enum CodingKeys: String, CodingKey {
        case itemName = "ItemName"
        case itemID = "ItemId"
        case playCount = "PlayCount"
        case totalTime = "TotalTime"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        itemName = try container.decode(String.self, forKey: .itemName)
        itemID = try container.decodeLossyStringIfPresent(forKey: .itemID)
        playCount = try container.decodeIfPresent(Int.self, forKey: .playCount) ?? 0
        totalTime = try container.decodeIfPresent(Int.self, forKey: .totalTime) ?? 0
    }

    var id: String { "\(itemID ?? itemName)-\(playCount)-\(totalTime)" }
}

struct HistoryEnvelope: Decodable {
    let status: String
    let data: [HistoryEntry]
    let pagination: PaginationInfo?
    let message: String?
}

struct PaginationInfo: Decodable {
    let page: Int
    let limit: Int
    let total: Int
    let totalPages: Int

    enum CodingKeys: String, CodingKey {
        case page
        case limit
        case total
        case totalPages = "total_pages"
    }
}

struct HistoryEntry: Decodable, Identifiable {
    let id = UUID()
    let dateCreated: String?
    let userID: String?
    let userName: String?
    let itemID: String?
    let itemName: String
    let itemType: String?
    let playDuration: Int?
    let deviceName: String?
    let clientName: String?
    let durationText: String?
    let dateText: String?

    enum CodingKeys: String, CodingKey {
        case dateCreated = "DateCreated"
        case userID = "UserId"
        case userName = "UserName"
        case itemID = "ItemId"
        case itemName = "ItemName"
        case itemType = "ItemType"
        case playDuration = "PlayDuration"
        case deviceName = "DeviceName"
        case clientName = "ClientName"
        case durationText = "DurationStr"
        case dateText = "DateStr"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dateCreated = try container.decodeIfPresent(String.self, forKey: .dateCreated)
        userID = try container.decodeLossyStringIfPresent(forKey: .userID)
        userName = try container.decodeIfPresent(String.self, forKey: .userName)
        itemID = try container.decodeLossyStringIfPresent(forKey: .itemID)
        itemName = try container.decodeIfPresent(String.self, forKey: .itemName) ?? "Unknown"
        itemType = try container.decodeIfPresent(String.self, forKey: .itemType)
        playDuration = try container.decodeIfPresent(Int.self, forKey: .playDuration)
        deviceName = try container.decodeIfPresent(String.self, forKey: .deviceName)
        clientName = try container.decodeIfPresent(String.self, forKey: .clientName)
        durationText = try container.decodeIfPresent(String.self, forKey: .durationText)
        dateText = try container.decodeIfPresent(String.self, forKey: .dateText)
    }
}

struct UserInsightEnvelope: Decodable {
    let status: String
    let data: UserInsight
}

struct UserInsight: Decodable {
    let hourly: [String: Int]
    let devices: [LabelCount]
    let clients: [LabelCount]
    let logs: [InsightLog]
    let overview: UserOverviewStats
    let preference: UserPreference
    let topFavorite: TopFavorite?

    enum CodingKeys: String, CodingKey {
        case hourly
        case devices
        case clients
        case logs
        case overview
        case preference
        case topFavorite = "top_fav"
    }
}

struct LabelCount: Decodable, Identifiable {
    let label: String
    let plays: Int

    var id: String { label }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode([String: JSONValue].self)
        label = raw["Device"]?.stringValue ?? raw["Client"]?.stringValue ?? raw["label"]?.stringValue ?? "Unknown"
        plays = raw["Plays"]?.intValue ?? raw["plays"]?.intValue ?? 0
    }
}

struct InsightLog: Decodable, Identifiable {
    let id = UUID()
    let dateCreated: String?
    let itemName: String
    let playDuration: Int?
    let device: String?
    let userName: String?

    enum CodingKeys: String, CodingKey {
        case dateCreated = "DateCreated"
        case itemName = "ItemName"
        case playDuration = "PlayDuration"
        case device = "Device"
        case userName = "UserName"
    }
}

struct UserOverviewStats: Decodable {
    let totalPlays: Int
    let totalDuration: Int
    let averageDuration: Int
    let accountAgeDays: Int

    enum CodingKeys: String, CodingKey {
        case totalPlays = "total_plays"
        case totalDuration = "total_duration"
        case averageDuration = "avg_duration"
        case accountAgeDays = "account_age_days"
    }
}

struct UserPreference: Decodable {
    let moviePlays: Int
    let episodePlays: Int

    enum CodingKeys: String, CodingKey {
        case moviePlays = "movie_plays"
        case episodePlays = "episode_plays"
    }
}

struct TopFavorite: Decodable {
    let itemName: String
    let itemID: String?
    let count: Int
    let duration: Int

    enum CodingKeys: String, CodingKey {
        case itemName = "ItemName"
        case itemID = "ItemId"
        case count = "c"
        case duration = "d"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        itemName = try container.decode(String.self, forKey: .itemName)
        itemID = try container.decodeLossyStringIfPresent(forKey: .itemID)
        count = try container.decodeIfPresent(Int.self, forKey: .count) ?? 0
        duration = try container.decodeIfPresent(Int.self, forKey: .duration) ?? 0
    }
}

struct BadgesEnvelope: Decodable {
    let status: String
    let data: [UserBadge]
}

struct UserBadge: Decodable, Identifiable {
    let id: String
    let name: String
    let icon: String?
    let color: String?
    let background: String?
    let description: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case icon
        case color
        case background = "bg"
        case description = "desc"
    }
}

struct PosterDataEnvelope: Decodable {
    let status: String
    let data: PosterData
}

struct PosterData: Decodable {
    let plays: Int
    let hours: Int
    let serverPlays: Int
    let topList: [PosterDataItem]
    let tags: [String]

    enum CodingKeys: String, CodingKey {
        case plays
        case hours
        case serverPlays = "server_plays"
        case topList = "top_list"
        case tags
    }
}

struct PosterDataItem: Decodable, Identifiable {
    let itemName: String
    let itemID: String?
    let count: Int
    let duration: Int

    enum CodingKeys: String, CodingKey {
        case itemName = "ItemName"
        case itemID = "ItemId"
        case count = "Count"
        case duration = "Duration"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        itemName = try container.decode(String.self, forKey: .itemName)
        itemID = try container.decodeLossyStringIfPresent(forKey: .itemID)
        count = try container.decodeIfPresent(Int.self, forKey: .count) ?? 0
        duration = try container.decodeIfPresent(Int.self, forKey: .duration) ?? 0
    }

    var id: String { "\(itemID ?? itemName)-\(count)" }
}

struct TopUsersEnvelope: Decodable {
    let status: String
    let data: [TopUserEntry]
}

struct TopUserEntry: Decodable, Identifiable {
    let userID: String
    let userName: String
    let plays: Int
    let totalTime: Int

    enum CodingKeys: String, CodingKey {
        case userID = "UserId"
        case userName = "UserName"
        case plays = "Plays"
        case totalTime = "TotalTime"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userID = try container.decodeLossyString(forKey: .userID)
        userName = try container.decodeIfPresent(String.self, forKey: .userName) ?? "Unknown"
        plays = try container.decodeIfPresent(Int.self, forKey: .plays) ?? 0
        totalTime = try container.decodeIfPresent(Int.self, forKey: .totalTime) ?? 0
    }

    var id: String { userID }
}

struct QualityEnvelope: Decodable {
    let status: String
    let data: QualityScanData
    let message: String?
}

struct QualityScanData: Decodable {
    let totalCount: Int
    let scanTime: String
    let movies: [String: [QualityMovie]]

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case scanTime = "scan_time_str"
        case movies
    }
}

struct QualityMovie: Decodable, Identifiable {
    let id: String
    let name: String
    let year: Int?
    let resolution: String?
    let path: String?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case year = "Year"
        case resolution = "Resolution"
        case path = "Path"
    }
}

struct IgnoredItemsEnvelope: Decodable {
    let status: String
    let data: [IgnoredItem]
}

struct IgnoredItem: Decodable, Identifiable {
    let itemID: String
    let itemName: String?
    let ignoredAt: String?

    enum CodingKeys: String, CodingKey {
        case itemID = "item_id"
        case itemName = "item_name"
        case ignoredAt = "ignored_at"
    }

    var id: String { itemID }
}

struct IgnoreItemRequest: Encodable {
    let itemID: String
    let itemName: String

    enum CodingKeys: String, CodingKey {
        case itemID = "item_id"
        case itemName = "item_name"
    }
}

struct UnignoreBatchRequest: Encodable {
    let itemIDs: [String]

    enum CodingKeys: String, CodingKey {
        case itemIDs = "item_ids"
    }
}

struct TaskGroupsEnvelope: Decodable {
    let status: String
    let data: [TaskGroup]
}

struct TaskGroup: Decodable, Identifiable {
    let title: String
    let tasks: [ScheduledTask]

    var id: String { title }
}

struct ScheduledTask: Decodable, Identifiable {
    let id: String
    let name: String
    let originalName: String
    let description: String?
    let state: String?
    let currentProgressPercentage: Double?
    let lastExecutionResult: TaskExecutionResult?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case originalName = "OriginalName"
        case description = "Description"
        case state = "State"
        case currentProgressPercentage = "CurrentProgressPercentage"
        case lastExecutionResult = "LastExecutionResult"
    }
}

struct TaskExecutionResult: Decodable {
    let status: String?
    let endTimeUTC: String?

    enum CodingKeys: String, CodingKey {
        case status = "Status"
        case endTimeUTC = "EndTimeUtc"
    }
}

struct TaskTranslationRequest: Encodable {
    let originalName: String
    let translatedName: String

    enum CodingKeys: String, CodingKey {
        case originalName = "original_name"
        case translatedName = "translated_name"
    }
}

struct BotSettingsEnvelope: Decodable {
    let status: String
    let data: BotSettings
}

struct BotSettings: Codable, Equatable {
    var tgBotToken: String = ""
    var tgChatID: String = ""
    var enableBot: Bool = false
    var enableNotify: Bool = false
    var enableLibraryNotify: Bool = false
    var wecomCorpid: String = ""
    var wecomCorpsecret: String = ""
    var wecomAgentid: String = ""
    var wecomTouser: String = "@all"
    var wecomProxyURL: String = "https://qyapi.weixin.qq.com"
    var wecomToken: String = ""
    var wecomAESKey: String = ""
    var webhookToken: String = "embypulse"

    enum CodingKeys: String, CodingKey {
        case tgBotToken = "tg_bot_token"
        case tgChatID = "tg_chat_id"
        case enableBot = "enable_bot"
        case enableNotify = "enable_notify"
        case enableLibraryNotify = "enable_library_notify"
        case wecomCorpid = "wecom_corpid"
        case wecomCorpsecret = "wecom_corpsecret"
        case wecomAgentid = "wecom_agentid"
        case wecomTouser = "wecom_touser"
        case wecomProxyURL = "wecom_proxy_url"
        case wecomToken = "wecom_token"
        case wecomAESKey = "wecom_aeskey"
        case webhookToken = "webhook_token"
    }
}

struct AdminRequestsEnvelope: Decodable {
    let status: String
    let data: [AdminRequestItem]
}

struct AdminRequestItem: Decodable, Identifiable {
    let tmdbID: Int
    let mediaType: String
    let title: String
    let year: String?
    let posterPath: String?
    let status: Int
    let season: Int
    let createdAt: String?
    let requestCount: Int
    let requestedBy: String?
    let rejectReason: String?

    enum CodingKeys: String, CodingKey {
        case tmdbID = "tmdb_id"
        case mediaType = "media_type"
        case title
        case year
        case posterPath = "poster_path"
        case status
        case season
        case createdAt = "created_at"
        case requestCount = "request_count"
        case requestedBy = "requested_by"
        case rejectReason = "reject_reason"
    }

    var id: String { "\(tmdbID)-\(season)" }
}

struct RequestBatchActionRequest: Encodable {
    let items: [RequestActionItem]
    let action: String
    let rejectReason: String?

    enum CodingKeys: String, CodingKey {
        case items
        case action
        case rejectReason = "reject_reason"
    }
}

struct RequestActionItem: Encodable {
    let tmdbID: Int
    let season: Int

    enum CodingKeys: String, CodingKey {
        case tmdbID = "tmdb_id"
        case season
    }
}

struct AdminFeedbackEnvelope: Decodable {
    let status: String
    let data: [AdminFeedbackItem]
}

struct AdminFeedbackItem: Decodable, Identifiable {
    let id: Int
    let itemName: String
    let username: String
    let issueType: String
    let description: String?
    let status: Int
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case itemName = "item_name"
        case username
        case issueType = "issue_type"
        case description
        case status
        case createdAt = "created_at"
    }
}

struct FeedbackActionRequest: Encodable {
    let id: Int
    let action: String
}

struct FeedbackBatchActionRequest: Encodable {
    let items: [Int]
    let action: String
}

struct ClientsDataEnvelope: Decodable {
    let status: String
    let message: String?
    let charts: ClientCharts?
    let devices: [ClientDevice]
}

struct ClientCharts: Decodable {
    let pie: ChartBucket
    let bar: ChartBucket
}

struct ChartBucket: Decodable {
    let labels: [String]
    let data: [Int]
}

struct ClientDevice: Decodable, Identifiable {
    let id: String
    let name: String
    let appName: String
    let lastActive: String
    let lastUser: String
    let isActive: Bool
    let isBlocked: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case appName = "app_name"
        case lastActive = "last_active"
        case lastUser = "last_user"
        case isActive = "is_active"
        case isBlocked = "is_blocked"
    }
}

struct BlacklistEnvelope: Decodable {
    let status: String
    let data: [BlacklistedApp]
    let message: String?
}

struct BlacklistedApp: Decodable, Identifiable {
    let appName: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case appName = "app_name"
        case createdAt = "created_at"
    }

    var id: String { appName }
}

struct BlacklistRequest: Encodable {
    let appName: String

    enum CodingKeys: String, CodingKey {
        case appName = "app_name"
    }
}

struct LibrarySearchEnvelope: Decodable {
    let status: String
    let data: [LibrarySearchResult]
    let message: String?
}

struct LibrarySearchResult: Decodable, Identifiable {
    let id: String
    let name: String
    let yearText: String
    let overview: String
    let type: String
    let poster: String
    let embyURL: String
    let badges: [LibraryBadge]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case yearText = "year"
        case overview
        case type
        case poster
        case embyURL = "emby_url"
        case badges
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeLossyString(forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        yearText = try container.decodeLossyStringIfPresent(forKey: .yearText) ?? "未知"
        overview = try container.decodeIfPresent(String.self, forKey: .overview) ?? "暂无简介"
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? "unknown"
        poster = try container.decodeIfPresent(String.self, forKey: .poster) ?? ""
        embyURL = try container.decodeIfPresent(String.self, forKey: .embyURL) ?? ""
        badges = try container.decodeIfPresent([LibraryBadge].self, forKey: .badges) ?? []
    }
}

struct LibraryBadge: Decodable, Identifiable {
    let id = UUID()
    let type: String
    let text: String
    let color: String?
}

struct InviteListEnvelope: Decodable {
    let status: String
    let data: [InviteCode]
    let message: String?
}

struct InviteCode: Decodable, Identifiable {
    let code: String
    let days: Int?
    let createdAt: String?
    let usedCount: Int?
    let maxUses: Int?
    let usedBy: String?
    let usedAt: String?
    let status: Int?

    enum CodingKeys: String, CodingKey {
        case code
        case days
        case createdAt = "created_at"
        case usedCount = "used_count"
        case maxUses = "max_uses"
        case usedBy = "used_by"
        case usedAt = "used_at"
        case status
    }

    var id: String { code }
}

struct InviteGenerateRequest: Encodable {
    let days: Int
    let templateUserID: String?
    let count: Int

    enum CodingKeys: String, CodingKey {
        case days
        case templateUserID = "template_user_id"
        case count
    }
}

struct InviteGenerateResponse: Decodable {
    let status: String
    let codes: [String]?
    let message: String?
}

struct NewUserRequest: Encodable {
    let name: String
    let password: String?
    let expireDate: String?
    let templateUserID: String?
    let copyLibrary: Bool
    let copyPolicy: Bool
    let copyParental: Bool

    enum CodingKeys: String, CodingKey {
        case name
        case password
        case expireDate = "expire_date"
        case templateUserID = "template_user_id"
        case copyLibrary = "copy_library"
        case copyPolicy = "copy_policy"
        case copyParental = "copy_parental"
    }
}

struct ReportPushRequest: Encodable {
    let userID: String
    let period: String
    let theme: String

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case period
        case theme
    }
}

enum ContentCategory: String, CaseIterable, Identifiable {
    case all
    case movie = "Movie"
    case episode = "Episode"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "全部"
        case .movie:
            return "电影"
        case .episode:
            return "剧集"
        }
    }
}

enum RankingSort: String, CaseIterable, Identifiable {
    case count
    case time

    var id: String { rawValue }

    var title: String {
        switch self {
        case .count:
            return "按次数"
        case .time:
            return "按时长"
        }
    }
}

enum ReportPeriod: String, CaseIterable, Identifiable {
    case day
    case week
    case month
    case year
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day:
            return "日报"
        case .week:
            return "周报"
        case .month:
            return "月报"
        case .year:
            return "年报"
        case .all:
            return "总览"
        }
    }
}

enum RequestStatusFilter: Int, CaseIterable, Identifiable {
    case all = -99
    case pending = 0
    case approved = 1
    case done = 2
    case rejected = 3
    case manual = 4

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .all: return "全部"
        case .pending: return "待处理"
        case .approved: return "已推送"
        case .done: return "已完成"
        case .rejected: return "已拒绝"
        case .manual: return "手动处理"
        }
    }
}

enum FeedbackStatusFilter: Int, CaseIterable, Identifiable {
    case all = -99
    case pending = 0
    case fixing = 1
    case done = 2
    case rejected = 3

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .all: return "全部"
        case .pending: return "待处理"
        case .fixing: return "修复中"
        case .done: return "已修复"
        case .rejected: return "忽略"
        }
    }
}

enum JSONValue: Decodable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.typeMismatch(JSONValue.self, .init(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON value"))
        }
    }

    var stringValue: String? {
        switch self {
        case .string(let value):
            return value
        case .int(let value):
            return String(value)
        case .double(let value):
            return String(Int(value))
        default:
            return nil
        }
    }

    var intValue: Int? {
        switch self {
        case .int(let value):
            return value
        case .double(let value):
            return Int(value)
        case .string(let value):
            return Int(value)
        default:
            return nil
        }
    }
}
