# 隔离联调与生命周期边界（#211）

2026-10-26 / Codex。基于业务 2883f07、回执 e87026f，分支 `codex/ios-isolated-validation-20261026`。

## 本轮修复

- `ShenxianyunClient.heartbeat` 返回时重新核对凭据；旧请求不能在切换提取码或 reset 后恢复旧 token。隧道会话固定启动时 token，后续 traffic/offline 发送前必须仍匹配，避免把旧流量发给新账号。
- `ExtensionProvider` 在运行 profile 身份变化时增加单调 epoch；`ScopedTunnelTrafficAccumulator` 遇到跨 epoch 的采样只重设基线，保留先前本账号已累计值。即使两次采样之间切出又切回，也不会计入其他 profile 的流量。边界未采样区间保守丢弃，不能宣称精确计量全部尾段。
- 旧配置授权错误的返回处理也核对 epoch，避免停止后来切到的其他配置。
- APITransport 使用客户端传入的平台值，隔离 macOS 测试客户端的 iOS 身份不会被宿主平台覆盖。
- 高级界面的神仙云返回栏改为独立布局，避免覆盖上游顶部配置名与启动按钮。

## 可重现的本机 API 测试

`scripts/isolated-api-fixture.py` 仅监听 127.0.0.1，默认随机空闲端口。假提取码是 `fixture211`，节点地址为 127.0.0.1:9，不提供实际代理线路。只记录请求方法/路径，不记录请求体或鉴权头。

```sh
swift test --package-path apple/ShenxianyunKit
python3 scripts/isolated-api-fixture.py --state .build/fixture-state.json --run-tests
# 保持测试后端供模拟器使用：
python3 scripts/isolated-api-fixture.py --state .build/fixture-ui-state.json
```

首命令发现 48 个测试，独立回环联调和 Release 环境门禁在默认 Debug 单测中跳过；46 项执行通过。第二命令启动真实本地 HTTP 服务，通过 URLSession 验证 verify → ticket → exchange → 下载带策略组/规则的 YAML → 本地提交 → heartbeat/traffic/offline，以及无效提取码保留原状态；该测试单独执行成功。脚本还以 Release 编译运行环境门禁，确认即使注入测试变量也不会覆盖生产引导地址。CI 已增加这一步，测试结束关闭自己的服务。

## Debug 界面验证入口

`DevelopmentBootstrap` 只在 Debug 接受环境变量 `SXY_TEST_API_BASE`，且仅允许无用户名/密码的回环 HTTP 地址；格式错误时使用 127.0.0.1:1，服务层请求入口拒绝非回环地址，避免复用生产缓存。Release 始终使用编译期引导地址，忽略这些测试覆盖。

在新建的隔离模拟器中用 `simctl launch` 设置 `SIMCTL_CHILD_SXY_TEST_API_BASE`，可选：

- `SIMCTL_CHILD_SXY_TEST_PRESENT_IMPORT=1`：呈现输入表单。
- `SIMCTL_CHILD_SXY_TEST_IMPORT_CODE=fixture211`：调用同一 prepare/install/select/commit 路径，验证自动化隔离导入。
- `SIMCTL_CHILD_SXY_TEST_SCREEN=settings` 或 `nodes`：呈现上游设置或节点入口。

复现本次设备（先确认该设备已启动；全新机器应创建自己的隔离设备并替换 UDID）：

```sh
python3 scripts/isolated-api-fixture.py --state .build/fixture-ui-state.json --port 57295
# 另一个终端，完成 Debug 构建后：
xcrun simctl install F2846F82-673C-4528-924D-363A5EEE21CA .build/DerivedData/Build/Products/Debug-iphonesimulator/Clash.app
env SIMCTL_CHILD_SXY_TEST_API_BASE=http://127.0.0.1:57295 SIMCTL_CHILD_SXY_TEST_IMPORT_CODE=fixture211 xcrun simctl launch --terminate-running-process F2846F82-673C-4528-924D-363A5EEE21CA de.sxnn.shenxianyun
xcrun simctl io F2846F82-673C-4528-924D-363A5EEE21CA screenshot .build/isolated-home.png
```

若端口已占用，让 fixture 自动选择空闲端口，并将其输出写入对应环境变量。仅操作本次新建设备，不能对用户原有设备执行重置/卸载。

这些是 Debug 专用的可重现测试钩子，不是用户操作流程，也不代表手工点击导航已验收。截图必须标记为隔离假数据；不能用真实提取码、真实订阅或生产签名材料替换 fixture。

## 开发环境事实与失败尝试

