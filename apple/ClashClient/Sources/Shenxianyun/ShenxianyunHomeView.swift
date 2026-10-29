import ShenxianyunKit
import SwiftUI

/// AppShell 持有，页面切换不会重复消费启动刷新，也不会丢失断开刷新。
@MainActor
final class SXYHomeSession: ObservableObject {
    @Published var refreshGeneration = 0
    var refreshedGeneration: Int?
    private var wasConnected = false
    var isolatedImportAttempted = false
    @Published var restriction: AccessRestriction?
    var recoveryTask: Task<Bool, Never>?
    var nextCheck = Date.distantPast
    var retryNotBefore = Date.distantPast
    var failures = 0

    func observe(_ status: String) {
        if status == "connected" { wasConnected = true }
        else if status != "connecting" && status != "disconnecting" && wasConnected {
            wasConnected = false
            refreshGeneration += 1
        }
    }
}

/// 未连接时只展示提取码和启动；配置选项跟随实际隧道状态。
struct ShenxianyunHomeView: View {
    @ObservedObject var vpn: VPNController
    @ObservedObject var profiles: ProfilesViewModel
    @ObservedObject var command: ClashCommandClient
    @ObservedObject var nodes: NodesModel
    let client: ShenxianyunClient
    @ObservedObject var session: SXYHomeSession
    /// 进入上游那套完整界面（节点选择、设置都在里面）。
    let openUpstream: () -> Void
    let openNodes: () -> Void
    @AppStorage("shenxianyun.profile_id", store: UserDefaults(suiteName: ShenxianyunProfile.appGroup))
    private var installedProfileID = ""

    @Environment(\.scenePhase) private var scenePhase
    @State private var showsNodes = false
    @State private var showsImport = false
    @State private var isWorking = false
    @State private var isStarting = false
    @State private var inputCode = ""
    @State private var isEditingCode = false
    @State private var notice: String?
    @State private var accessCode: String?
    @State private var expiresAt: String?

    private var isConnected: Bool { vpn.status == "connected" }
    private var isTransitioning: Bool {
        vpn.status == "connecting" || vpn.status == "disconnecting"
    }

    private var statusText: String {
        switch vpn.status {
        case "connected": return "运行中"
        case "connecting": return "连接中"
        case "disconnecting": return "断开中"
        default: return "已停止"
        }
    }

