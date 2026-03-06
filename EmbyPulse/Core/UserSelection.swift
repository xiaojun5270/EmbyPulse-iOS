import Foundation

struct UserSelectionOption: Identifiable, Hashable {
    let id: String
    let name: String

    static let all = UserSelectionOption(id: "all", name: "全部用户")
}
