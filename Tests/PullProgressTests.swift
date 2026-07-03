import Foundation
import Testing

@Suite("PullProgress")
struct PullProgressTests {
    @Test func parsesFetchingWithBytesAndSpeed() throws {
        let p = try #require(PullProgress.parse(line: "[1/2] Fetching image 0% (17 of 56 blobs, 25 KB/28,8 MB, 2 KB/s) [9s]"))
        #expect(p.stage == .fetching)
        #expect(p.stepIndex == 1)
        #expect(p.stepCount == 2)
        #expect(p.percent == 0)
        #expect(p.layersDone == 17)
        #expect(p.layersTotal == 56)
        #expect(p.transferred == "25 KB")
        #expect(p.total == "28,8 MB")
        #expect(p.speed == "2 KB/s")
        #expect(p.elapsedSeconds == 9)
        #expect(p.subtitle == "25 KB / 28,8 MB · 2 KB/s")
    }

    @Test func parsesLocaleDecimalTransferred() throws {
        let p = try #require(PullProgress.parse(line: "[1/2] Fetching image 8% (19 of 56 blobs, 2,5/28,8 MB, 2,5 MB/s) [10s]"))
        #expect(p.percent == 8)
        #expect(p.transferred == "2,5")
        #expect(p.total == "28,8 MB")
        #expect(p.speed == "2,5 MB/s")
    }

    @Test func parsesFetchingBlobsOnlyWithoutPercent() throws {
        let p = try #require(PullProgress.parse(line: "[1/2] Fetching image (1 of 17 blobs) [3s]"))
        #expect(p.stage == .fetching)
        #expect(p.percent == nil)
        #expect(p.layersDone == 1)
        #expect(p.layersTotal == 17)
        #expect(p.transferred == nil)
        #expect(p.subtitle == "1 of 17 layers")
    }

    @Test func parsesBarePhaseLine() throws {
        let p = try #require(PullProgress.parse(line: "[1/2] Fetching image [0s]"))
        #expect(p.stage == .fetching)
        #expect(p.percent == nil)
        #expect(p.subtitle == nil)
        #expect(p.elapsedSeconds == 0)
        #expect(p.overallFraction == 0)
    }

    @Test func parsesUnpackingPlatform() throws {
        let p = try #require(PullProgress.parse(line: "[2/2] Unpacking image for platform linux/amd64 0% [29s]"))
        #expect(p.stage == .unpacking)
        #expect(p.stepIndex == 2)
        #expect(p.percent == 0)
        #expect(p.platform == "linux/amd64")
        #expect(p.subtitle == "linux/amd64")
    }

    @Test func parsesUnpackingComplete() throws {
        let p = try #require(PullProgress.parse(line: "[2/2] Unpacking image for platform linux/s390x 100% (514 entries, 8,1 MB) [34s]"))
        #expect(p.percent == 100)
        #expect(p.platform == "linux/s390x")
        // "514 entries, 8,1 MB" has no "X/Y" byte pair, so no transfer figures.
        #expect(p.transferred == nil)
    }

    @Test func overallFractionBlendsStepWithPercent() {
        let fetchingHalf = PullProgress(stage: .fetching, stepIndex: 1, stepCount: 2, percent: 50)
        #expect(fetchingHalf.overallFraction == 0.25)

        let unpackingHalf = PullProgress(stage: .unpacking, stepIndex: 2, stepCount: 2, percent: 50)
        #expect(unpackingHalf.overallFraction == 0.75)

        let done = PullProgress(stage: .unpacking, stepIndex: 2, stepCount: 2, percent: 100)
        #expect(done.overallFraction == 1.0)
    }

    @Test func ignoresNonProgressLines() {
        #expect(PullProgress.parse(line: "") == nil)
        #expect(PullProgress.parse(line: "Done") == nil)
        #expect(PullProgress.parse(line: "some unrelated banner text") == nil)
    }

    @Test func doesNotMistakePlatformPathForBytes() throws {
        let p = try #require(PullProgress.parse(line: "[2/2] Unpacking image for platform linux/arm64/v8 0% [31s]"))
        #expect(p.platform == "linux/arm64/v8")
        #expect(p.transferred == nil)
        #expect(p.total == nil)
    }
}
