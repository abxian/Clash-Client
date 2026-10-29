# Apple258隔离界面与恢复证据

日期2026-10-29，来源Codex258；实际产品8ba3385（合并官方e3e6472），开发版0.1.0(1)，Xcode27.1/SDK27.1，专用iPhone17Pro与iPad mini/A17 Pro模拟器iOS26.5。五PNG为simctl原始截图，均为fixture211/127.0.0.1假数据，不含用户配置或凭据，无需额外遮盖。画面显示模拟器系统时间，来源日期以本记录为准。

| 文件 | 可检索关注点 |
|---|---|
| apple258-iphone-first.png | 全新iPhone首次仅提取码输入/启动；必要用途告知；玻璃正圆按钮 |
| apple258-iphone-bound.png | 已绑定停止页仅切换提取码/启动；无节点/模式常态选项 |
| apple258-ipad-first.png | iPad mini竖屏内容无裁切，按钮正圆，宽度适配 |
| apple258-ipad-nodes.png | 每行两节点、自动选择第一、选中态、底部整行测试连通性 |
| apple258-iphone-nodes.png | 手机两列卡片与底部测试操作不裁切 |

节点截图通过既有DEBUG隔离环境加SXY_TEST_SCREEN=nodes进入实际sheet，模型读取真实已导入的假配置；不伪造VPN已连接，不等于真实隧道/测速/自动故障切换通过。--nodes-layout夹具提供假三节点和url-test；生产没有该导航入口，未连接仍仅简洁首页。UI图片仅说明布局，不是唯一状态证据。

simulator-recovery.json为实际运行DEBUG App+回环fixture的原配置/原凭据/原URL、revision消费与错误保留证据：过期→加时+更旧文件迁移、同revision流量额度恢复、503保留旧源与版本、恢复后重试通过，exchange共1。无真实支付/生产数据/NetworkExtension运行。

复现按APPLE-SYNC-258.md：bootstrap准确pins、brand/configure，Debug arm64构建，启动专用模拟器并simctl install；fixture --state/--control，SIMCTL_CHILD_SXY_TEST_API_BASE固定当前回环地址，可选SXY_TEST_IMPORT_CODE=fixture211。节点画面另用--nodes-layout和SXY_TEST_SCREEN=nodes。不要向Release设置隔离变量（会被忽略）；不要重置用户设备。临时服务和专用设备收尾已停止，恢复重新启动即可。UI/内核/模型/布局/系统版本或字体设置变化后图片失效需重验；网络/支付/签名/真机结论始终另验。

工具：scripts/archive-verified-sdk.py、scripts/verify-isolated-recovery.py、scripts/isolated-api-fixture.py，SHA在最终manifest。参数/依赖/读写范围/风险/验证/回退见源码docstring和APPLE-SYNC-258.md。GitHub固定提交全文回下载SHA后才称归档，不上传.build缓存/原始运行日志/设备preferences。
