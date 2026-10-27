# 同一 Apple 客户端的平台审查（#236）

2026-10-27 / Codex。源码基线 `2798e59e3beb66899832d5c8adb3bc283a2055d3`，审查分支 `codex/apple-platform-audit-20261027`。范围是本仓库 iPad、macOS、tvOS，不包含另外的 PC/Android 客户端。本次只新增审查证据，没有修改或发布业务代码。

## 结果

| 平台 | 已验证 | 当前问题 |
| --- | --- | --- |
| iPad | iPad mini A17 Pro / iOS 26.5 启动现有 #211 Debug App；本机假码校验、票据交换、订阅下载、安装、选中及本地提交成功 | 竖屏右侧控件被裁切，不能按可用客户端验收 |
| macOS | 独立缓存、Debug、arm64、无签名构建 | 编译失败；神仙云提取码流程未接入 Mac 界面 |
| tvOS | 独立缓存、Debug、arm64、无签名模拟器构建成功 | 神仙云提取码流程未接入 TV 界面；未做遥控器和运行验证 |

## 发现及修复验收条件

1. **P1 — Mac 编译被 iOS 专用代码阻断。** `apple/ClashClient/project.yml:414` 的 Mac Sources 未排除新增 Shenxianyun 目录。实际编译器在 `Sources/Shenxianyun/ShenxianyunHomeView.swift:332` 和 `ShenxianyunImportView.swift:92` 报 `cannot find 'UIApplication' in scope`。需明确平台专属视图边界或使用平台适配接口；重新编译 Mac App/Extension，同时回归 iOS。当前错误不能被品牌检查通过所替代。

2. **P1 — iPad 竖屏首页溢出。** `Sources/Shenxianyun/ShenxianyunHomeView.swift:89` 使用 380 + 440 点固定双栏、56 点间距、80 点水平内边距，合计 956 点；regular size class 并不保证有这个宽度。744 点宽 iPad mini 竖屏截图已复现右侧裁切。应按实际可用宽度切换单栏或自适应列宽；修复后覆盖 mini 竖横屏、大 iPad 和分屏/窗口窄宽度，并回归 iPhone。

3. **功能缺口 — Mac/TV 还不是完整的神仙云业务客户端。** iPad 复用 ClashiOS 的业务入口；Mac 使用 `Sources/Mac/ClashMacApp.swift:5206` 的通用 ProfileImportRouter，TV 使用 `Sources/TV/ClashTVAddSubscriptionScreen.swift:65` 的 Profile URL 入口。两个平台入口均未创建并连接 ShenxianyunClient 的提取码导入流程。共享包/Extension 中存在设备上报代码不等于 App 已完成设备绑定、凭据提交及受管 profile 关联。后续接入应复用 prepare → 安装/设为当前 → commit 两阶段流程，并验证失败保留旧配置、平台身份、心跳/流量/拒绝授权边界。TV 还需为遥控器输入设计适用的导入方式。通用订阅能力本身未被判定不可用。

4. **P2 — 版本号仍分裂。** 神仙云 iOS/共享资料为 0.1.0(1)，`project.yml:466` Mac 覆盖为 1.0.14(59)，`:800` TV 覆盖为 1.0.11(31)，相应 Extension 也保留覆盖。TV 实际构建 Info.plist 已确认 1.0.11(31)；Mac 数值来自项目配置，不能称为成功包。`scripts/brand-apply.py` 只更新全局 settings.base，不能覆盖这些目标设置。应确定统一发布版本策略并验证每个 App/Extension 产物。另有 `apple/ShenxianyunKit/Sources/ShenxianyunKit/APITransport.swift` 的 app_name 固定追加 iOS；移植时需与 platform 一起校验，避免 Mac/TV 上报名称误标。

## 重现、证据和边界

环境：Xcode 27.1，macOS SDK 27.0、tvOS Simulator SDK 27.0；仅安装 iOS 26.5 模拟器运行时，未安装 tvOS runtime。由项目现有依赖缓存构建，不升级上游或内核。

```sh
xcodebuild -project apple/ClashClient/ClashClient.xcodeproj -scheme ClashmacOS -configuration Debug -destination 'generic/platform=macOS' -derivedDataPath .build/AppleAudit236Mac CODE_SIGNING_ALLOWED=NO ARCHS=arm64 ONLY_ACTIVE_ARCH=YES build
xcodebuild -project apple/ClashClient/ClashClient.xcodeproj -scheme ClashtvOS -configuration Debug -destination 'generic/platform=tvOS Simulator' -derivedDataPath .build/AppleAudit236TV CODE_SIGNING_ALLOWED=NO ARCHS=arm64 ONLY_ACTIVE_ARCH=YES build
python3 scripts/isolated-api-fixture.py --state .build/audit236-fixture.json --port 57296
```

iPad 新建设备 `Shenxianyun iPad audit 236`，UDID `379708E3-5C77-43E5-B5B0-9DEFC173E304`。安装未改动的 `.build/DerivedData/Build/Products/Debug-iphonesimulator/Clash.app`（#211 构建），以 `SIMCTL_CHILD_SXY_TEST_API_BASE=http://127.0.0.1:57296`、`SIMCTL_CHILD_SXY_TEST_IMPORT_CODE=fixture211` 启动。第一次启动早于安装完成而失败，安装完成后重试成功。截图使用 `xcrun simctl io <上述UDID> screenshot <输出路径>`。导入用 Debug 钩子触发，不冒称手工操作验收。

原始本地日志：`.build/audit236-mac.log`、`.build/audit236-tv.log`；脱敏错误和截图见 [证据目录](docs/evidence/apple236/README.md)。原始构建日志和 App 不提交；图片只有隔离假数据。现有 CI 只有服务测试/品牌和手动 iOS 编译，没有 Mac/TV 构建及 iPad UI 覆盖；此次独立检查发现了上述漏项。

无真机、签名、真实 VPN 出口、Network Extension 跨进程、后台存活、iCloud 或遥控器焦点验收。未执行生产 API、后端改动、内核升级、NAS 部署、客户端发布。本次是审查完成，缺陷尚未修复；不能视为多平台首版可发布。

## 清理与回退

结束后停止本次回环 fixture、终止并关闭上述专用 iPad 模拟器，保留设备作为复现环境；不重置原有模拟器、不触碰真实 Mac 配置。只新增文档，可正常 revert 文档提交回退，无数据库或业务备份需求；源码基线 2798e59 保留。已有备份不裁剪。本次免部署/发布/线上验证，因为没有产品变更；后续修复必须重新通过相应构建和运行验收。

审查文档、截图、JSON/清单随 Git 分支留存，以提交固定的原始下载路径回读 SHA-256 核验。依赖 Python3、Xcode/simctl 和 #211 Debug 测试环境，写入范围仅本地独立缓存、专用模拟器、回环服务及审查记录。Trilium 项目变更记录 `4Xh7zcNM8N7w` 与 AI 记忆账本同步本轮结论。
