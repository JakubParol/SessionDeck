import Foundation
import Testing
@testable import SessionDeckCore

@Test("catalog result state fixture catalog covers empty no-match warning failure and mixed cases")
func catalogResultStateFixtureCatalogCoversRequiredCases() {
    let emptySummary = AppShellCatalogSummary.make(
        snapshot: CatalogResultStateFixtureCatalog.emptySnapshot
    )
    let noMatchSummary = AppShellCatalogSummary.make(
        snapshot: CatalogResultStateFixtureCatalog.healthySnapshot,
        scope: .all,
        queryRequest: CatalogResultStateFixtureCatalog.noMatchQuery,
        isFiltered: true
    )
    let warningSummary = AppShellCatalogSummary.make(
        snapshot: CatalogResultStateFixtureCatalog.warningSnapshot
    )
    let failureSummary = AppShellCatalogSummary.make(
        snapshot: CatalogResultStateFixtureCatalog.failureSnapshot
    )
    let mixedSummary = AppShellCatalogSummary.make(
        snapshot: CatalogResultStateFixtureCatalog.mixedSnapshot
    )

    #expect(emptySummary.resultState == .empty)
    #expect(noMatchSummary.resultState == .noMatches)
    #expect(warningSummary.resultState == .warning)
    #expect(failureSummary.resultState == .failure)
    #expect(mixedSummary.resultState == .warning)
    #expect(mixedSummary.rows.map(\.id.rawValue) == ["healthy-mixed-session"])
    #expect(mixedSummary.sourceFailureCount == 1)
}
