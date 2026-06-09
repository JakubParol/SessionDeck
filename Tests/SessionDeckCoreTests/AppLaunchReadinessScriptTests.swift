import Foundation
import Testing

@Test("run app script waits for automation-readable main window readiness")
func runAppScriptWaitsForMainWindowReadiness() throws {
    let root = repositoryRoot()
    let runAppScript = try String(
        contentsOf: root.appending(path: "scripts/run-app.sh"),
        encoding: .utf8
    )
    let readinessScript = try String(
        contentsOf: root.appending(path: "scripts/wait-for-main-window.sh"),
        encoding: .utf8
    )

    #expect(runAppScript.contains("wait-for-main-window.sh"))
    #expect(runAppScript.contains("SESSIONDECK_SKIP_WINDOW_READINESS"))
    #expect(readinessScript.contains("wait_for_main_window"))
    #expect(readinessScript.contains("System Events"))
    #expect(readinessScript.contains("readiness_output"))
    #expect(readinessScript.contains("readiness_output=\"not-ready\""))
    #expect(readinessScript.contains("== \"ready\""))
    #expect(readinessScript.contains("SESSIONDECK_WINDOW_READINESS_TIMEOUT_SECONDS"))
}

private func repositoryRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
