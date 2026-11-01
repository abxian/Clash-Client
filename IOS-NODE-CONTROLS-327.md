# iOS/iPad 节点页固定测试操作区 · task 327 · 2026-11-02

基线 Client 48249f5；任务327/评估478。仅修改实际 ShenxianyunNodesView.swift 与 HomeView.swift 的模拟器节点预览；不动节点调度、选择确认、真实VPN和后端。

实际页将测试按钮从列表下方移到固定顶部，ScrollView只包双列LazyVGrid；运行时显示 NodesModel 的 latencyCompletedCount/latencyTotalCount 并提供取消，准备阶段也阻止重复点击。取消调用现有 cancelLatencyTests(reason: .requested)，包含 testAllSession 代次失效，防准备阶段的旧请求恢复。自动组优先及其余原顺序不变，测速不排序。

预览独立组件 SXYPreviewNodesView：40个明确标注演示节点用于长列表，自动选择第一；模拟进度/取消，不访问NodesModel或代理。关闭弹窗即取消演示任务。保留原 DEBUG + simulator + loopback + uiPreview VPN门禁。

前提：Xcode27.2、已准备本地SDK/生成工程、专用iPad326及loopback fixture53526。增量编译沿用 .build/DerivedData326；验证后仅重装专用设备72746310-36A6-425A-883C-09BFCA817E14的de.sxnn.shenxianyun。保持设备/fixture给用户操作，不改其余设备和生产服务。启动需SIMCTL_CHILD_SXY_TEST_API_BASE=http://127.0.0.1:53526及SIMCTL_CHILD_SXY_TEST_UI_PREVIEW=1。

回退：保留原Git48249f5和现有SDK，不裁剪。正常revert本任务提交并增量重编/仅重装该专用设备；不reset用户树或整机清数据。运行截图仅假数据，本地证据另记SHA；真实VPN大规模测速性能及实机签名待实机验证。

验证：准确最终 Debug arm64 Simulator 构建 BUILD SUCCEEDED；git diff --check 通过。CUA 实际将40项演示列表滚至节点36，顶部测试按钮仍在；开始后显示3/40和取消，18/40取消后按钮恢复；再次开始最终40/40，关闭重开首项仍自动选择。预览当前留在列表首部可操作。不把演示取消/进度当真实网络调度性能验证；未运行真实VPN测速。此次不重复326的服务65项测试（63过2skip），服务代码未改。

安装实际产物为 .build/DerivedData326/Build/Products/Debug-iphonesimulator/Clash.app（显示名神仙云），不要按显示名拼文件路径。首次按神仙云.app拼路径安装失败，随后 glob唯一.app重装成功，进程49877。单次临时命令为 xcodebuild原scheme/Debug/arm64/无签名构建，以及simctl仅指定专用设备terminate/install/launch；无可复用新脚本或凭据工件。
