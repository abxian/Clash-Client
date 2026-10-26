@preconcurrency import Clash
import Foundation
import ShenxianyunKit
import os.log

/// Network Extension 进程内的遥测上报器。
///
/// **为什么在 Extension 里而不是 App 里**：iOS 的 App 进程随时会被挂起甚至终止，
/// 而隧道由系统按需拉起、可以长时间独立运行。心跳要反映的是「隧道在不在」，
/// 不是「用户有没有打开 App」，所以只能在这里发。
///
/// 设备凭据从 **App Group** 读——这也是 `ShenxianyunKit` 的存储必须用 App Group
/// 而不是 `UserDefaults.standard` 的原因。
///
/// 节奏沿用族内 2026-08-16 定案：300 秒基础间隔 + 60 秒抖动、单飞、
/// Retry-After / 指数退避、隧道停止时清理在途标记。这些逻辑全在
/// `TelemetryScheduler` 里，本类只负责「什么时候问它」和「拿数据发出去」。
actor ShenxianyunTelemetryReporter {
    static let shared = ShenxianyunTelemetryReporter()

    /// 轮询粒度。真正的上报间隔由 scheduler 决定（300s+抖动），
    /// 这里只是「多久去问一次现在该不该发」。取小值是为了让隧道刚起来时
    /// 第一次心跳能及时发出，而不是等满一个周期。
    /// 用 nanoseconds 版而不是 `Task.sleep(for:)`——部署目标是 iOS 15，
    /// `Duration` 要 iOS 16。
    private static let tickIntervalNanos: UInt64 = 30 * 1_000_000_000

    private let log = Logger(
        subsystem: ShenxianyunProfile.bundleBase, category: "telemetry")
    private let client: ShenxianyunClient
    private var scheduler = TelemetryScheduler()
    private var counter = TrafficCounter()
    private var usage = ScopedTunnelTrafficAccumulator(upload: 0, download: 0, scope: .init(isCurrent: false, epoch: 0))
    private var loop: Task<Void, Never>?
    private var generation = UUID()
    private var stopDenied: (@Sendable () -> Void)?
    private var scope: (@Sendable () -> TelemetryScope)?
    private var credentialToken: String?


    private init() {
        // App Group 拿不到就退回内存存储——那样读不到设备凭据，
        // 后面每次上报都会拿到 .notActivated 并被静默跳过，不会反复打网络。
        let store: ShenxianyunStore =
            AppGroupStore(suiteName: ShenxianyunProfile.appGroup) ?? InMemoryStore()
        client = ShenxianyunClient(store: store)
    }

    // MARK: - 生命周期

    /// 隧道起来了。每次都换一个新的 counterID：后端靠
    /// counter_id + sequence 识别客户端重启导致的计数器归零，
    /// 沿用旧 ID 会让它把重启当成流量暴涨。
    func tunnelDidStart(scope: @escaping @Sendable () -> TelemetryScope,
                        stopDenied: @escaping @Sendable () -> Void) async {
        self.stopDenied = stopDenied
        scheduler = TelemetryScheduler()
        self.scope = scope
        generation = UUID()
        let currentGeneration = generation
        loop?.cancel()
        counter = TrafficCounter()
        let totals = Self.readTrafficTotals()
        usage = ScopedTunnelTrafficAccumulator(upload: totals?.up ?? 0, download: totals?.down ?? 0, scope: scope())
        let activationToken = await client.savedActivation()?.deviceToken
        guard generation == currentGeneration else { return }
        credentialToken = activationToken
        loop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.tickIfDue(generation: currentGeneration)
                try? await Task.sleep(nanoseconds: Self.tickIntervalNanos)
            }
        }
    }

    /// 隧道要停了。先取消循环，再补一次下线通知让后台的在线数及时回落。
    /// 下线失败不重试——隧道都停了，没有下一次机会，硬等只会拖慢 stopTunnel。
    func tunnelWillStop() async {
        generation = UUID()
        loop?.cancel()
        loop = nil
        await scheduler.cancelInFlight()
        guard let currentScope = scope?(), currentScope.isCurrent, let token = credentialToken else { return }
        scope = nil
        credentialToken = nil
        // Best effort final cumulative snapshot; each shutdown request is bounded to two seconds.
        if let totals = Self.readTrafficTotals() {
            usage.observe(upload: totals.up, download: totals.down, scope: currentScope)
            counter.advance(uploadTotal: usage.upload, downloadTotal: usage.download)
            try? await client.reportTraffic(counter, final: true, expectedDeviceToken: token)
        }
        do {
            try await client.reportOffline(expectedDeviceToken: token)
        } catch {
            log.debug("offline report unavailable")
        }
    }

    // MARK: - 一次上报

    private func tickIfDue(generation expected: UUID) async {
        guard generation == expected, let startedScope = scope?(), startedScope.isCurrent,
              let token = credentialToken else { return }
        guard await client.canReportTelemetry else { return }
        let scheduler = self.scheduler
        guard await scheduler.beginIfDue() else { return }

        do {
            try await client.heartbeat(expectedDeviceToken: token)
            guard generation == expected, !Task.isCancelled, scope?().isCurrent == true else {
                await scheduler.cancelInFlight()
                return
            }
            if let totals = Self.readTrafficTotals(), let currentScope = scope?(), currentScope.isCurrent {
                usage.observe(upload: totals.up, download: totals.down, scope: currentScope)
                counter.advance(uploadTotal: usage.upload, downloadTotal: usage.download)
                try await client.reportTraffic(counter, expectedDeviceToken: token)
            }
            await scheduler.finishSuccess()
        } catch is CancellationError {
            await scheduler.cancelInFlight()
        } catch let error as ShenxianyunError {
            guard generation == expected, !Task.isCancelled, scope?() == startedScope else {
                await scheduler.cancelInFlight()
                return
            }
            if case let .server(server) = error, [401, 403].contains(server.statusCode) {
                UserDefaults(suiteName: ShenxianyunProfile.appGroup)?.set(
                    "提取码或设备授权已失效、受限，请重新导入或检查额度", forKey: "shenxianyun.connection_error")
                stopDenied?()
                return
            }
            // 后端明确给了 Retry-After 就听它的，否则走指数退避。
            if case let .rateLimited(retryAfter) = error {
                await scheduler.finishFailure(retryAfter: retryAfter)
            } else {
                await scheduler.finishFailure()
            }
            log.debug("telemetry unavailable; retry scheduled")
        } catch {
            if Task.isCancelled { await scheduler.cancelInFlight(); return }
            await scheduler.finishFailure()
        }
    }

    /// 从内核读累计流量。解析放在 ShenxianyunKit 里，好被单测覆盖。
    private static func readTrafficTotals() -> (up: Int64, down: Int64)? {
        TrafficCounter.parseTotals(fromTrafficJSON: ClashTrafficJSON())
    }
}
