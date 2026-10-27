# 神仙云首页两阶段重构（#238）

2026-10-27 / Codex，源码基线3020d78，分支codex/minimal-home-20261027。

## 行为

- 首次未连接仅提取码输入和启动，启动动作依次prepare、安装/选中、commit、连接，保留系统VPN授权及必要数据告知。
- 已保存提取码且断开时显示切换提取码与启动，成功连接后才展示节点、模式、更新和设置。断开也退出已打开的高级界面。
- AppShell持有会话刷新状态，进程启动、稳定断开时刷新现有订阅；界面往返不重复刷新。首页主动load配置；列表异步变化只触发独立刷新，不取消导入事务。会话内每个启动/断开代次尝试一次，失败不因busy变化形成重试风暴，可重开软件重试或连接后手动更新。
- 采用有最大宽度的单栏，修复iPad mini固定956点双栏溢出。
- 沿用ResourceDownloader的普通通道与Extension DIRECT回退及同步后restage机制，刷新失败保留旧配置；无真实VPN环境不宣称此路径真机已验。
- 缓存API全部失效时仍可回到编译期引导地址；隔离Debug只使用当前回环地址，防止旧测试端口影响复现。业务拒绝仍不故障转移。

## 修改入口

`apple/ClashClient/Sources/Shenxianyun/ShenxianyunHomeView.swift`、`Sources/ClashClientApp.swift`；服务层`apple/ShenxianyunKit/Sources/ShenxianyunKit/ShenxianyunClient.swift`；回归`Tests/ShenxianyunKitTests/FailoverAndStateTests.swift`。

## 验证与边界

Xcode27.1、ClashiOS、Debug/Release无签名arm64 Simulator构建；Swift包49发现，47通过/2按模式跳过；回环集成和Release环境门禁分别1项通过。专用iPad mini/iOS26.5设备379708E3-5C77-43E5-B5B0-9DEFC173E304，假数据fixture127.0.0.1:57298。截图与最终启动刷新核对见docs/evidence/home238。没有生产请求、签名、真实VPN出口或商店发布。

同一任务PC仓库shenxianyun（包括Windows/macOS/Linux）和Android仓库shenxianyun-android分别提交及Actions验证。原生ClashmacOS/tvOS尚未接神仙云业务的#237缺口保留，本次不声称已完成其业务移植；iPad属于ClashiOS。

## 复现及回退

沿用scripts/isolated-api-fixture.py（--state必填，--port可选）及#211 Debug隔离环境；`SXY_TEST_API_BASE`指定回环，可选`SXY_TEST_IMPORT_CODE=fixture211`触发假码导入，不启动真实VPN。关闭测试进程和专用模拟器即清理运行状态，保留设备复现；不重置用户设备。PNG全为假数据，日期/版本/焦点/失效条件见证据README。首次复验未请求订阅的根因为首页未调用profiles.load，已补充并确认重开只下载一次；曾用无凭据的临时Debug状态文件定位，诊断代码已移除。原始日志在.build/home238-*.log，不提交二进制或敏感运行数据。

正常revert任务提交回退，源码3020d78和现有发布包保留；无数据迁移，不裁剪旧备份。正式发布与真机门禁保留给后续发布任务，当前仅开发分支和临时构建。Trilium计划65kZMQlSK4yu、AI记忆AveSJISKqcvH同步最终事实，PC/Android计划HyOJQ4yf7QkD。

2026-10-28收尾：iPhone 17 Pro/iOS26.5专用全新模拟器首次首页核对通过；iPad重启下载一次，停止回环服务后页面显示更新失败，active与配置SHA保持不变。证据为2026-10-27采集；所有模拟器检查未启动真实VPN。

并发收尾：savedAccessCode异步读取后再检查会话代次和忙状态，检查与代次标记之间不再挂起，避免并发通知在极快更新完成后重复刷新。
