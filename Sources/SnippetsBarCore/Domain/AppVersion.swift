import Foundation

/// Numeric version such as “1.2.0” (a leading “v” is accepted, as in git tags).
public struct AppVersion: Comparable, CustomStringConvertible {
    public let components: [Int]

    /// nil for anything that is not dot-separated numbers, e.g. “0.0.0-dev”.
    public init?(_ string: String) {
        let numbers = string.hasPrefix("v") ? string.dropFirst() : Substring(string)
        let parts = numbers.split(separator: ".", omittingEmptySubsequences: false)
        guard !parts.isEmpty, parts.count <= 4 else { return nil }
        var components: [Int] = []
        for part in parts {
            guard let number = Int(part), number >= 0 else { return nil }
            components.append(number)
        }
        self.components = components
    }

    public var description: String {
        components.map(String.init).joined(separator: ".")
    }

    /// Missing components count as 0: 1.2 == 1.2.0.
    private static func padded(_ a: AppVersion, _ b: AppVersion) -> ([Int], [Int]) {
        let count = max(a.components.count, b.components.count)
        func pad(_ v: AppVersion) -> [Int] { v.components + Array(repeating: 0, count: count - v.components.count) }
        return (pad(a), pad(b))
    }

    public static func == (a: AppVersion, b: AppVersion) -> Bool {
        let (x, y) = padded(a, b)
        return x == y
    }

    public static func < (a: AppVersion, b: AppVersion) -> Bool {
        let (x, y) = padded(a, b)
        return x.lexicographicallyPrecedes(y)
    }
}