    var body: some View {
        ZStack {
            SXYTheme.canvas
            compactLayout
        }
        .sheet(isPresented: $showsImport) {
            ShenxianyunImportView(client: client, onImported: handleImported)
                .shenxianyunLight()
        }
        .sheet(isPresented: $showsNodes) { ShenxianyunNodesView(nodes: nodes) }
        .task(id: session.refreshGeneration) { await loadState() }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await client.refreshEndpoints()
            _ = await checkRecovery(force: true)
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: 5_000_000_000) } catch { return }
                _ = await checkRecovery()
            }
        }
        .onChange(of: profiles.profiles.map(\.id)) { _ in
            Task { await refreshWhenReady() }
        }
        .onChange(of: profiles.busyProfileID) { value in
            if value == nil { Task { await refreshWhenReady() } }
        }
        .onChange(of: vpn.status) { _ in
            if !isConnected { showsNodes = false }
            if let failure = UserDefaults(suiteName: ShenxianyunProfile.appGroup)?
                .string(forKey: "shenxianyun.connection_error") { notice = failure }
        }
        .shenxianyunLight()
    }

    // MARK: - 两套布局

    /// iPhone、以及 iPad 上分屏/侧拉挤成 compact 宽度时。单列居中。
    private var compactLayout: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 18) {
                    brandColumn
                    if isConnected { controlColumn }
                }
                .padding(24)
                .frame(maxWidth: geometry.size.width > 700 ? 760 : 560)
                .frame(maxWidth: .infinity, minHeight: max(0, geometry.size.height - 32))
                .background(RoundedRectangle(cornerRadius: 32).fill(.ultraThinMaterial))
                .overlay(RoundedRectangle(cornerRadius: 32).stroke(.white.opacity(0.8)))
                .padding(16)
            }
        }
    }

    /// 左栏 / 上半：品牌、电源键、状态。
    private var brandColumn: some View {
        VStack(spacing: 0) {
            header
            if !isConnected {
                if accessCode != nil && !isEditingCode {
                    Button("切换提取码") { isEditingCode = true; inputCode = "" }
                        .disabled(isWorking || isStarting || isTransitioning)
                        .padding(.top, 24)
                } else {
                TextField(accessCode == nil ? "输入提取码" : "切换提取码", text: $inputCode)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .onSubmit(togglePower)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel(accessCode == nil ? "输入提取码" : "切换提取码")
                    .disabled(isWorking || isStarting || isTransitioning)
                    .padding(.horizontal, 28).padding(.top, 24)
                }
            }
            SXYPowerButton(
                isOn: isConnected,
                isBusy: isTransitioning || (!isConnected && (isWorking || isStarting)),
                action: togglePower)
                .padding(.top, 18)

            if isConnected { statusRow.padding(.top, 10) }
            if !isConnected, let restriction = session.restriction, restriction.renewable,
               ShenxianyunProfile.paymentEntryEnabled {
                Button("续费提取码", action: openPayment)
                    .buttonStyle(.bordered).padding(.top, 12)
            }
            if accessCode == nil {
                Text("连接时发送设备状态与累计流量，用于设备和套餐额度校验。")
                    .font(.caption).foregroundStyle(SXYTheme.textMuted)
                    .multilineTextAlignment(.center).padding(.top, 12)
            }

            if let notice {
                Text(notice)
                    .font(.system(size: 12))
                    .foregroundStyle(SXYTheme.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
            }
        }
    }

    /// 右栏 / 下半：模式切换与操作项。
    private var controlColumn: some View {
        VStack(spacing: 0) {
            SXYModePicker(
                mode: command.mode,
                isEnabled: command.isConnected,
                select: setMode)
            actions.padding(.top, 16)
            if isConnected {
                Text("上传 \(Foundation.ByteCountFormatter.string(fromByteCount: command.traffic.uploadTotal, countStyle: .binary)) · 下载 \(Foundation.ByteCountFormatter.string(fromByteCount: command.traffic.downloadTotal, countStyle: .binary))")
                    .font(.caption).foregroundStyle(SXYTheme.textMuted).padding(.top, 12)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - 分块

    private var header: some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(SXYTheme.powerFill)
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(.white))
                .padding(.bottom, 8)

            Text(ShenxianyunProfile.appName)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(SXYTheme.textSoft)
        }
        .padding(.top, 24)
    }

    private var statusRow: some View {
        HStack(spacing: 8) {
            Text(statusText)
                .foregroundStyle(isConnected ? SXYTheme.green : SXYTheme.textMuted)
            Text("·").foregroundStyle(SXYTheme.chevron)
            Text(accessCode == nil ? "未选择" : "提取码已绑定")
                .foregroundStyle(SXYTheme.textMuted)
            if let expiresAt, !expiresAt.isEmpty {
                Text("·").foregroundStyle(SXYTheme.chevron)
                Text("到期 \(expiresAt.prefix(10))")
                    .foregroundStyle(SXYTheme.textMuted)
            }
        }
        .font(.system(size: 12))
    }

    private var actions: some View {
        VStack(spacing: 10) {
            SXYActionRow(
                icon: "point.3.connected.trianglepath.dotted",
                title: "选择节点", trailing: .chevron, action: { showsNodes = true })

            SXYActionRow(
                icon: "key.fill",
                title: accessCode == nil ? "提取码订阅" : "切换提取码",
                subtitle: "输入或切换本机使用的提取码",
                trailing: .chevron) {
                    if isConnected || isTransitioning { notice = "请先断开连接，再切换提取码" }
                    else { showsImport = true }
                }

            SXYActionRow(
                icon: "arrow.clockwise",
                title: "更新节点",
                subtitle: "刷新当前提取码的节点信息",
                isBusy: isWorking, action: updateNodes)

            // 购买入口受 profile 开关控制。App Store 审核指南 3.1.3(f) 禁止
            // 「calls to action for purchase outside of the app」，跳转支付页正属此类，
            // 上架时必须关掉。用户从网站买好提取码后直接回来输入即可。
            if ShenxianyunProfile.paymentEntryEnabled {
                SXYActionRow(
                    icon: "creditcard.fill",
                    title: accessCode == nil ? "新购提取码" : "续费提取码",
                    subtitle: accessCode == nil ? "打开购买页面获取提取码" : "在官网延长当前提取码",
                    trailing: .external, action: openPayment)
            }

            SXYActionRow(
                icon: "gearshape.fill",
                title: "设置", trailing: .chevron, action: openUpstream)
        }
    }

    // MARK: - 动作

    private func loadState() async {
        // The upstream settings shell normally loads profiles on appearance; this
        // standalone home must load its own model before refresh or reconnect.
        profiles.load()
        accessCode = await client.savedAccessCode()
        expiresAt = await client.savedActivation()?.expiresAt
        session.restriction = await client.accessRestriction()
        if inputCode.isEmpty { inputCode = accessCode ?? "" }
        #if DEBUG
        // Reproducible headless Simulator QA; enabled only with the loopback guard active.
        if DevelopmentBootstrap.isolated {
            let environment = ProcessInfo.processInfo.environment
            if environment["SXY_TEST_PRESENT_IMPORT"] == "1" { showsImport = true }
            if let code = environment["SXY_TEST_IMPORT_CODE"], !session.isolatedImportAttempted {
                session.isolatedImportAttempted = true
                do {
                    let prepared = try await client.prepareImport(code)
                    try await handleImported(prepared, code)
                } catch {
                    notice = (error as? ShenxianyunError)?.userMessage
                        ?? (error as? LocalizedError)?.errorDescription ?? "隔离导入失败"
                }
            }
        }
        #endif
        await refreshWhenReady()
    }

    @MainActor
    private func refreshWhenReady() async {
        let savedCode = await client.savedAccessCode()
        let generation = session.refreshGeneration
        guard !Task.isCancelled, !isWorking, !isStarting,
              session.refreshedGeneration != generation,
              savedCode != nil else { return }
        guard profiles.busyProfileID == nil,
              profiles.profiles.contains(where: { $0.id == installedProfileID }) else { return }
        session.refreshedGeneration = generation
        _ = await checkRecovery(force: true)
    }

    private func togglePower() {
        // A background subscription save must never disable the user's stop.
        if isConnected {
            guard !isTransitioning else { return }
            Task { await vpn.stop() }
            return
        }
        guard !isWorking, !isStarting, !isTransitioning else { return }
        isStarting = true
        Task { @MainActor in
            defer { isStarting = false }
            notice = nil
            if let pending = session.recoveryTask { _ = await pending.value }
            if isConnected { await vpn.stop(); return }
            let code = inputCode.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !code.isEmpty else { notice = "请输入提取码"; return }
            do {
                if code != accessCode || !profiles.profiles.contains(where: { $0.id == installedProfileID }) {
                    let prepared = try await client.prepareImport(code)
                    try await handleImported(prepared, code)
                }
                guard let profile = profiles.profiles.first(where: { $0.id == installedProfileID }) else {
                    notice = "订阅配置不可用，请重新输入提取码"; return
                }
                guard await profiles.selectAndWait(profile),
                      await checkRecovery(force: true, starting: true) else { return }
                if !(await profiles.connectFromHome(profile)) {
                    notice = "连接未成功，请检查网络或系统 VPN 授权后重试"
                }
            } catch {
                notice = (error as? ShenxianyunError)?.userMessage
                    ?? (error as? LocalizedError)?.errorDescription ?? "启动失败，请重试"
            }
        }
    }

    @MainActor
    private func handleImported(_ outcome: ShenxianyunClient.ImportOutcome, _ code: String) async throws {
        if let pending = session.recoveryTask { _ = await pending.value }
        guard !isWorking, profiles.busyProfileID == nil else { throw SXYImportError.busy }
        isWorking = true
        defer { isWorking = false }
        // Never replace the device credential under a live tunnel/counter.
        guard !isConnected && !isTransitioning else { throw SXYImportError.stopFirst }
        let created = try await profiles.quickCreate(.link(outcome.subscriptionURL.absoluteString), preservingRouting: true)
        guard let profile = profiles.profiles.first(where: { $0.id == created.id }),
              await profiles.selectAndWait(profile), !Task.isCancelled else {
            throw SXYImportError.installFailed
        }
        await client.commitImport(outcome, code: code)
        installedProfileID = created.id
        accessCode = await client.savedAccessCode()
        inputCode = accessCode ?? ""
        isEditingCode = false
        session.refreshedGeneration = session.refreshGeneration
        switch outcome {
        case let .managed(activation): expiresAt = activation.expiresAt
        case let .plain(_, status): expiresAt = status.expireTime
        }
        UserDefaults(suiteName: ShenxianyunProfile.appGroup)?.removeObject(forKey: "shenxianyun.connection_error")
        session.restriction = nil
        session.retryNotBefore = .distantPast
        session.nextCheck = .distantPast
        notice = nil
    }

    private func updateNodes() {
        Task { @MainActor in _ = await checkRecovery(force: true) }
    }

    @MainActor
    private func checkRecovery(force: Bool = false, starting: Bool = false) async -> Bool {
        if let pending = session.recoveryTask { return await pending.value }
        guard !isWorking, (!isStarting || starting), profiles.busyProfileID == nil,
              accessCode != nil else { return false }
        guard Date() >= session.retryNotBefore else {
            if starting { notice = "服务器繁忙，请稍后再试" }
            return false
        }
        if !force && Date() < session.nextCheck { return session.restriction == nil }
        let profileID = installedProfileID
        session.nextCheck = Date().addingTimeInterval(30)
        let task = Task { @MainActor in
            defer { session.recoveryTask = nil }
            do {
                let snapshot = try await client.checkSubscriptionState()
                guard await client.isCurrent(snapshot), installedProfileID == profileID,
                      let profile = profiles.profiles.first(where: { $0.id == profileID }),
                      profiles.activeProfileID == profileID else { return false }
                if snapshot.needsRefresh || force {
                    // Keep the original managed source and UID; never exchange a
                    // new credential to bypass revocation or file migration.
                    let activeURL = await client.activeSubscriptionURL()
                    guard case let .url(source) = profile.source, URL(string: source) == activeURL else {
                        notice = "当前配置已手动更改，未覆盖本地订阅"; return false
                    }
                    isWorking = true
                    let outcome = await profiles.syncAwaitingLibrary(profile)
                    isWorking = false
                    guard await client.isCurrent(snapshot), installedProfileID == profileID else { return false }
                    guard let outcome else { notice = "更新尚未完成，已保留当前配置"; return false }
                    if case .failed = outcome { notice = "更新失败，已保留原配置，请稍后重试"; return false }
                }
                try await client.acknowledgeSubscriptionState(snapshot)
                session.restriction = nil
                expiresAt = snapshot.record.expiresAt
                session.failures = 0
                session.nextCheck = Date().addingTimeInterval(Double.random(in: 24...36))
                notice = nil
                UserDefaults(suiteName: ShenxianyunProfile.appGroup)?.removeObject(forKey: "shenxianyun.connection_error")
                return true
            } catch is CancellationError {
                return false
            } catch {
                session.restriction = await client.accessRestriction()
                session.failures = min(4, session.failures + 1)
                let delay = min(300.0, 30 * pow(2, Double(session.failures - 1)))
                session.nextCheck = Date().addingTimeInterval(delay)
                if let apiError = error as? ShenxianyunError, case let .rateLimited(seconds) = apiError {
                    session.retryNotBefore = Date().addingTimeInterval(min(3600, max(1, seconds)))
                    session.nextCheck = max(session.nextCheck, session.retryNotBefore)
                }
                if session.restriction != nil, isConnected, profiles.activeProfileID == profileID { await vpn.stop() }
                if starting || session.restriction != nil {
                    notice = (error as? ShenxianyunError)?.userMessage ?? "更新失败，已保留原配置"
                }
                return false
            }
        }
        session.recoveryTask = task
        return await task.value
    }

    /// 模式切换直接下到内核。失败时把原因显示出来——静默失败会让用户
    /// 以为切过去了，实际流量还走着旧模式。
    private func setMode(_ mode: String) {
        guard command.mode.lowercased() != mode else { return }
        Task {
            let ok = await command.setMode(mode)
            if !ok {
                notice = command.lastError.isEmpty
                    ? "模式切换失败，请稍后重试" : command.lastError
            } else {
                notice = nil
            }
        }
    }

    private func openPayment() {
        Task {
            let url = await (accessCode == nil
                ? client.purchaseURL() : client.renewURL())
            await UIApplication.shared.open(url)
        }
    }
}

private enum SXYImportError: LocalizedError {
    case busy, stopFirst, installFailed
    var errorDescription: String? {
        switch self {
        case .busy: return "当前配置操作尚未完成，请稍后重试"
        case .stopFirst: return "请先断开连接，再切换提取码"
        case .installFailed: return "订阅未能安装或设为当前配置，原提取码已保留"
        }
    }
}
