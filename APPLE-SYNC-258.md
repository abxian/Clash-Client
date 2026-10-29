# Apple正式版同步与神仙云UI/恢复（258）

2026-10-29 / Codex。用户明确恢复Apple开发；此前239冻结约束由本次明确指令解除。原分支codex/minimal-home-20261027与8fd29aa保留恢复点，开发分支codex/apple-sync-ui-20261029。

同步ProjectClash/Clash-Client公开main e3e6472，对应官方说明iOS1.0.13(151)，不是神仙云自有版本号；App Store最新1.0.13、GitHub没有Release标签。保留自有fork与神仙云0.1.0(1)、品牌/App Group/URL scheme；本轮不做正式发布。合并冲突仅依赖锁与配置创建策略，采用新版payload.routing/runsAsWritten，同时保留preservingRouting与服务端DNS/分组/规则所有权。其余新版大配置/模块/来源查看/网络改进完整合入。

锁定kernel4b7d5f53/adapter09fbc0d7及Go1.26.10；自有SDK fork main分别安全快进53658265/d47c04a，Client只构建正式配对锁定提交，不直接采用更晚HEAD。旧SDK校验每个字节/五切片provenance、旧Vendor比对旧Adapter后归档.build/sdk-archive/before-apple258-20261029，未裁剪。新SDK五切片已构建并核对准确sourceRevision/dirty=false/debug=false和库存；bootstrap下载工具链后，Apple构建器拒绝GOMODCACHE内部Go的overlay。将checksum核验的Go1.26.10原样复制到.build/toolchains/go1.26.10，校对bin/go、gofmt、runtime关键文件并使用局部PATH/GOTOOLCHAIN=local重跑成功，未改系统Go。Go二进制SHA256 5742f0004c49c005313d88cd06df964b09cad6bcf2eac4506bdb90abc923b1f4。第一次brand configure因Vendor尚未物化失败，SDK完成后重新brand/configure/universal CLI已成功。

UI：保留未连接提取码/启动、连接后配置、断开切码与启动；首页大按钮显式等宽高/fixedSize/玻璃材质，移除常态宣传与重复状态提示，保留首次必要流量用途告知及错误。自有节点sheet复用真实NodesModel的选择读回/测试调度器，每行两卡；运行配置已有自动组保持在前，测试不按延迟重排，不伪造不存在的自动组。隐藏高级页面时保留Home监控owner，不取消保存事务。后台更新不能阻止用户停止VPN。

服务：/api/update-state结构化限制/opaque revision，原码/设备token/URL/原profileID持续更新。到期加时、额度恢复、迁移更旧时间戳由权威状态发现。前台24–36秒，回前台立即检查；iOS后台/未运行遵循系统生命周期，不声称推送常连接。单飞保存、失败退避30至300秒、Retry-After冷却，限制在成功落地原受管源后才清除，版本也在成功后消费。15秒总HTTP读取预算跨base共享并取消慢响应体，网络/503不冒充过期，切码晚响应不覆盖。撤销不自动签票；手动断开的VPN保持关闭。购买入口继续受payment.entry.enabled既有分发开关控制，不自动打开商店购买引导。

入口：apple/ShenxianyunKit/Sources/ShenxianyunKit/{SubscriptionRecovery,ShenxianyunClient,Storage,APITransport,ShenxianyunError}.swift与Tests/SubscriptionRecoveryTests.swift；UI在apple/ClashClient/Sources/Shenxianyun/{ShenxianyunHomeView,ShenxianyunComponents,ShenxianyunNodesView}.swift、ClashClientApp.swift。新版下载仍复用ProfilesView.syncAwaitingLibrary与ResourceDownloader现有DIRECT回退；本轮无后台/数据库/PC/安卓/52nm变更。

新10项服务测试覆盖到期加时/额度同revision恢复/低版本迁移/不ack失败/跨账号取消/晚读取消/503 RetryAfter/停用不续费/无expiry和旧服务/慢body总预算，59发现含旧2个模式跳过。隔离fixture新增--control JSON（restriction/revision/version/expires_at/node_name/fail_download），仅127.0.0.1与假数据；普通Swift测试/回环/Release环境门禁分开记录，模拟器与完整编译待补。手机/平板为业务目标，原生Mac/TV的237历史业务缺口不冒称本次已完成。

工具scripts/archive-verified-sdk.py ARCHIVE_DIRECTORY：Python3，调用现有bootstrap库存校验、Git旧Adapter，确认无未知修改后才移动SDK/inventory/vendor到新目录；既有archive拒绝覆盖。只写本地依赖缓存/指定归档，不读用户配置/凭据、不联网发布，恢复旧lock并移动三路径回原位即可回退。源文件Git归档，最终提交后固定源码下载核SHA。临时一次性命令/构建日志只写.build，不含生产数据。GitHub Actions使用shenxianyun-development.yml workflow_dispatch compile_ios=true选择本开发分支，默认CI服务/回环/Release/品牌门禁，最终来源和结论待补。

回退revert本开发提交并重建，旧源码/SDK归档/模拟器与旧包保留；不删除或重置用户设备、不更改当前已安装Mac App，不动正式下载/签名/商店元数据。构建通过不等于真机VPN/付费/模块/多设备验收。

2026-10-29验证门禁：Actions40811974621服务/回环/品牌成功，unsigned-ios在选Xcode阶段失败（公共runner没有Xcode27），并未编译源码。评估348保持失败证据，以本机Xcode27.1/SDK27.1新SDK/独立DerivedData258完整Debug/Release与模拟器验证替代本轮云端unsigned门禁；不降低SDK/部署目标/签名权限。兼容runner可用后恢复云端编译。50d源compile_ios=false40812265166与079源push40812337432全部成功（unsigned按条件skip），不能写成完整云编译成功。最终产品源与本机编译/模拟器结果待补。
