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
    │   ├── LaunchConfigurationProviding.swift
    │   ├── SessionDeckApplicationComposition.swift
    │   ├── SourceDiscovery/              # source discovery port, DTOs, use case
    │   ├── SessionCatalog/               # session catalog port, DTOs, use case
    │   └── TranscriptLoading/            # transcript preview port, DTOs, use case
    ├── Infrastructure/
    │   ├── PlaceholderLaunchConfigurationProvider.swift
    │   ├── DefaultCodexSourceDiscoveryAdapter.swift
    │   ├── PlaceholderSessionCatalogAdapter.swift
    │   └── PlaceholderTranscriptLoadingAdapter.swift
    └── CompositionRoot/
        └── SessionDeckCompositionRoot.swift
```

The initial launch behavior is intentionally minimal. `SessionDeckCompositionRoot` is the startup composition boundary: it creates the default Codex source discovery adapter plus placeholder-safe catalog/transcript adapters, injects them into Application use cases, and returns `SessionDeckApplicationComposition` to the macOS app. `SessionDeckApp` passes the already-composed `AppShellViewModel` into SwiftUI instead of constructing adapters in Presentation.

`DefaultCodexSourceDiscoveryAdapter` performs bounded read-only detection of the default Codex sessions root at `~/.codex/sessions` through injected HOME and filesystem abstractions. It reports available, missing, or inaccessible source diagnostics and basic transcript/source bucket counts without decoding transcripts or mutating the source store. `PlaceholderLaunchConfigurationProvider`, `PlaceholderSessionCatalogAdapter`, and `PlaceholderTranscriptLoadingAdapter` remain placeholder-safe adapters. They do not call the network, execute commands, upload telemetry, or mutate sessions.

Future catalog and transcript slices start from Application-owned ports and DTOs: `SessionCatalogPort` and `TranscriptLoadingPort`. Infrastructure will implement those ports later; current tests use in-memory fakes and temp HOME/source fixtures so Application behavior stays independent of real Codex/Hermes HOME data and direct IO. Future real adapters should be introduced by changing `SessionDeckCompositionRoot` wiring, not by rewriting SwiftUI views.

## Boundary verification

The test suite includes focused architecture checks in `Tests/SessionDeckCoreTests/ArchitectureBoundaryTests.swift`:

- Domain source files are scanned for banned framework and layer imports.
- Presentation source files are scanned to catch direct infrastructure construction and direct IO/process usage.
- Concrete placeholder adapter construction is scanned to ensure wiring stays centralized in `SessionDeckCompositionRoot`.
- Application behavior is tested with injected fake and placeholder adapters, proving use cases can run without real local stores.

Run the documented gate before committing architecture changes:

```bash
./scripts/quality-gate.sh
```
