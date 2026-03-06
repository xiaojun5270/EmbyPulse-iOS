import Foundation

struct StatusMessageResponse: Decodable {
    let status: String
    let message: String?
}

struct DashboardEnvelope: Decodable {
    let status: String
    let data: DashboardSnapshot
}

struct DashboardSnapshot: Decodable {
    let totalPlays: Int
    let activeUsers: Int
    let totalDuration: Int
    let library: LibraryOverview

    enum CodingKeys: String, CodingKey {
        case totalPlays = "total_plays"
        case activeUsers = "active_users"
        case totalDuration = "total_duration"
        case library
    }
}

struct LibraryOverview: Decodable {
    let movie: Int
    let series: Int
    let episode: Int
}

struct TrendEnvelope: Decodable {
    let status: String
    let data: [String: Int]
}

struct TrendPoint: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
}

struct LiveSessionsEnvelope: Decodable {
    let status: String
    let data: [LiveSession]
}

struct LiveSession: Decodable, Identifiable {
    let id: String
    let userName: String
    let client: String?
    let deviceName: String?
    let remoteEndPoint: String?
    let nowPlayingItem: LiveMediaItem?
    let playState: LivePlayState?
    let transcodingInfo: LiveTranscodingInfo?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case userName = "UserName"
        case client = "Client"
        case deviceName = "DeviceName"
        case remoteEndPoint = "RemoteEndPoint"
        case nowPlayingItem = "NowPlayingItem"
        case playState = "PlayState"
        case transcodingInfo = "TranscodingInfo"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        userName = try container.decodeIfPresent(String.self, forKey: .userName) ?? "Unknown"
        client = try container.decodeIfPresent(String.self, forKey: .client)
        deviceName = try container.decodeIfPresent(String.self, forKey: .deviceName)
        remoteEndPoint = try container.decodeIfPresent(String.self, forKey: .remoteEndPoint)
        nowPlayingItem = try container.decodeIfPresent(LiveMediaItem.self, forKey: .nowPlayingItem)
        playState = try container.decodeIfPresent(LivePlayState.self, forKey: .playState)
        transcodingInfo = try container.decodeIfPresent(LiveTranscodingInfo.self, forKey: .transcodingInfo)
    }

    var title: String {
        nowPlayingItem?.name ?? "Unknown Media"
    }

    var subtitle: String {
        [client, deviceName].compactMap { $0 }.joined(separator: " / ")
    }

    var progress: Double {
        guard
            let positionTicks = playState?.positionTicks,
            let runtimeTicks = nowPlayingItem?.runTimeTicks,
            runtimeTicks > 0
        else {
            return 0
        }

        return min(max(Double(positionTicks) / Double(runtimeTicks), 0), 1)
    }

    var isTranscoding: Bool {
        transcodingInfo != nil
    }
}

struct LiveMediaItem: Decodable {
    let name: String
    let type: String?
    let seriesName: String?
    let runTimeTicks: Int64?

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case type = "Type"
        case seriesName = "SeriesName"
        case runTimeTicks = "RunTimeTicks"
    }
}

struct LivePlayState: Decodable {
    let positionTicks: Int64?

    enum CodingKeys: String, CodingKey {
        case positionTicks = "PositionTicks"
    }
}

struct LiveTranscodingInfo: Decodable {
    let audioCodec: String?
    let videoCodec: String?

    enum CodingKeys: String, CodingKey {
        case audioCodec = "AudioCodec"
        case videoCodec = "VideoCodec"
    }
}

struct RecentActivityEnvelope: Decodable {
    let status: String
    let data: [RecentActivity]
}

struct RecentActivity: Decodable, Identifiable {
    let id = UUID()
    let dateCreated: String?
    let userName: String
    let displayName: String
    let itemType: String?

    enum CodingKeys: String, CodingKey {
        case dateCreated = "DateCreated"
        case userName = "UserName"
        case displayName = "DisplayName"
        case itemType = "ItemType"
    }
}

struct LatestMediaEnvelope: Decodable {
    let status: String
    let data: [LatestMedia]
}

struct LatestMedia: Decodable, Identifiable {
    let id: String
    let name: String
    let seriesName: String?
    let year: Int?
    let rating: Double?
    let type: String?
    let dateCreated: String?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case seriesName = "SeriesName"
        case year = "Year"
        case rating = "Rating"
        case type = "Type"
        case dateCreated = "DateCreated"
    }
}

struct CalendarWeekResponse: Decodable {
    let error: String?
    let days: [CalendarDay]
    let embyURL: String
    let serverID: String
    let dateRange: String
    let currentTTL: Int

    enum CodingKeys: String, CodingKey {
        case error
        case days
        case embyURL = "emby_url"
        case serverID = "server_id"
        case dateRange = "date_range"
        case currentTTL = "current_ttl"
    }
}

struct CalendarDay: Decodable, Identifiable {
    let date: String
    let weekdayCN: String
    let isToday: Bool
    let items: [CalendarEntry]

    enum CodingKeys: String, CodingKey {
        case date
        case weekdayCN = "weekday_cn"
        case isToday = "is_today"
        case items
    }

    var id: String { date }
}

struct CalendarEntry: Decodable, Identifiable {
    let seriesName: String
    let seriesID: String?
    let tmdbID: String?
    let episodeName: String?
    let season: Int
    let episodeText: String
    let airDate: String?
    let posterPath: String?
    let status: String
    let overview: String?
    let seriesOverview: String?

