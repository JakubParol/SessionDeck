import SessionDeckCore
import Foundation

struct FakeSourceDiscoveryPort: SourceDiscoveryPort {
    let sources: [SessionSourceSummary]

    init(sources: [SessionSourceSummary]) {
        self.sources = sources
    }

    func discoverSources() throws -> [SessionSourceSummary] {
        sources
    }
}

struct FakeCandidateSessionFileEnumerationPort: CandidateSessionFileEnumerationPort {
    let files: [CandidateSessionFile]

    init(files: [CandidateSessionFile]) {
        self.files = files
    }

    func enumerateCandidateFiles(sourceID: SessionSourceID?) throws -> [CandidateSessionFile] {
        guard let sourceID else {
            return files
        }

        return files.filter { $0.sourceID == sourceID }
    }
}

struct FakeSessionCatalogPort: SessionCatalogPort {
    let sessions: [SessionSummary]

    init(sessions: [SessionSummary]) {
        self.sessions = sessions
    }

    func listSessions(sourceID: SessionSourceID?) throws -> [SessionSummary] {
        guard let sourceID else {
            return sessions
        }

        return sessions.filter { $0.sourceID == sourceID }
    }
}

struct FakeTranscriptLoadingPort: TranscriptLoadingPort {
    let previewsBySessionID: [SessionID: TranscriptPreview]

    init(previews: [TranscriptPreview]) {
        self.previewsBySessionID = Dictionary(uniqueKeysWithValues: previews.map { ($0.sessionID, $0) })
    }

    func loadTranscriptPreview(sessionID: SessionID) throws -> TranscriptPreview {
        guard let preview = previewsBySessionID[sessionID] else {
            throw FakeTranscriptLoadingError.previewNotFound(sessionID)
        }

        return preview
    }
}

enum FakeTranscriptLoadingError: Error, Equatable {
    case previewNotFound(SessionID)
}

struct FakeCatalogMetadataExtractionPort: CatalogMetadataExtractionPort {
    let resultsBySourceID: [SessionSourceID: CatalogSourceExtractionResult]
    let errorsBySourceID: [SessionSourceID: Error]

    init(
        resultsBySourceID: [SessionSourceID: CatalogSourceExtractionResult],
        errorsBySourceID: [SessionSourceID: Error] = [:]
    ) {
        self.resultsBySourceID = resultsBySourceID
        self.errorsBySourceID = errorsBySourceID
    }

    func extractSessions(source: SessionSourceSummary) throws -> CatalogSourceExtractionResult {
        if let error = errorsBySourceID[source.id] {
            throw error
        }

        return resultsBySourceID[source.id] ?? CatalogSourceExtractionResult(sourceID: source.id, sessions: [])
    }
}

struct FixedCatalogRefreshClock: CatalogRefreshClock {
    let nowDate: Date

    init(now: Date) {
        self.nowDate = now
    }

    func now() -> Date {
        nowDate
    }
}
