# 提取码按钮真实隔离页面 · 263

2026-10-30 / Codex。产品3948487782dd22429a7c0e34f159313fd39f8770，Xcode27.1/SDK27.1，iPhone17Pro/iPad mini A17Pro iOS26.5独立模拟器。仅DEBUG环境127.0.0.1 fixture211假数据，未启动VPN，未使用生产提取码。

- iphone-first-home.png：首次首页：钥匙按钮打开提取码输入，无内嵌文本框；玻璃圆形启动。SHA/来源/失效条件见manifest.json。
- iphone-code-sheet.png：原真实导入sheet已呈现；底部是新模拟器系统滑行输入提示，不当成应用遮挡缺陷或点击验收。SHA/来源/失效条件见manifest.json。
- ipad-bound-home.png：真实假提取码完成原profile导入：切换提取码按钮、停止状态到期2099-12-31、不显示流量。SHA/来源/失效条件见manifest.json。

Computer Use无法获取Simulator应用，未替代鼠标/键盘自动化。通过现有DEBUG隔离参数呈现sheet/执行真实导入，simctl只用于专用设备启动、安装自有开发App和截图/只读验证。不能把截图当成按钮点击、真机VPN或端到端切码已验收；iPad原profile/source确已落地，正式账号/设备不变。

本机完整Debug双架构/Release arm64及身份/3扩展核验在verification.json；云端40916103836容量未取得runner，原失败/annotations与363本机替代、264内部补跑在ci-capacity.json。不是云编译成功或源码失败。
