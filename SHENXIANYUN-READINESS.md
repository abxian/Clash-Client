# 开发准备验证记录

> 本页是 #209 的历史准备记录。#210 已开始业务实现，当前范围和遗留以 [首版开发记录](SHENXIANYUN-FIRST-CLIENT.md) 为准。

2026-10-25 · Codex · #209。结果是新上游开发基线可编译，神仙云业务迁移尚未开始。

| 项目 | 核验结果 |
| --- | --- |
| 三个 fork | GitHub API 验证 isFork=true，parent 分别为 ProjectClash/Clash-Client、Clash、Clash-Adapter |
| GitHub 分类 | 三仓 topics 均含 shenxianyun-ios / shenxianyun / apple-client |
| 客户端 main | 3b8ea95eff7cdfd817608fdba8079f4b03013148，origin/main = upstream/main |
| 内核 main | 878ea2c063075b2a87b693f230dbe3d7aabf4cfc，origin/main = upstream/main |
| 适配层 main | bdf40d4148eca4ead785fe54d724abd79d020876，origin/main = upstream/main |
| 依赖锁 | 仅 repository 改到 abxian；kernel a5cb38da、adapter 821b6e40 保持上游配对 |
| 工具链 | Xcode 27.1 / 27A9275，Go 1.26.9，PyYAML 6.0.3（隔离 venv），XcodeGen 可用 |
| 适配层独立编译 | Clash-Adapter main 上 swift build -c release，exit 0 |
| CLI | 两架构 universal 辅助工具及内置 help / skill 验证通过 |
| SDK | bootstrap exit 0，五切片齐全；逐切片 sourceRevision = a5cb38da，sourceDirty=false；来源与文件清单验证通过 |
| 工程生成 | configure exit 0；project.yml 语义未变化，恢复原格式避免无关 diff |
| iOS 基线编译 | ClashiOS / Release / generic iOS Simulator / arm64 + x86_64 / CODE_SIGNING_ALLOWED=NO，exit 0，BUILD SUCCEEDED |
| 产物身份 | .build/DerivedData/Build/Products/Release-iphonesimulator/Clash.app，Clash / org.example.clash，是原始上游身份 |
| 路径归类 | 真实仓库位于 rc 根目录，分类目录 shenxianyun-ios-dev 下为相对软链接，均验证指向同一仓库 |
| 移动后验证 | xcodebuild -list -json exit 0，ClashiOS 等 scheme 可解析，原分类路径仍可访问构建产物 |

## 已解决的环境准备问题

首次 bootstrap 因 Go 1.26.9 仅存在于 GOMODCACHE、不能施加 Apple CPU overlay 而失败。
从 Go 已下载的同版本官方模块缓存复制到 `/Users/cgnay/sdk/go1.26.9`，仅给复制件增加用户写权限，保留缓存原件；重跑完整 bootstrap 成功。
运行构建时在当前 shell 的 PATH 前置该目录的 bin，不修改全局 shell 配置。
系统 Python 缺少 PyYAML，已在客户端 `.build/python-env` 中安装 6.0.3。

## 尚待处理的环境与产品验证

- Xcode 报告本机 CoreSimulator 1051.55.0 低于所需 1174.9.2，另有 CoreDevice 符号加载告警。generic 目标编译和工程解析均成功，但本次未启动模拟器，不能声称模拟器可运行。后续 UI 验证前先修复 Xcode 与系统开发组件匹配；本任务未改系统框架。
- 上游编译存在 Swift actor 隔离等告警，本次未改上游源代码，也未将其提升为新的业务修复范围。
- 神仙云品牌、提取码、节点选择、模式和遥测尚未迁入新基线。旧工程 e1575b5 完整保留，迁移入口见 SHENXIANYUN-DEVELOPMENT.md。
- 未执行生产提取码请求、未启动 VPN、未做真机验证；未签名、未创建 CI/Release、未发布或改下载入口。

## 本地证据与恢复

日志在 `/Users/cgnay/Desktop/claude/rc/shenxianyun-ios-dev/`：`bootstrap.log`（首次失败）、`bootstrap-retry.log`（成功）、`adapter-build.log`、`cli-build.log`、`configure.log`、`ios-build.log`、`project-list.json`。
一次性命令使用 git / gh API 创建核验 fork、设置 topics、克隆并保留上游远端；Python 仅用于锁定 URL、工具链复制、语义检查与归类，不产生带凭据脚本。
两个准备文档与依赖锁进入独立开发分支；日志和可重建二进制不提交。回退可正常 revert 准备提交；旧仓库不需恢复。三仓 topics 为新增分类，可独立移除。
