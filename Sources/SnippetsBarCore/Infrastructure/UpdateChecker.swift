import Foundation

/// A published release of SnippetsBar.
public struct Release: Equatable {
    public let version: AppVersion
    public let url: URL

    public init(version: AppVersion, url: URL) {
        self.version = version
        self.url = url
    }
}

/// Asks GitHub for the latest published release. Only the request itself is sent.
public enum UpdateChecker {
    public static let latestReleaseURL = URL(string: "https://api.github.com/repos/giboow/SnippetsBar/releases/latest")!

    public static func latestRelease(session: URLSession = .shared) async throws -> Release {
        var request = URLRequest(url: latestReleaseURL, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("SnippetsBar", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try release(from: data)
    }

    static func release(from data: Data) throws -> Release {
        struct Payload: Decodable {
            let tag_name: String
            let html_url: URL
        }
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        guard let version = AppVersion(payload.tag_name) else { throw URLError(.cannotParseResponse) }
        return Release(version: version, url: payload.html_url)
    }
}
