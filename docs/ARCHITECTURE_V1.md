# Architecture V1

SessionDeck follows Clean Architecture so future catalog, transcript, and live-monitoring features can grow without coupling SwiftUI code to local Codex/Hermes stores.

## Dependency direction

```text
Presentation → Application → Domain
Infrastructure → Application / Domain
Composition Root → Application + Infrastructure
```

Rules:

- Domain remains pure Swift model/policy code. It must not import SwiftUI, AppKit, Foundation, persistence, file-system, OS, network, command execution, Presentation, or Infrastructure concerns.
- Application owns use cases, ports, and DTOs consumed by Presentation.
- Infrastructure implements Application-owned ports and owns concrete adapters for local stores, file systems, watchers, indexes, and decoders.
- Presentation renders Application DTOs/view models and does not construct Infrastructure adapters or perform direct file/process IO.
- The composition root is the only place that wires concrete adapters into Application use cases.

## Current SwiftPM layout

```text
Sources/
├── SessionDeckApp/
│   ├── SessionDeckApp.swift              # app entry point; calls the composition root
│   └── Presentation/
│       └── AppShellView.swift            # SwiftUI rendering of Application DTOs
└── SessionDeckCore/
    ├── Domain/
    │   └── LaunchSafetyPolicy.swift      # pure launch safety policy
    ├── Application/
    │   ├── AppShellLaunchConfiguration.swift
    │   ├── AppShellUseCase.swift
    │   ├── AppShellViewModel.swift
    │   └── LaunchConfigurationProviding.swift
    ├── Infrastructure/
    │   └── PlaceholderLaunchConfigurationProvider.swift
    └── CompositionRoot/
        └── SessionDeckCompositionRoot.swift
```

The initial placeholder launch behavior is intentionally minimal. `AppShellUseCase` builds the shell view model from the Application-owned `LaunchConfigurationProviding` port. `PlaceholderLaunchConfigurationProvider` is an Infrastructure adapter that returns zero configured session sources and a placeholder-safe policy. `SessionDeckCompositionRoot` wires that adapter into the use case for the app shell.

## Boundary verification

The test suite includes focused architecture checks in `Tests/SessionDeckCoreTests/ArchitectureBoundaryTests.swift`:

- Domain source files are scanned for banned framework and layer imports.
- Presentation source files are scanned to catch direct infrastructure construction and direct IO/process usage.
- Application behavior is tested with an injected fake launch configuration provider, proving the use case can run without real local stores.

Run the documented gate before committing architecture changes:

```bash
./scripts/quality-gate.sh
```
