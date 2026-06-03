import Foundation

struct TempCodexSessionSource: Equatable {
    let label: String
    let profile: String
    let rootURL: URL
    let sessionsRootURL: URL
}

struct TempCodexSessionFile: Equatable {
    let source: TempCodexSessionSource
    let placement: TempCodexSessionPlacement
    let sessionID: String
    let timestamp: String
    let url: URL
}

enum TempCodexSessionPlacement: Equatable {
    case project(String)
    case nonProjectChat
    case missingMetadata
}

struct TempCodexSessionMetadata: Equatable {
    let sessionID: String
    let timestamp: String
    let title: String
    let project: String?
    let cwd: String?
    let source: String
    let omitProjectAndCwd: Bool
}

enum TempCodexSessionStoreError: Error, Equatable {
    case invalidPathComponent(String)
    case invalidSessionMetadata
    case invalidTimestamp(String)
    case pathEscapesTempRoot(String)
}
