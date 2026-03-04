//
//  DashboardModel.swift
//  EmbyPulse
//
//  Created by EmbyPulse Team on 2026/03/04.
//

import Foundation

// 仪表盘统计
struct DashboardStats: Codable {
    let total_users: Int
    let active_users: Int
    let online_users: Int
    let total_plays: Int64
    let total_duration: Int64
    let total_size: Int64?
    let server_count: Int
    let today_plays: Int
    let week_plays: Int
    let month_plays: Int
    let bandwidth_today: Int64?
    let bandwidth_week: Int64?
    let bandwidth_month: Int64?
    
    var formattedTotalSize: String {
        formatBytes(total_size ?? 0)
    }
    
    var formattedTotalDuration: String {
        formatDuration(total_duration)
    }
    
    var activeRate: Double {
        total_users > 0 ? Double(active_users) / Double(total_users) : 0
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var size = Double(bytes)
        var unitIndex = 0
        while size > 1024 && unitIndex < units.count - 1 {
            size /= 1024
            unitIndex += 1
        }
        return String(format: "%.1f %@", size, units[unitIndex])
    }
    
    private func formatDuration(_ seconds: Int64) -> String {
        let hours = seconds / 3600
        let days = hours / 24
        if days > 0 {
            return "\(days)天"
        } else if hours > 0 {
            return "\(hours)小时"
        } else {
            let minutes = seconds / 60
            return "\(minutes)分钟"
        }
    }
}

// 时间趋势数据
struct TimeTrend: Codable, Identifiable {
    let id = UUID()
    let time: String
    let plays: Int
    let users: Int
    let duration: Int64
    let bandwidth: Int64?
    
    enum CodingKeys: String, CodingKey {
        case time, plays, users, duration, bandwidth
    }
}

// 实时在线用户
struct OnlineUser: Codable, Identifiable {
    let id: String
    let name: String
    let device: String?
    let ip_address: String?
    let current_playing: String?
    let play_start: String?
    let duration: Int?
    let playback_progress: Double?
    let quality: String?
    let transcoding: Bool?
    
    var progressPercentage: Double {
        min(100.0, (playback_progress ?? 0) * 100)
    }
}

// 在线用户响应
struct OnlineUsersResponse: Codable {
    let total: Int
    let users: [OnlineUser]
}

// 播放活动
struct PlayActivity: Codable, Identifiable {
    let id = UUID()
    let user_id: String
    let user_name: String
    let item_name: String
    let item_type: String
    let item_year: Int?
    let started_at: String
    let ended_at: String?
    let duration: Int
    let completion: Double?
    let device: String?
    let quality: String?
    let transcoding: Bool?
    
    var isPlaying: Bool {
        ended_at == nil
    }
    
    var formattedDuration: String {
        let hours = duration / 3600
        let minutes = (duration % 3600) / 60
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }
    
    var progressPercentage: Double {
        min(100.0, (completion ?? 0) * 100)
    }
    
    enum CodingKeys: String, CodingKey {
        case user_id, user_name, item_name, item_type, item_year, started_at, ended_at, duration, completion, device, quality, transcoding
    }
}

// 播放活动响应
struct PlayActivitiesResponse: Codable {
    let activities: [PlayActivity]
    let total: Int
    let page: Int
    let page_size: Int
}