1. 本机 `xcodebuild -checkFirstLaunchStatus` / `xcrun simctl list runtimes` 检查链路触发 Xcode 官方组件补装，输出 Install Succeeded；CoreSimulator 从旧服务 1051.55 更新至 1174.9.2，可识别 iOS 26.5 (23F77)，新建模拟器成功启动。macOS 27.0.1、Xcode 27.1 (27A9275)。未手工替换系统框架。
2. 新建隔离设备 `Shenxianyun isolated 211`，UDID `F2846F82-673C-4528-924D-363A5EEE21CA`。原有模拟器未删除/重置，未读取其数据。所在卷可用空间检查为 181 GiB，保留独立设备用于复现，不裁剪其他备份。
3. 无签名 Debug App 可安装，但启动后 CloudKit 报缺 entitlement 而退出。仅在 `.build/SimulatorQA211` 复制件尝试本地 ad-hoc 签名，原始产物未改；首次误用含变量的生成 entitlement，解析成具体身份后仍被模拟器拒绝启动。该尝试不能写成运行成功，也不是开发者证书或真机签名。
4. `ICloudAutoBackup` 在 Debug 且启用隔离后端时使用上游已有的 unavailable sink，避免构造需要签名权限的 CKContainer；不访问真实 Apple 账号，不改变 Release 的 iCloud 能力。Debug 且为 Simulator 且启用隔离变量时，`Shared/ClashAppGroupContainer.swift` 将配置文件放在当前进程沙箱 Application Support/ShenxianyunIsolatedQA，解决无签名 App 无共享容器的问题；该替身不能证明 App Group 跨进程共享有效，真机和 Release 仍使用正式 App Group。模拟器中未验证 iCloud 备份、Network Extension 真正起隧道或实际出口。

## 工件、回退和遗留

可复用工件是本文件、fixture 脚本、生命周期/回环测试、CI 工作流和本轮结果清单；均随本分支提交并按 SHA-256 回读验证。脚本参数 `--state` 必填、`--port` 可选、`--run-tests` 可选；依赖 Python3、Swift；读写限本机回环和指定测试状态文件，不接触生产或用户业务数据。退出测试服务、卸载此隔离设备中的 App、正常 revert 本轮提交可回退项目改动；官方系统组件只能通过官方开发工具维护，不手工降级。

日志保存在客户端 `.build/tests211.log`、`integration211.log`、`ios211-debug*.log`、`ios211-release*.log`、`sim211-*.log`。二进制与原始日志不提交；可审计方法、成功/失败和剩余验证写入结果文档。iPhone 签名、VPN 真机、后台存活、系统强杀尾段补报、iCloud 实际功能仍需后续验证。

## 模拟器实际验证（2026-10-26）

已在 iPhone 17 Pro / iOS 26.5 隔离设备用无签名 Debug 运行：首页、提取码表单、高级界面、节点页均已呈现。通过 Debug 测试钩子实际走过 verify → ticket → exchange → URL 下载 → 上游配置安装/编译/设为当前 → 本地凭据提交，首页显示已绑定与测试到期日期。随后导入 bad-fixture 显示中文错误，原订阅与 active profile 保留。

读回该新设备的专用 QA 沙箱：DNS、策略组与 fixture 完全一致，published-rules.yaml 两条规则顺序一致。上游将规则编译为 x-clash-rule-index，因此 active/config.yaml 无 inline rules 并非规则丢失；高级页显示 1 个代理、1 个组、2 条规则，节点页显示「神仙云节点 / 隔离测试节点 / DIRECT」。脱敏结果和截图见 [证据目录](docs/evidence/ios211/README.md)。

模拟器没有可调用的 Simulator.app 图形入口，本轮使用 simctl 启动和原始截图，页面呈现由 Debug 钩子触发；没有冒充手工点击导航验收。初次键盘会出现系统滑行输入提示。未启动隧道、未测速、未请求真实订阅或生产 API；fixture 节点为本机端口 9。普通 UI 中的「可以启动」只表示配置已安装，不是实际 VPN 已连接。


## 构建与操作门禁

本轮使用 `ClashiOS` / `generic/platform=iOS Simulator` / `CODE_SIGNING_ALLOWED=NO`；Debug 缓存 `.build/DerivedData`、Release 最终缓存 `.build/DerivedData211Release`。Debug 和 Release 双架构均编译成功；布局最后调整的 Release 增量复查也已通过，结果写 [本轮机器可读清单](SHENXIANYUN-ISOLATED-VERIFICATION.json)。#210 的验证 JSON 保留为历史，不覆盖其当时尚未运行 UI 的事实。

Runbook 的 NAS 备份、部署、线上验收序列本轮按范围不执行：只修改客户端开发分支和新建隔离模拟器，没有 NAS 服务/生产数据变更。替代保障为保留 e87026f Git 恢复点、提交与远端推送、fixture 回归和 Simulator 证据；未引入开发者证书或发版。残余风险为真实权限、VPN/后台和 iCloud 未验；转入签名/真机/发布工作时恢复相应门禁并重新评估。无备份裁剪。
