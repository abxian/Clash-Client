# #211 隔离模拟器证据

2026-10-26 / Codex / 神仙云 0.1.0 (1)。来源：simctl 原始截图，iPhone 17 Pro、iOS 26.5 (23F77)、Xcode 27.1 (27A9275)。页面通过 Debug 测试入口呈现，无手工点击导航或 VPN 真机验收。

仅包含人工 fixture。测试节点 127.0.0.1:9 不提供代理服务，到期时间 2099-12-31 为假值。无真实提取码、订阅、Apple 账号、用户数据或签名材料；原图检查后无需打码。图示失效条件：对应 UI、导入路径或配置编译流程变更；请重新执行隔离验证。精确 SHA-256/大小/焦点见 [manifest.json](manifest.json)。

- [首页](home-imported.png)：导入完成后显示已绑定与假到期时间。
- [节点页](nodes.png)：神仙云节点组、隔离测试节点和 DIRECT。
- [无效码](invalid-code.png)：中文错误且原绑定保留。
- [高级界面](advanced.png)：返回栏不遮挡配置名与启动按钮，显示1代理/1组/2规则。
- [配置核对](profile-proof.json)：active profile 指向fixture订阅，DNS/策略组和发布规则顺序一致。上游规则索引保留规则，active YAML 无 inline rules 不等于丢失。

完整前提、步骤、风险与回退见 [隔离验证记录](../../../SHENXIANYUN-ISOLATED-QA.md)。四图仅辅助检索，文字结果与测试是验收依据；不能证明 VPN 已启动、后台长期存活或共享容器跨进程有效。
