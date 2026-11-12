import Foundation

struct Snippet: Identifiable, Hashable {
    let id: Int64          // Z_PK dans la base Core Data
    var shortcut: String
    var phrase: String
    var modified: Date?
}
