# 神仙云 iOS 首版开发记录

2026-10-25 / Codex / #210。开发版本 0.1.0（1），不是上游商店版本；未签名、未发布、未真机验收。

## 实现范围

- 迁移旧 Apple 线 e1575b5 的品牌、云闪电图标、浅色首页和 iPad 布局；与 Android 配色保持一致。
- `apple/ShenxianyunKit/` 保留地址发现、API 故障转移、提取码 verify、ticket/exchange、受管订阅、稳定 client_id 和共享状态。
- 输入提取码后先准备授权，等待新版配置库完整安装并选中，才提交本地提取码/凭据；切换失败不主动覆盖旧本地账号。401/403/429/5xx 不再被吞掉后降级成普通订阅；仅非保护模式的 404/501 兼容旧服务。
- 神仙云订阅使用完整原始配置模式，保留服务端 DNS、策略组与规则，不套用上游链接导入默认的基础规则。节点更新复用新版配置库同步接口，等处理结果后再显示成功/已最新/失败。
- 电源键通过上游 `connectFromHome` 完成配置发布与 VPN 启动；模式通过 `ClashCommandClient.setMode` 操作真实内核。运行时显示累计上下行，连接失败给出可见提示。
- 首页“选择节点”进入新版节点页，“设置”进入完整上游界面；顶部返回神仙云。覆写、模块、脚本、规则、DNS、按需连接和诊断等入口保留。
- Extension 启动成功后才开始设备心跳和流量；仅运行中的 profile 与导入 profile ID 相符时发送，避免其他配置流量记到神仙云账号。正常间隔 300 秒加 0–60 秒抖动，30 秒检查一次是否到期，失败 Retry-After/指数退避、单飞、停止取消。
- 流量基线排除旧会话累计值，内核重载归零后继续累计新段；隧道停止前尽力提交最终累计值和 offline，各自只尝试一个地址、每请求超时 2 秒。
- 401/403 设备授权/额度拒绝触发停止隧道并存储通用可读错误；传输失败按退避处理。遥测日志不记录 token、订阅 URL 或后端原始错误。
- 导入页告知连接期间发送设备状态与累计流量，隐私清单声明账号标识、设备标识和使用数据用于应用功能且不用于追踪。分类键以 [Apple 官方 Privacy Manifest 文档](https://developer.apple.com/documentation/bundleresources/describing-data-use-in-privacy-manifests) 为依据，正式分发前仍需整体复核。
- `.github/workflows/shenxianyun-development.yml` 提供隔离服务层测试和品牌一致性检查；无签名 iOS 编译是手动可选任务，需要 runner 有 Xcode 27+，不做签名/发布。

## 编辑和构建入口

- 品牌、版本、引导 API、自己的 URL scheme：`site-profile.properties`；`scripts/brand-apply.py` 生成身份与 `ShenxianyunProfile.swift`。`--check` 有差异时返回非零；不直接编辑生成 plist/entitlements。
- UI：`apple/ClashClient/Sources/Shenxianyun/`；主壳入口 `Sources/ClashClientApp.swift`；上游导入新增可选 `preservingRouting`，默认行为保持，只有神仙云导入传 true。
- 协议：`apple/ShenxianyunKit/Sources/ShenxianyunKit/`；隔离测试：同包 `Tests/ShenxianyunKitTests/`。
- 隧道接线：`apple/ClashClient/Extension/ExtensionProvider.swift` 与 `ShenxianyunTelemetryReporter.swift`。
- 共享身份仍为 `de.sxnn.shenxianyun` / `group.de.sxnn.shenxianyun`，只注册 `shenxianyun` scheme；team 为空。内核与适配层 pin 没有升级。

```sh
export PATH=/Users/cgnay/sdk/go1.26.9/bin:$PATH
.build/python-env/bin/python scripts/brand-apply.py
.build/python-env/bin/python scripts/brand-apply.py --check
swift test --package-path apple/ShenxianyunKit
xcodebuild -project apple/ClashClient/ClashClient.xcodeproj \
  -scheme ClashiOS -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO build
```

## 验证边界和后续

只用 mock HTTP 做服务层验证，不调用生产提取码或真实设备授权；没有修改 vpn-web、PC、Android、52nm 或生产下载入口。
本地日志在 `.build/tests210.log`、`.build/brand210.log`、`.build/ios210*.log`。完整结果、提交和 CI 见项目变更记录。

本次本地结果：40 项隔离服务测试全部通过；品牌注入幂等/替代品牌干跑和 `--check` 通过；最终 iOS Simulator Release 的 arm64 与 x86_64 无签名编译成功。实际 App 与三个扩展的显示名、Bundle ID、0.1.0（1）、唯一 shenxianyun scheme 和隐私清单均已读取产物核对。机器可读结果在 [SHENXIANYUN-VERIFICATION.json](SHENXIANYUN-VERIFICATION.json)。首轮因本地 ByteCountFormatter 同名类型遮蔽失败，改为 Foundation.ByteCountFormatter 后两轮完整编译成功；不把失败尝试隐藏为一次通过。

以下仍需要后续验证或实现，不能据此说第一版已经可交付：

1. 当前 Mac 的 CoreSimulator/CoreDevice 组件与 Xcode 不匹配；generic 编译不代表模拟器启动或 UI 验收成功。修复环境后检查小屏、iPad 分屏、深色系统和错误场景。
2. 需自己的 Apple 开发者签名才能进行 iPhone VPN 实测；包括 DNS/出口、节点切换、前后台/重启、断网恢复、大订阅内存和模块兼容。
3. 实际提取码链路必须用专用测试数据，在授权的隔离后端或专门测试环境验证。准备授权的 ticket/exchange 本身可能在服务端绑定/轮换凭据；本地安装失败不代表服务器能撤销该副作用，不应宣称跨服务端事务回滚。
4. 正常停止时的最终上报是尽力而为；进程被系统强杀时最后一个上报间隔可能缺失，需要真机验证与后续持久化补报设计。不能把已有客户端的所有计量策略都写成 iOS 已对齐。
5. iOS 专属版本发现/升级提示、提取码 deep link 激活、PC 式导入后出口预检尚未接入。现后端 upgrade_hint 默认按 PC/Android 分组，不能直接展示为 iOS 更新。
6. 服务层已解析 bootstrap_proxy/直连提示字段，但本轮没有实现与 PC/Android 相同的额外救援代理和完整引导 DNS 改写。
7. 本轮只验证 iOS 目标；macOS/tvOS 源码仍保留，不代表神仙云业务 UI 在其他 Apple 平台已完成。

## 回退与上游同步

保留 `codex/shenxianyun-ios-20261025@a3d3cc3` 与旧 `shenxianyun-apple@e1575b5`。对业务提交正常 revert 即可回到纯上游准备状态，无生产数据迁移。
同步时先获取 upstream，审查 API、工程与依赖锁变化后合并业务分支，运行服务测试/品牌检查/无签名编译并再做真机回归。绝不 force 覆盖神仙云业务分支，也不把内核 main 自动替换为客户端 pin。

## 远端验证回执（2026-10-26）

业务提交 `2883f074cef0a1c579ac3b2457e0fc20680e5ac9` 已推送，GitHub [run 40209436084](https://github.com/abxian/Clash-Client/actions/runs/40209436084) 结论 success：服务层 40 项测试和品牌检查成功，远端 unsigned-ios 是手动可选任务，本次跳过；双架构无签名编译证据来自本机。远端 CI 不代表签名、安装或运行验收。开发记录、验证 JSON、品牌脚本、CI 配置已从 GitHub 按业务提交下载并核对 SHA-256；后续回执修改按新提交再次核验。
