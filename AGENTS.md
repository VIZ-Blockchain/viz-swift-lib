# AGENTS.md

Guidance for AI coding agents (Claude Code, Codex, Cursor, Aider, etc.) working in this repository.

## Project

**viz-swift-lib** — a low-level Swift library for the VIZ blockchain (operations, transactions, signing, JSON-RPC). Modernized to Swift 5.5+, async/await, `actor Client`, `Sendable` throughout. Public README: [README.md](README.md).

## Layout

- `Sources/VIZ/` — public library. One file per concept (`Operation.swift`, `Transaction.swift`, `Asset.swift`, `Client.swift`, …).
- `Sources/Crypto/` — internal crypto primitives.
- `Tests/UnitTests/` — XCTest suite, no network. Fast (sub-second).
- `Tests/IntegrationTests/` — hits a live node (`https://node.viz.cx`). Flaky by nature.
- `Tests/UnitTests/XCTestManifests.swift` — Linux test discovery. Must be hand-edited when adding tests.

## Build & test

```bash
swift build
swift test --filter UnitTests          # always run this — fast, no network
swift test --filter IntegrationTests   # only when you know the node is up
swift test                             # both (may flake on integration)
```

Unit suite runs ~124 tests in under a second. If your changes push it over a second, that's worth investigating.

## Conventions

- **Async API surface uses `async`/`await` and `Sendable`.** Don't introduce completion-handler APIs.
- **`actor Client` owns network state.** Don't add shared mutable globals.
- **Public types conform to `VIZCodable` (binary) and `Codable` (JSON snake_case).** When adding a new operation or model type, add both sides plus tests.
- **No length prefix on raw `Data` in `VIZEncoder`** — it appends bytes verbatim. This is a load-bearing contract; tests pin it.
- **JSON uses snake_case** via `JSONEncoder.KeyEncodingStrategy.convertToSnakeCase` and a custom date format `yyyy-MM-dd'T'HH:mm:ss`.
- **Operations are dispatched manually** in `AnyOperation.init(from:)` and `AnyOperation.encode(to:)`. Adding a new operation requires editing both switches plus `OperationId`.

## Adding tests

1. Add test methods to the relevant file in `Tests/UnitTests/`.
2. Register them in `Tests/UnitTests/XCTestManifests.swift` (the `__allTests` array for the class **and** the `allTests()` list at the bottom — the latter is wrapped in `#if !os(macOS)`).
3. `swift test --generate-linuxmain` is **deprecated** in current toolchains — edit the manifest by hand.
4. Use the existing helpers in `Tests/UnitTests/Common.swift`: `AssertEncodes`, `AssertDecodes`, `TestDecode`. For new operation tests, use the `OperationFixture` + `roundTrip` helpers in `Tests/UnitTests/Operation.swift`.

## Known quirks (do not "fix" silently)

Each of these is intentional and pinned by a test. Don't change behavior without also updating the pin.

- `Operation.Convert` (and other Steem-legacy ops) has no `OperationId` case — encoding it throws by design; VIZ has no such operation. Kept only for source/decoding compatibility (`Sources/VIZ/Operation.swift`).
- `PublicKey.AddressPrefix.testNet` stringifies to `"VIZ"` like `.mainNet` — intentional (VIZ has no separate testnet prefix).

## Things to avoid

- **Don't restructure `Operation.swift`** (it's 1,294 LOC by design — one file is the convention here).
- **Don't add new abstractions or feature-flag shims for hypothetical needs.** This is a primitives library.
- **Don't change the public API signatures** without checking — downstream code on VIZ depends on shape stability.
- **Don't mock network in IntegrationTests** — they exist to catch real wire-format drift against a live node.

## Commit style

- Imperative mood, lowercase, no trailing period (`test: add asset edge-case coverage`).
- Prefixes used in this repo: `feat:`, `fix:`, `test:`, `chore:`, `refactor:`, `docs:`.
- **No `Co-Authored-By: Claude …` trailer** on commit messages.

## Planning & specs

Long-running design work lives under `docs/superpowers/`:

- `docs/superpowers/specs/` — design documents (one per feature).
- `docs/superpowers/plans/` — task-by-task implementation plans derived from specs.

If you're about to take on something non-trivial, look there first to see if it's already been planned.
