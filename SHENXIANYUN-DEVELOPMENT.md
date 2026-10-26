# 神仙云 iOS 开发入口

2026-10-26 · Codex。#209 上游准备、#210 首版业务迁移已提交；当前继续开发分支为 `codex/ios-isolated-validation-20261026`。本轮生命周期修复、隔离联调和模拟器证据见 [隔离验证记录](SHENXIANYUN-ISOLATED-QA.md)，上一轮实现见 [首版开发记录](SHENXIANYUN-FIRST-CLIENT.md)。仍未进行开发者签名、真机 VPN 验证或发布。

## 仓库分类

| 层 | 自有 fork | 上游 | 本地目录（相对工作区 rc） |
| --- | --- | --- | --- |
| 客户端与神仙云业务 | https://github.com/abxian/Clash-Client | ProjectClash/Clash-Client | shenxianyun-ios-dev/Clash-Client |
| Apple 内核 | https://github.com/abxian/Clash | ProjectClash/Clash | shenxianyun-ios-dev/Clash |
| Packet Tunnel 适配 | https://github.com/abxian/Clash-Adapter | ProjectClash/Clash-Adapter | shenxianyun-ios-dev/Clash-Adapter |

仅 fork 开发所需的三个项目。官网 clash.md 和三个 Legacy 仓库作为参考，不新增 fork。
所有仓库 origin 指向 abxian，upstream 指向 ProjectClash。
GitHub 三仓统一添加 `shenxianyun-ios`、`shenxianyun`、`apple-client` topics，便于按项目归类检索。
为兼容协作工具只扫描 rc 根目录的约定，真实仓库位于 `rc/Clash-Client`、`rc/Clash`、`rc/Clash-Adapter`；上表分类目录中的入口是相对软链接，两条路径访问同一工作树。协作锁分别使用 `Clash-Client`、`Clash`、`Clash-Adapter`，不要按两个路径重复认领或克隆。
客户端基线 3b8ea95；开发分支 `codex/shenxianyun-ios-20261025`。
内核和适配层保留上游代码；神仙云业务只写客户端开发分支。

## 可复现依赖

`Dependencies.lock.json` 已改用自有 fork，但保留客户端上游测试过的精确版本：

- kernel：`a5cb38dab6123ff1dded608b0d7fdceca9027421`
- adapter：`821b6e40f13b423f6e5d3017611851ef6955ca94`
- gomobile / gobind：sagernet `v0.1.13`

内核 main 已到另一版本，不能把 main 的最新版本当成当前客户端锁定版本；升级内核需单独验证。
不要照搬 Hako 历史笔记中的强制同步命令。新上游 README 说明其保留了 mihomo 历史，后续同步先 fetch、检查祖先与差异；禁止覆盖业务分支。

## 本地准备与验证

要求 Xcode 27+、iOS/macOS/tvOS SDK、XcodeGen、Python 3 + PyYAML；Go 工具链版本以锁定内核的 `bind/clash/go.mod` 为准。

从本目录执行：

```sh
export PATH=/Users/cgnay/sdk/go1.26.9/bin:$PATH
python3 -m venv .build/python-env
.build/python-env/bin/python -m pip install PyYAML==6.0.3
.build/python-env/bin/python scripts/bootstrap.py
.build/python-env/bin/python scripts/configure.py
xcodebuild -project apple/ClashClient/ClashClient.xcodeproj \
  -scheme ClashiOS -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

实际验证使用 `-derivedDataPath .build/DerivedData` 隔离构建缓存。

bootstrap 克隆 `.build/dependencies/{kernel,adapter}`，按锁构建并验证五切片 `Clash.xcframework` 的来源与清单，复制适配层到 `Vendor/`。
configure 生成工程，同时编译 macOS CLI，即使目标只做 iOS。生成文件、SDK 和 Vendor 不提交。
若 Go 只存在 GOMODCACHE 且构建拒绝 overlay，应按内核要求物化同版本官方工具链到 `~/sdk/`，不要复用旧 Go 1.26.6 或放宽 SDK 来源检查。
构建只验证编译；Network Extension 起隧道、内存、DNS、出口、后台遥测和重启恢复均需后续真机验收。

## 迁移来源与待办

旧项目 `/Users/cgnay/Desktop/claude/rc/shenxianyun-apple` 保持原样；业务来源为远端同名仓库的 `claude/brand-shenxianyun-20260905`，当前 `e1575b5`。
其 fork parent 已变为 `ProjectClash/Clash-Client-Legacy`，不是当前新客户端。
原 `Hako`、`Hako-Adapter` 两个目录同样只留作历史参考，不删除、不重置、不移动。

以下是 #209 制定的迁移顺序；当前实际实现以首版开发记录和源码为准：

1. 迁入旧 `apple/ShenxianyunKit`，先以隔离 mock 跑 `swift test`；检查现行后端协议，保留 ticket、exchange、受管订阅、稳定 client_id 和失败退避。
2. 移植 `site-profile.properties` 和品牌注入，针对新 `apple/ClashClient/project.yml`、标识常量和扩展逐项调整，不能直接运行旧脚本。
3. 保留原自有身份：`de.sxnn.shenxianyun`、`group.de.sxnn.shenxianyun`、`shenxianyun://`，不抢占 Clash 的 scheme / App Group。旧图标与 iPad 布局可复用，需重新验收。
4. 将旧首页接入新的 profile / VPN / Clash API，复核模式切换、节点选择、提取码导入与更新；逐项确认 Hako → Clash 的 Swift 模块和 API 变化。
5. 接通 Extension 生命周期和心跳/流量定时器；旧笔记存在已完成 UI 但遥测和模式仍未接通的记录，必须以代码和测试核对。
6. 重建新工程的无签名 iOS CI，随后才配置签名、真机和分发。旧 CI 的工程路径、scheme 与 Xcode 版本不可照抄。

沿用已确认方向：iOS 优先；独立 macOS 产品已有 PC 线；默认关闭购买引导；上架与分发后置。
纯 UI 验证使用隔离后端，禁止随意拿生产提取码测试；不得把凭据、订阅、签名材料写进 Git。
本任务不改变 vpn-web、生产域名、用户数据或下载入口。

## 回退与状态

旧工程和远端业务分支完整保留。新分支的准备改动可正常 revert，main 仍保留上游基线；无需 force push。
精确执行结果见同目录 `SHENXIANYUN-READINESS.md`。后续业务实现、完整编译、签名、发布、真机验收分别记录，不以 fork 成功代替完成客户端。
