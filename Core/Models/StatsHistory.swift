import Foundation
import Observation

/// One raw stats sample, timestamped at ingest with the real wall clock.
/// The poll cadence is nominal (sleep + subprocess round-trip), so derived
/// rates must divide by measured elapsed time, never an assumed interval.
struct StatsSample: Sendable, Equatable {
    let timestamp: Date
    let cpuUsageUsec: UInt64?
    let memoryUsageBytes: UInt64?
    let memoryLimitBytes: UInt64?
}

/// A derived, chartable point. `cpuPercent == nil` marks a gap (first sample,
/// counter reset after restart, or a too-large interval) — used to break the
/// line into segments instead of interpolating across the gap.
struct StatsPoint: Identifiable, Equatable, Sendable {
    var id: Date { timestamp }
    let timestamp: Date
    let cpuPercent: Double?
    let memoryBytes: UInt64?
    let memoryFraction: Double?
}

/// Pure math for deriving chartable points from cumulative counters.
enum StatsMath {
    static let coreUsecPerSecond = 1_000_000.0

    /// CPU usage as a percent of a single core over `[prev, curr]` (like
    /// `docker stats`, so a busy 2-core container reads ~200%). `nil` when not
    /// derivable: missing counter, non-positive or over-`maxGap` elapsed, or a
    /// counter reset (`curr < prev`, i.e. the container restarted).
    static func cpuPercent(prev: StatsSample, curr: StatsSample, maxGap: TimeInterval = 12) -> Double? {
        guard let p = prev.cpuUsageUsec, let c = curr.cpuUsageUsec, c >= p else { return nil }
        let elapsed = curr.timestamp.timeIntervalSince(prev.timestamp)
        guard elapsed > 0, elapsed <= maxGap else { return nil }
        return (Double(c - p) / (elapsed * coreUsecPerSecond)) * 100
    }

    /// Splits contiguous runs of derivable points into segments so charts draw
    /// real breaks at gaps and resets.
    static func segments(_ points: [StatsPoint]) -> [[StatsPoint]] {
        var out: [[StatsPoint]] = []
        var current: [StatsPoint] = []
        for point in points {
            if point.cpuPercent == nil {
                if !current.isEmpty { out.append(current); current = [] }
            } else {
                current.append(point)
            }
        }
        if !current.isEmpty { out.append(current) }
        return out
    }
}

/// Rolling per-container time series fed by the stats poll; retains a short
/// trailing window for sparklines and the inspector chart.
@MainActor
@Observable
final class StatsHistory {
    let retention: TimeInterval
    let maxGap: TimeInterval

    private(set) var pointsByID: [String: [StatsPoint]] = [:]
    @ObservationIgnored private var lastSampleByID: [String: StatsSample] = [:]

    init(retention: TimeInterval = 120, maxGap: TimeInterval = 12) {
        self.retention = retention
        self.maxGap = maxGap
    }

    /// Appends one derived point per sampled container and drops series for
    /// containers that are no longer running.
    func ingest(_ stats: [ContainerStats], runningIDs: Set<String>, now: Date = Date()) {
        for id in pointsByID.keys where !runningIDs.contains(id) {
            pointsByID.removeValue(forKey: id)
            lastSampleByID.removeValue(forKey: id)
        }
        for stat in stats where runningIDs.contains(stat.id) {
            let sample = StatsSample(
                timestamp: now,
                cpuUsageUsec: stat.cpuUsageUsec,
                memoryUsageBytes: stat.memoryUsageBytes,
                memoryLimitBytes: stat.memoryLimitBytes
            )
            let cpu = lastSampleByID[stat.id].flatMap {
                StatsMath.cpuPercent(prev: $0, curr: sample, maxGap: maxGap)
            }
            let point = StatsPoint(
                timestamp: now,
                cpuPercent: cpu,
                memoryBytes: stat.memoryUsageBytes,
                memoryFraction: stat.memoryFraction
            )
            let cutoff = now.addingTimeInterval(-retention)
            pointsByID[stat.id] = (pointsByID[stat.id] ?? []).filter { $0.timestamp >= cutoff } + [point]
            lastSampleByID[stat.id] = sample
        }
    }

    func points(for id: String) -> [StatsPoint] { pointsByID[id] ?? [] }
    func latest(for id: String) -> StatsPoint? { pointsByID[id]?.last }
}
