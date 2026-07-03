import Foundation
import Testing

/// Verifies the palette's subsequence gate and ranking tiers.
@Suite("Fuzzy matching")
struct FuzzyMatchTests {
    @Test func subsequenceGate() {
        #expect(FuzzyMatch.score("web", in: "web") != nil)
        #expect(FuzzyMatch.score("wbe", in: "web") == nil)
        #expect(FuzzyMatch.score("xyz", in: "web-frontend") == nil)
        #expect(FuzzyMatch.score("", in: "anything") == 0)
    }

    @Test func caseInsensitive() {
        #expect(FuzzyMatch.score("NGINX", in: "nginx:latest") != nil)
        #expect(FuzzyMatch.score("nginx", in: "NGINX:LATEST") != nil)
    }

    @Test func prefixBeatsScattered() {
        let prefix = FuzzyMatch.score("con", in: "containers")!
        let scattered = FuzzyMatch.score("con", in: "docker.io/nginx:current")!
        #expect(prefix > scattered)
    }

    @Test func contiguousBeatsScattered() {
        let contiguous = FuzzyMatch.score("net", in: "subnet")!
        let scattered = FuzzyMatch.score("net", in: "manifest")!
        #expect(contiguous > scattered)
    }

    @Test func wordBoundaryBonus() {
        // "dc" hitting d(elete)-c(ontainer) boundaries beats interior scatter.
        let boundary = FuzzyMatch.score("dc", in: "delete-container")!
        let interior = FuzzyMatch.score("dc", in: "produce")!
        #expect(boundary > interior)
    }

    @Test func multiWordQuery() {
        #expect(FuzzyMatch.score("strt cont", in: "start container") != nil)
        let full = FuzzyMatch.score("start container", in: "start container")!
        let abbreviated = FuzzyMatch.score("strt cont", in: "start container")!
        #expect(full > abbreviated)
    }

    @Test func camelCaseBoundary() {
        let camel = FuzzyMatch.score("pi", in: "pullImage")!
        let flat = FuzzyMatch.score("pi", in: "spinner")!
        #expect(camel > flat)
    }
}
