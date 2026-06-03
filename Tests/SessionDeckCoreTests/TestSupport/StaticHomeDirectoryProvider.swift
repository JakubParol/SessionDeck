import Foundation
import SessionDeckCore

struct StaticHomeDirectoryProvider: HomeDirectoryProviding {
    let homeDirectoryURL: URL

    func homeDirectory() -> URL {
        homeDirectoryURL
    }
}
