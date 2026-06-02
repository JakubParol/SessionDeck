import SessionDeckCore

struct FakeSourceDiscoveryPort: SourceDiscoveryPort {
    let sources: [SessionSourceSummary]

    init(sources: [SessionSourceSummary]) {
        self.sources = sources
    }

    func discoverSources() throws -> [SessionSourceSummary] {
        sources
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
