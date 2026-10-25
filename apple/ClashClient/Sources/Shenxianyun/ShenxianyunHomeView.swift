import ShenxianyunKit
import SwiftUI

/// 神仙云主界面。信息架构逐项对齐安卓 `design_main.xml`：
/// 标志 → 应用名 → 副标题 → 线路 → 电源键 → 状态行 → 模式切换 → 五个大按钮。
///
/// 安卓上「外部资源」「日志」两项是 `visibility=GONE`，这里同样不放。
struct ShenxianyunHomeView: View {
    @ObservedObject var vpn: VPNController
    @ObservedObject var profiles: ProfilesViewModel
    @ObservedObject var command: ClashCommandClient
    let client: ShenxianyunClient
    /// 进入上游那套完整界面（节点选择、设置都在里面）。
    let openUpstream: () -> Void
    let openNodes: () -> Void
    @AppStorage("shenxianyun.profile_id", store: UserDefaults(suiteName: ShenxianyunProfile.appGroup))
    private var installedProfileID = ""

    /// 上游 AppShellView 也是用 horizontalSizeClass 判断布局的，这里沿用同一套，
    /// 免得两层界面在 iPad 分屏时对宽度的理解不一致。
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isRegularWidth: Bool { horizontalSizeClass == .regular }

    @State private var showsImport = false
    @State private var isWorking = false
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
            if isRegularWidth { regularLayout } else { compactLayout }
        }
        .sheet(isPresented: $showsImport) {
            ShenxianyunImportView(client: client, onImported: handleImported)
                .shenxianyunLight()
        }
        .task { await loadState() }
        .onChange(of: vpn.status) { _ in
            if let failure = UserDefaults(suiteName: ShenxianyunProfile.appGroup)?
                .string(forKey: "shenxianyun.connection_error") { notice = failure }
        }
        .shenxianyunLight()
    }

    // MARK: - 两套布局

    /// iPhone、以及 iPad 上分屏/侧拉挤成 compact 宽度时。单列居中。
    private var compactLayout: some View {
        ScrollView {
            VStack(spacing: 0) {
                brandColumn
                controlColumn.padding(.top, 18)
            }
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 28)
        }
    }

    /// iPad 全屏。单列拉到 iPad 上会变成一条细带，中间大片空白。
    /// 拆成左右两栏：左边是「状态与开关」，右边是「能做什么」——
    /// 这也和用户的注意力顺序一致，先看连没连上，再决定要不要动它。
    ///
    /// 两个坑，都是实机截图才看出来的：
    /// 1. 右栏原本单独套了 ScrollView。**ScrollView 会贪心占满可用高度**，
    ///    于是右栏顶到天花板、左栏浮在中间，两栏完全不在一条线上。
    ///    改成整体一个 ScrollView，两栏都是自然高度，`alignment: .center` 才生效。
    /// 2. 光套 ScrollView 内容会顶到顶部。用 GeometryReader 量出视口高度再
    ///    `minHeight:`，内容比屏幕矮时垂直居中、比屏幕高时照常滚动。
    private var regularLayout: some View {
        GeometryReader { geometry in
            ScrollView {
                HStack(alignment: .center, spacing: 56) {
                    brandColumn.frame(width: 380)
                    controlColumn.frame(width: 440)
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 32)
                .frame(maxWidth: .infinity)
                .frame(minHeight: geometry.size.height)
            }
        }
    }

    /// 左栏 / 上半：品牌、电源键、状态。
    private var brandColumn: some View {
        VStack(spacing: 0) {
            header
            SXYPowerButton(
                isOn: isConnected,
                isBusy: isTransitioning || isWorking,
                action: togglePower)
                .padding(.top, 18)

            Text(isConnected ? "已连接" : "点此启动")
                .font(.system(size: 13))
                .foregroundStyle(SXYTheme.textMuted)
                .padding(.top, 14)

            statusRow.padding(.top, 10)

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
            Text("智能加速 · 稳定连接")
                .font(.system(size: 12))
                .foregroundStyle(SXYTheme.textMuted)
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
                title: "选择节点", trailing: .chevron, action: openNodes)

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
        accessCode = await client.savedAccessCode()
        expiresAt = await client.savedActivation()?.expiresAt
        // 地址表刷新是纯优化，失败也不提示——用户不需要知道。
        await client.refreshEndpoints()
    }

    private func togglePower() {
        Task {
            notice = nil
            if isConnected {
                await vpn.stop()
            } else {
                guard await client.activeSubscriptionURL() != nil else {
                    notice = "请先用提取码导入订阅"
                    showsImport = true
                    return
                }
                guard let profile = profiles.profiles.first(where: { $0.id == installedProfileID }) else {
                    notice = "当前订阅配置不可用，请重新导入提取码"
                    return
                }
                if !(await profiles.connectFromHome(profile)) {
                    notice = "连接未成功，请到设置查看配置或 VPN 错误"
                }
            }
        }
    }

    @MainActor
    private func handleImported(_ outcome: ShenxianyunClient.ImportOutcome, _ code: String) async throws {
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
        switch outcome {
        case let .managed(activation): expiresAt = activation.expiresAt
        case let .plain(_, status): expiresAt = status.expireTime
        }
        UserDefaults(suiteName: ShenxianyunProfile.appGroup)?.removeObject(forKey: "shenxianyun.connection_error")
        notice = "订阅已导入，可以启动了"
    }

    private func updateNodes() {
        Task { @MainActor in
            guard !isWorking, profiles.busyProfileID == nil else { return }
            isWorking = true
            defer { isWorking = false }
            guard let profile = profiles.profiles.first(where: { $0.id == installedProfileID }) else {
                notice = "请先用提取码导入订阅"
                return
            }
            guard let outcome = await profiles.syncAwaitingLibrary(profile) else {
                notice = "更新尚未完成，请到设置查看处理状态"
                return
            }
            switch outcome {
            case .changed: notice = "节点已更新"
            case .unchanged: notice = "当前节点已是最新"
            case .failed: notice = "更新失败，已保留原配置；请到设置查看原因"
            }
        }
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
