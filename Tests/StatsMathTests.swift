import Foundation
import Testing

/// Verifies CPU% derivation from cumulative usec counters and segment
/// splitting around gaps/resets.
@Suite("Stats math")
struct StatsMathTests {
    private func sample(at seconds: TimeInterval, cpu: UInt64?) -> StatsSample {
        StatsSample(
            timestamp: Date(timeIntervalSinceReferenceDate: seconds),
            cpuUsageUsec: cpu,
            memoryUsageBytes: nil,
            memoryLimitBytes: nil
        )
    }

    @Test func normalDelta() {
        // 1.5s of CPU time over 3s of wall clock = 50% of one core.
        let prev = sample(at: 0, cpu: 0)
        let curr = sample(at: 3, cpu: 1_500_000)
        #expect(StatsMath.cpuPercent(prev: prev, curr: curr) == 50)
    }

    @Test func multiCoreExceedsHundredPercent() {
        // 6s of CPU time over 3s of wall clock = 200% (two busy cores), uncapped.
        let prev = sample(at: 0, cpu: 0)
        let curr = sample(at: 3, cpu: 6_000_000)
        #expect(StatsMath.cpuPercent(prev: prev, curr: curr) == 200)
    }

    @Test func variableElapsedUsesMeasuredWallClock() {
        // Same delta over 5s instead of 3s reads lower — cadence is not assumed.
        let prev = sample(at: 0, cpu: 0)
        let curr = sample(at: 5, cpu: 1_500_000)
        #expect(StatsMath.cpuPercent(prev: prev, curr: curr) == 30)
    }

    @Test func counterResetReturnsNil() {
        // Restart resets the cumulative counter; no false spike.
        let prev = sample(at: 0, cpu: 9_000_000)
        let curr = sample(at: 3, cpu: 1_000)
        #expect(StatsMath.cpuPercent(prev: prev, curr: curr) == nil)
    }

    @Test func missingCountersReturnNil() {
        #expect(StatsMath.cpuPercent(prev: sample(at: 0, cpu: nil), curr: sample(at: 3, cpu: 5)) == nil)
        #expect(StatsMath.cpuPercent(prev: sample(at: 0, cpu: 5), curr: sample(at: 3, cpu: nil)) == nil)
    }

    @Test func nonPositiveElapsedReturnsNil() {
        let prev = sample(at: 3, cpu: 0)
        #expect(StatsMath.cpuPercent(prev: prev, curr: sample(at: 3, cpu: 1_000)) == nil)
        #expect(StatsMath.cpuPercent(prev: prev, curr: sample(at: 1, cpu: 1_000)) == nil)
    }

    @Test func overlongGapReturnsNil() {
        // Wake-from-sleep: a multi-minute delta would be a misleading average.
        let prev = sample(at: 0, cpu: 0)
        let curr = sample(at: 60, cpu: 1_500_000)
        #expect(StatsMath.cpuPercent(prev: prev, curr: curr, maxGap: 12) == nil)
        #expect(StatsMath.cpuPercent(prev: prev, curr: curr, maxGap: 120) != nil)
    }

    @Test func segmentsSplitAroundGaps() {
        func point(_ seconds: TimeInterval, _ cpu: Double?) -> StatsPoint {
            StatsPoint(
                timestamp: Date(timeIntervalSinceReferenceDate: seconds),
                cpuPercent: cpu,
                memoryBytes: nil,
                memoryFraction: nil
            )
        }
        // Leading, interior, and trailing nils all break/trim segments.
        let points = [point(0, nil), point(3, 10), point(6, 20), point(9, nil), point(12, 30), point(15, nil)]
        let segments = StatsMath.segments(points)
        #expect(segments.count == 2)
        #expect(segments[0].map(\.cpuPercent) == [10, 20])
        #expect(segments[1].map(\.cpuPercent) == [30])
        #expect(StatsMath.segments([]).isEmpty)
        #expect(StatsMath.segments([point(0, nil)]).isEmpty)
    }

    @MainActor
    @Test func historyIngestTrimsAndClears() {
        let history = StatsHistory(retention: 120, maxGap: 12)
        let t0 = Date(timeIntervalSinceReferenceDate: 1000)
        let stat = ContainerStats(id: "web", memoryUsageBytes: 10, memoryLimitBytes: 100, cpuUsageUsec: 0)

        history.ingest([stat], runningIDs: ["web"], now: t0)
        #expect(history.points(for: "web").count == 1)
        #expect(history.latest(for: "web")?.cpuPercent == nil)  // first sample: no delta yet

        let stat2 = ContainerStats(id: "web", memoryUsageBytes: 20, memoryLimitBytes: 100, cpuUsageUsec: 3_000_000)
        history.ingest([stat2], runningIDs: ["web"], now: t0.addingTimeInterval(3))
        #expect(history.latest(for: "web")?.cpuPercent == 100)
        #expect(history.points(for: "web").count == 2)

        // Container no longer running → series dropped.
        history.ingest([], runningIDs: [], now: t0.addingTimeInterval(6))
        #expect(history.points(for: "web").isEmpty)
    }
}
