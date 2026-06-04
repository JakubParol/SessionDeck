import Foundation

public enum SourceProfileNavigationPolicy {
    public static let unknownSourceStableID = "unknown-source"
    public static let unknownSourceDisplayName = "Unknown Source"
    public static let unknownProfileStableSegment = "unknown-profile"
    public static let unknownProfileDisplayName = "Unknown Profile"

    public static func sourceMetadata(
        for session: SessionSummary
    ) -> SourceProfileSourceNavigationMetadata {
        guard session.fallbackReasons.contains(.unknownSource) == false,
              session.sourceLabel.sourceID.trimmedForNavigation.isEmpty == false,
              session.sourceLabel.displayName.trimmedForNavigation.isEmpty == false else {
            return SourceProfileSourceNavigationMetadata(
                stableID: unknownSourceStableID,
                sourceID: nil,
                displayName: unknownSourceDisplayName,
                isFallback: true
            )
        }

        return SourceProfileSourceNavigationMetadata(
            stableID: "source.\(stableSegment(session.sourceID.rawValue))",
            sourceID: session.sourceID,
            displayName: session.sourceLabel.displayName.trimmedForNavigation,
            isFallback: false
        )
    }

    public static func profileMetadata(
        for session: SessionSummary
    ) -> SourceProfileProfileNavigationMetadata {
        let sourceMetadata = sourceMetadata(for: session)
        let profileDisplayName = profileDisplayName(for: session)
        let isFallback = profileDisplayName == nil
        let profileSegment = isFallback
            ? unknownProfileStableSegment
            : stableSegment(profileDisplayName ?? unknownProfileStableSegment)

        return SourceProfileProfileNavigationMetadata(
            stableID: "\(sourceMetadata.stableID).profile.\(profileSegment)",
            sourceID: sourceMetadata.sourceID,
            sourceStableID: sourceMetadata.stableID,
            displayName: profileDisplayName ?? unknownProfileDisplayName,
            isFallback: isFallback
        )
    }

    public static func session(
        _ session: SessionSummary,
        matches expectedSourceMetadata: SourceProfileSourceNavigationMetadata
    ) -> Bool {
        sourceMetadata(for: session).stableID == expectedSourceMetadata.stableID
    }

    public static func session(
        _ session: SessionSummary,
        matches profileMetadata: SourceProfileProfileNavigationMetadata
    ) -> Bool {
        self.profileMetadata(for: session).stableID == profileMetadata.stableID
    }

    private static func profileDisplayName(for session: SessionSummary) -> String? {
        if let profileName = session.sourceLabel.profileName?.trimmedForNavigation,
           profileName.isEmpty == false {
            return profileName
        }
        if let profileName = session.metadata.agentProfileName?.trimmedForNavigation,
           profileName.isEmpty == false {
            return profileName
        }

        return nil
    }

    private static func stableSegment(_ value: String) -> String {
        let trimmed = value.trimmedForNavigation.lowercased()
        let scalars = trimmed.unicodeScalars.map { scalar in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : "-"
        }
        let collapsed = String(scalars).split(separator: "-").joined(separator: "-")
        return collapsed.isEmpty ? "unknown" : collapsed
    }
}

private extension String {
    var trimmedForNavigation: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
