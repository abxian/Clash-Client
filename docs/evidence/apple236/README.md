# Apple 平台审查证据 #236

2026-10-27 / Codex / 源码 2798e59。截图来源：新建 iPad mini A17 Pro / iOS 26.5 专用模拟器，simctl 原始截图。仅使用 scripts/isolated-api-fixture.py 假数据，无生产提取码、token、订阅或用户信息；无需遮盖。

关注点：竖屏右侧按钮超出可见区域；首页已绑定和 2099 到期日均为假数据。截图不证明 VPN 连接成功。源码布局变更、设备尺寸或系统版本改变后需重验，不能沿用本结论作验收。

- ipad-mini-portrait.png：1488×2266，原始竖屏截图。
- results.json：编译结果、编译错误、导入请求路径与布局证据。
- manifest.json：上述文件和报告的 SHA-256。

方法、前置条件、范围、清理与回退见仓库根 SHENXIANYUN-APPLE-PLATFORM-AUDIT.md。
