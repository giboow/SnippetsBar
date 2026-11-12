import Foundation

public struct CommandResult: Equatable {
    public let status: Int32
    public let output: String
    public let errorOutput: String
    public let timedOut: Bool

    public init(status: Int32, output: String, errorOutput: String, timedOut: Bool = false) {
        self.status = status
        self.output = output
        self.errorOutput = errorOutput
        self.timedOut = timedOut
    }

    public var succeeded: Bool { status == 0 && !timedOut }

    /// Message court pour un toast.
    public var failureSummary: String {
        if timedOut { return "Délai dépassé" }
        let firstLine = errorOutput.split(separator: "\n").first.map(String.init) ?? ""
        return firstLine.isEmpty ? "Échec (code \(status))" : "Échec (code \(status)) : \(firstLine)"
    }
}

/// Exécute une commande avec zsh en shell de connexion, pour retrouver le PATH
/// de l'utilisateur (Homebrew…) qu'une app lancée depuis le Finder n'a pas.
public enum ShellCommandRunner {
    public static let defaultTimeout: TimeInterval = 5

    public static func run(_ command: String, timeout: TimeInterval = defaultTimeout,
                           shell: String = "/bin/zsh") async -> CommandResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: runSync(command, timeout: timeout, shell: shell))
            }
        }
    }

    static func runSync(_ command: String, timeout: TimeInterval, shell: String) -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shell)
        process.arguments = ["-l", "-c", command]
        process.standardInput = FileHandle.nullDevice
        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError = err

        do {
            try process.run()
        } catch {
            return CommandResult(status: -1, output: "", errorOutput: error.localizedDescription)
        }

        // Lecture en parallèle des deux flux : évite le blocage quand un tampon de pipe est plein.
        let outBuffer = Buffer(), errBuffer = Buffer()
        let group = DispatchGroup()
        for (pipe, buffer) in [(out, outBuffer), (err, errBuffer)] {
            group.enter()
            DispatchQueue.global().async {
                buffer.set(pipe.fileHandleForReading.readDataToEndOfFile())
                group.leave()
            }
        }

        var timedOut = false
        if group.wait(timeout: .now() + timeout) == .timedOut {
            timedOut = true
            process.terminate()
            // Un processus enfant peut garder le pipe ouvert : on n'attend pas indéfiniment.
            _ = group.wait(timeout: .now() + 1)
        }
        if !timedOut { process.waitUntilExit() }

        return CommandResult(
            status: timedOut ? -1 : process.terminationStatus,
            output: trimmingTrailingNewlines(outBuffer.string),
            errorOutput: trimmingTrailingNewlines(errBuffer.string),
            timedOut: timedOut
        )
    }

    private static func trimmingTrailingNewlines(_ s: String) -> String {
        var s = s
        while s.last?.isNewline == true { s.removeLast() }
        return s
    }

    private final class Buffer {
        private let lock = NSLock()
        private var data = Data()

        func set(_ data: Data) { lock.lock(); self.data = data; lock.unlock() }
        var string: String { lock.lock(); defer { lock.unlock() }; return String(decoding: data, as: UTF8.self) }
    }
}
