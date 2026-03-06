import Foundation

enum AppFormatting {
    static func durationText(seconds: Int) -> String {
        guard seconds > 0 else { return "0 分钟" }

        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours > 0 {
            return minutes > 0 ? "\(hours) 小时 \(minutes) 分钟" : "\(hours) 小时"
        }

        return "\(max(minutes, 1)) 分钟"
    }

    static func shortDate(_ source: String?) -> String {
        guard let source, let date = parseDate(source) else {
            return source ?? "-"
        }

        return shortDateFormatter.string(from: date)
    }

    static func shortDateTime(_ source: String?) -> String {
        guard let source, let date = parseDate(source) else {
            return source ?? "-"
        }

        return shortDateTimeFormatter.string(from: date)
    }

    private static func parseDate(_ source: String) -> Date? {
        for formatter in inputFormatters {
            if let date = formatter.date(from: source) {
                return date
            }
        }
        return ISO8601DateFormatter().date(from: source)
    }

    private static let inputFormatters: [DateFormatter] = {
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd"
        ]

        return formats.map {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.timeZone = .current
            formatter.dateFormat = $0
            return formatter
        }
    }()

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static let shortDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
