import Foundation

/// A parsed snapshot of one `container image pull --progress plain` line.
///
/// The CLI emits progress on stderr in a stable, line-oriented format:
///
///     [1/2] Fetching image 8% (19 of 56 blobs, 2,5/28,8 MB, 2,5 MB/s) [10s]
///     [2/2] Unpacking image for platform linux/amd64 0% [29s]
///
/// i.e. `[step/count] <action> [<percent>%] (<details>) [<elapsed>s]`. Byte and
/// speed figures are locale-formatted by the CLI (e.g. comma decimals), so they
/// are captured verbatim as strings rather than re-parsed into numbers.
struct PullProgress: Equatable, Sendable {
    enum Stage: Equatable, Sendable {
        case fetching
        case unpacking
        case other(String)
    }

    var stage: Stage
    var stepIndex: Int
    var stepCount: Int
    var percent: Int?
    var platform: String?
    var transferred: String?
    var total: String?
    var speed: String?
    var layersDone: Int?
    var layersTotal: Int?
    var elapsedSeconds: Int?

    init(
        stage: Stage,
        stepIndex: Int,
        stepCount: Int,
        percent: Int? = nil,
        platform: String? = nil,
        transferred: String? = nil,
        total: String? = nil,
        speed: String? = nil,
        layersDone: Int? = nil,
        layersTotal: Int? = nil,
        elapsedSeconds: Int? = nil
    ) {
        self.stage = stage
        self.stepIndex = stepIndex
        self.stepCount = stepCount
        self.percent = percent
        self.platform = platform
        self.transferred = transferred
        self.total = total
        self.speed = speed
        self.layersDone = layersDone
        self.layersTotal = layersTotal
        self.elapsedSeconds = elapsedSeconds
    }

    /// Overall completion in `0...1`, blending the finished steps with the
    /// in-step percentage so the bar advances smoothly across all phases.
    var overallFraction: Double {
        guard stepCount > 0 else { return 0 }
        let inStep = Double(percent ?? 0) / 100
        return (Double(max(0, stepIndex - 1)) + inStep) / Double(stepCount)
    }

    var title: String {
        switch stage {
        case .fetching: return "Fetching image"
        case .unpacking: return "Unpacking image"
        case .other(let name): return name
        }
    }

    var systemImage: String {
        switch stage {
        case .fetching: return "arrow.down.circle"
        case .unpacking: return "shippingbox"
        case .other: return "circle.dashed"
        }
    }

    /// A human-friendly secondary line: byte progress with speed when fetching,
    /// the platform when unpacking, otherwise a layer count.
    var subtitle: String? {
        if let transferred, let total {
            var text = "\(transferred) / \(total)"
            if let speed { text += " · \(speed)" }
            return text
        }
        if let platform { return platform }
        if let layersDone, let layersTotal { return "\(layersDone) of \(layersTotal) layers" }
        return nil
    }

    // MARK: - Parsing

    /// Parses a single CLI output line, or returns `nil` for lines that don't
    /// carry progress (so callers can ignore banners, blank lines, etc.).
    static func parse(line: String) -> PullProgress? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Every progress line starts with a "[step/count]" prefix.
        guard let head = capture(#"^\[(\d+)/(\d+)\]\s*(.*)$"#, in: trimmed),
              let stepIndex = Int(head[1]),
              let stepCount = Int(head[2])
        else { return nil }

        var rest = head[3]

        var elapsed: Int?
        if let match = capture(#"\[(\d+)s\]\s*$"#, in: rest), let value = Int(match[1]) {
            elapsed = value
            if let range = rest.range(of: #"\s*\[\d+s\]\s*$"#, options: .regularExpression) {
                rest.removeSubrange(range)
            }
        }

        let stage: Stage
        if rest.localizedCaseInsensitiveContains("Fetching") {
            stage = .fetching
        } else if rest.localizedCaseInsensitiveContains("Unpacking") {
            stage = .unpacking
        } else {
            let name = rest
                .replacingOccurrences(of: #"\s*\(.*\)\s*"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            stage = .other(name.isEmpty ? "Working" : name)
        }

        var progress = PullProgress(stage: stage, stepIndex: stepIndex, stepCount: stepCount, elapsedSeconds: elapsed)

        if let match = capture(#"(\d+)%"#, in: rest), let value = Int(match[1]) {
            progress.percent = min(100, max(0, value))
        }
        if let match = capture(#"for platform (\S+)"#, in: rest) {
            progress.platform = match[1]
        }
        if let match = capture(#"(\d+) of (\d+) blobs"#, in: rest) {
            progress.layersDone = Int(match[1])
            progress.layersTotal = Int(match[2])
        }
        // "<transferred>/<total>" where total ends in a byte unit. The leading
        // digit-before-slash requirement keeps this from matching speed ("/s")
        // or platform paths ("linux/amd64").
        if let match = capture(#"([\d.,]+(?:\s?[KMGTP]?i?B)?)/([\d.,]+\s?[KMGTP]?i?B)"#, in: rest) {
            progress.transferred = match[1].trimmingCharacters(in: .whitespaces)
            progress.total = match[2].trimmingCharacters(in: .whitespaces)
        }
        if let match = capture(#"([\d.,]+\s?[KMGTP]?i?B/s)"#, in: rest) {
            progress.speed = match[1].trimmingCharacters(in: .whitespaces)
        }

        return progress
    }

    /// Returns the capture groups (index 0 is the whole match) of the first
    /// match of `pattern` in `string`, or `nil` if there is no match.
    private static func capture(_ pattern: String, in string: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(string.startIndex..., in: string)
        guard let match = regex.firstMatch(in: string, range: range) else { return nil }
        return (0..<match.numberOfRanges).map { index in
            guard let r = Range(match.range(at: index), in: string) else { return "" }
            return String(string[r])
        }
    }
}
