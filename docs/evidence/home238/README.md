# #238 首页隔离证据

2026-10-27 / Codex / iPad mini A17 Pro、iOS26.5、ClashiOS Debug arm64，原始simctl截图1488×2266。仅回环fixture假码/节点，无生产账号/凭据/真实订阅；未开VPN，无需图像遮盖。

焦点：断开首页只有切换提取码与启动，必要告知/更新结果保留；原固定双栏裁切消失。补充首页主动加载后，重新启动实际只下载一次，绑定profile与active一致（results.json）；初次0下载的失败尝试见根报告。截图不代表VPN运行、节点选择或后台已通过真机验收。布局/状态逻辑、屏幕或系统版本改变后必须重验。

完整复现、前置条件、源码路径、读写范围和回退见根HOME-ENTRY-238.md；原始日志在.build/home238-*，Git仅保存假数据证据，不保存App或原始业务日志。

证据索引：`ipad-disconnected.png`为重启刷新成功；`ipad-refresh-failure.png`为停用fixture后更新失败且保留旧配置；`iphone-first-launch.png`为全新iPhone 17 Pro/iOS26.5首次安装页（1206×2622）。2026-10-27原始simctl截图，2026-10-28归档，全部假数据、无敏感内容、无需遮盖。Debug及Release编译均成功；SHA清单同时包含根报告和全部图像/结果，布局或逻辑改变后这些截图即需重验。
