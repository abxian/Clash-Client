# Apple baseline and basic-function audit · 2026-11-02 · Codex322

User requested latest projects first, then basic-function parity with Shenxianyun.
Fetched origin/upstream: Client e3e647283b1593a61dba622f13cd499deeda9b8b is already an ancestor; no missing upstream commits. Clash53658265 and Adapterd47c04a equal upstream. Retain all Shenxianyun development from0f27eb88; do not replace it with old origin/main3b8ea95. Current comparison sources PC55/1e157bef, Android55/a562d91e, Web2b3d591c.

## Changes

- APITransport retries transport/5xx within one total deadline, reserving time for other routes. Respect business denial/consumed ticket/429 and503 Retry-After. Fixed HTTPS ll.sxnn.de/v1/client/sxnn entry/state/presence fallback only; no arbitrary URL/tenant, custom/isolated endpoints excluded, cancel propagates. Relay traffic grants/queued delivery and managed subscription relay are **not implemented by this patch**.
- Home pauses/cancels old recovery when code input is open; resumes after closing, preserves original credential until configuration install succeeds. Manual node update now reports success/failure; background checks remain quiet on transient failures. It still uses state-first refresh, unlike PC's authenticated-download-first path.
- Native Clash branch adds ProxyTrafficJSON using Manager.TotalTraffic(true), excludes DIRECT/REJECT and retains closed-connection bytes; old TrafficJSON UI semantics unchanged. Tested mixed native totals. Client pins a7034e94062d649b344611f13bf16947f3818725, Adapter stays official09fbc0d7. Old SDK full inventory/provenance/vendor verified before archiving .build/sdk-archive/before-apple322-20261102; five slices rebuilt.
- Apple telemetry uses proxy totals; private AppGroup durable outbox freezes first packet sequence/timestamp, coalesces only later unsent cumulative snapshots, binds token hash, removes only committed success.202 not final ACK; retry and next-session delivery survive client recreation.64-record cap preserves old records and rejects new insertions rather than deleting usage. This is not the full PC/Android relay billing implementation.
- Xcode27.2 rejects XcodeGen2.46 duplicate navigator children. configure.py normalizes duplicate PBXGroup child references only; target build memberships unchanged. Current CoreSimulator1174.9.2 is older than Xcode's1174.21.0; no simulator service restart/update or user device changes performed. Device-target unsigned build is separate from simulator execution and signing.

## Validation and limits

Service suite65 discovered/63 passed/2 mode skips; isolated loopback and Release bootstrap separately pass. Native proxy binding tests pass. SDK five-slice verification passes. Exact App build status and source/CI submission recorded in ops/apple322-20261102 receipts, not assumed here. No signed IPA, App Store/NAS deployment, production-code requests, user App installation or VPN activation. No developer account available.

## Remaining parity

Real VPN/AppGroup signing, WiFi/cellular/background behavior, automatic node failover and payment need device verification. Cold-launch rule reset, setting local mode, independent DIRECT POST management transport, full subscription relay and traffic grant/finalACK protocol remain platform-specific work, not silently treated as synced. Existing two-column/automatic-first node layout and renewal/quota/file migration logic preserved. Native macOS/tvOS business integration remains task237 scope.

Editable: apple/ShenxianyunKit/Sources/ShenxianyunKit/{APITransport,Telemetry,Storage,ShenxianyunClient}.swift; apple/ClashClient/Sources/Shenxianyun/ShenxianyunHomeView.swift; Extension/ShenxianyunTelemetryReporter.swift; Dependencies.lock.json; scripts/configure.py; service tests and development workflow. Build with scripts/brand-apply.py then unsigned ClashiOS; new binary required. Rollback normal revert; restore old lock then preserve new SDK under a new archive before moving old three SDK/vendor/inventory paths back. Keep old Git/SDK milestones; no pruning or production DB restoration. Operational commands/logs and note/archive receipts: /Users/cgnay/Desktop/claude/rc/ops/apple322-20261102. Sources/validation dated2026-11-02; invalidate when source/SDK/toolchain changes.

Final local result: Xcode27.2/SDK27.2 Release generic iOS arm64 BUILD SUCCEEDED, main App plus 3 extensions identity/version/binarySHA recorded in verification.json. CODE_SIGNING_ALLOWED=NO; not installable signed IPA. Simulator execution remains unavailable; no device test claimed.
