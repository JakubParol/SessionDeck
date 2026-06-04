import Foundation

public struct QueryCatalogUseCase: Sendable {
    private let sessionCatalog: any SessionCatalogPort

    public init(sessionCatalog: any SessionCatalogPort) {
        self.sessionCatalog = sessionCatalog
    }

    public func query(_ request: CatalogQueryRequest = CatalogQueryRequest()) throws -> [SessionSummary] {
        let candidates = try sessionCatalog.listSessions(sourceID: request.source?.sourceID ?? request.sourceID)

        return CatalogQueryEvaluation.query(sessions: candidates, request: request)
    }

    public func filterOptions() throws -> CatalogFilterOptions {
        CatalogQueryEvaluation.filterOptions(
            for: try sessionCatalog.listSessions(sourceID: nil)
        )
    }
}