    enum CodingKeys: String, CodingKey {
        case seriesName = "series_name"
        case seriesID = "series_id"
        case tmdbID = "tmdb_id"
        case episodeName = "ep_name"
        case season
        case episode
        case airDate = "air_date"
        case posterPath = "poster_path"
        case status
        case overview
        case seriesOverview = "series_overview"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        seriesName = try container.decode(String.self, forKey: .seriesName)
        seriesID = try container.decodeLossyStringIfPresent(forKey: .seriesID)
        tmdbID = try container.decodeLossyStringIfPresent(forKey: .tmdbID)
        episodeName = try container.decodeIfPresent(String.self, forKey: .episodeName)
        season = try container.decode(Int.self, forKey: .season)
        episodeText = try container.decodeLossyString(forKey: .episode)
        airDate = try container.decodeIfPresent(String.self, forKey: .airDate)
        posterPath = try container.decodeIfPresent(String.self, forKey: .posterPath)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "unknown"
        overview = try container.decodeIfPresent(String.self, forKey: .overview)
        seriesOverview = try container.decodeIfPresent(String.self, forKey: .seriesOverview)
    }

    var id: String {
        "\(seriesID ?? seriesName)-\(season)-\(episodeText)-\(airDate ?? "")"
    }

    var episodeDisplay: String {
        "S\(String(format: "%02d", season))E\(episodeText)"
    }

    var summaryText: String {
        let trimmed = (overview?.isEmpty == false ? overview : seriesOverview) ?? "暂无简介"
        return trimmed
    }
}

struct UsersEnvelope: Decodable {
    let status: String
    let data: [ManagedUser]
    let embyURL: String?

    enum CodingKeys: String, CodingKey {
        case status
        case data
        case embyURL = "emby_url"
    }
}

struct ManagedUser: Decodable, Identifiable, Equatable {
    let id: String
    let name: String
    let lastLoginDate: String?
    let isDisabled: Bool
    let isAdmin: Bool
    let expireDate: String?
    let note: String?
    let primaryImageTag: String?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case lastLoginDate = "LastLoginDate"
        case isDisabled = "IsDisabled"
        case isAdmin = "IsAdmin"
        case expireDate = "ExpireDate"
        case note = "Note"
        case primaryImageTag = "PrimaryImageTag"
    }
}

struct SettingsEnvelope: Decodable {
    let status: String
    let data: AppSettings
}

struct AppSettings: Codable, Equatable {
    var embyHost: String = ""
    var embyAPIKey: String = ""
    var tmdbAPIKey: String = ""
    var proxyURL: String = ""
    var webhookToken: String = "embypulse"
    var hiddenUsers: [String] = []
    var embyPublicURL: String = ""
    var welcomeMessage: String = ""
    var clientDownloadURL: String = ""
    var moviePilotURL: String = ""
    var moviePilotToken: String = ""
    var pulseURL: String = ""

    enum CodingKeys: String, CodingKey {
        case embyHost = "emby_host"
        case embyAPIKey = "emby_api_key"
        case tmdbAPIKey = "tmdb_api_key"
        case proxyURL = "proxy_url"
        case webhookToken = "webhook_token"
        case hiddenUsers = "hidden_users"
        case embyPublicURL = "emby_public_url"
        case welcomeMessage = "welcome_message"
        case clientDownloadURL = "client_download_url"
        case moviePilotURL = "moviepilot_url"
        case moviePilotToken = "moviepilot_token"
        case pulseURL = "pulse_url"
    }
}

struct CalendarTTLRequest: Encodable {
    let ttl: Int
}

struct LoginRequest: Encodable {
    let username: String
    let password: String
}

struct UserStatusUpdateRequest: Encodable {
    let userID: String
    let isDisabled: Bool

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case isDisabled = "is_disabled"
    }
}

enum TrendDimension: String, CaseIterable, Identifiable {
    case day
    case week
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day:
            return "日"
        case .week:
            return "周"
        case .month:
            return "月"
        }
    }
}

enum CalendarTTL: Int, CaseIterable, Identifiable {
    case oneHour = 3600
    case oneDay = 86400
    case sevenDays = 604800

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .oneHour:
            return "1 小时"
        case .oneDay:
            return "1 天"
        case .sevenDays:
            return "7 天"
        }
    }
}

extension KeyedDecodingContainer {
    func decodeLossyString(forKey key: Key) throws -> String {
        if let stringValue = try? decode(String.self, forKey: key) {
            return stringValue
        }
        if let intValue = try? decode(Int.self, forKey: key) {
            return String(intValue)
        }
        if let doubleValue = try? decode(Double.self, forKey: key) {
            return String(Int(doubleValue))
        }

        throw DecodingError.typeMismatch(
            String.self,
            .init(codingPath: codingPath + [key], debugDescription: "Expected a string-like value.")
        )
    }

    func decodeLossyStringIfPresent(forKey key: Key) throws -> String? {
        if let stringValue = try? decodeIfPresent(String.self, forKey: key) {
            return stringValue
        }
        if let intValue = try? decodeIfPresent(Int.self, forKey: key) {
            return intValue.map(String.init)
        }
        if let doubleValue = try? decodeIfPresent(Double.self, forKey: key) {
            return doubleValue.map { String(Int($0)) }
        }
        return nil
    }
}
