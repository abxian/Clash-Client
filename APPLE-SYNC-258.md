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

工具scripts/verify-isolated-recovery.py：参数--device/--fixture-state/--control/--output。Python3、Xcode simctl、已有DEBUG隔离App/fixture211前台运行；只允许名称Shenxianyun iPhone258的Booted专用设备，fixture状态与control必须在仓库.build且base为127.0.0.1。读取该设备App内假数据preferences与原source.yaml，写fixture control并有界轮询真实App监控。验证到期→加时+低版本迁移、额度同revision恢复、503保留旧配置/版本及后续恢复，最后核原profileID/token/URL且exchange仅1；只输出布尔/计数，不打印凭据。无真实VPN、无安装或修改App偏好；回退停止自己的fixture/App并移除自己的control，不删除用户数据。夹具--nodes-layout提供假三节点+url-test，仅DEBUG回环SXY_TEST_SCREEN=nodes打开实际节点sheet看布局，不能当真实连接状态/测速/故障切换验收。工具来源258/2026-10-29，Git源码+固定提交下载SHA归档。

## 最终开发验证 · 2026-10-29

产品源码8ba3385bbce76afe1a0e82db402315eb0503dcc6，官方e3e6472已作为祖先合并（merge3faa8e3）；后续仅工具/证据/报告提交，不改变已编译的产品源码。最终Debug与Release arm64 iOS Simulator在独立DerivedData258均BUILD SUCCEEDED，Xcode27.1(27A9275)/SDK27.1。两配置App和3扩展的神仙云Bundle家族/0.1.0(1)一致，主程序arm64及SHA见docs/evidence/apple258/verification.json；无签名，不是可装iPhone IPA。品牌注入/configure/universal CLI和--check成功。上游Swift5并发隔离警告保留，没有把警告视作本任务的新错误。

产品8ba云端40829813162 service-tests/brand-check success、unsigned条件skip；40811974621的unsigned缺Xcode27环境失败保留，评估348本机门禁替代，不称云端完整编译通过。最终本机服务59发现57通过2按模式跳过，独立回环1/Release环境门禁1再过，新增10恢复/取消/读取预算测试。夹具新增参数后回环/Release门禁再验通过。

实际DEBUG App隔离模拟器全链路通过：fixture211仅1次ticket exchange，过期→延长+更旧文件版本迁移应用B、同revision额度恢复应用C、503下载保留C及旧revision、后续恢复D；原profileID/device token/URL全程不变。iPhone17Pro 5B472B77-2619-445C-8762-6468A04EAE5C与iPad mini A17Pro 5A4B21E5-A0E0-436D-A179-36FCFF327525/iOS26.5，5张原始截图与检索文字/来源/失效条件见docs/evidence/apple258。节点页是DEBUG隔离路由，未开VPN，也没把离线选中样式当成真实代理切换。Computer Use未能识别Simulator App，本轮用Xcode专用simctl安装/启动隔离测试、只读截图与配置结果核对，无替代鼠标/键盘自动化。

专用两App和两设备已停止，两回环服务已停止；旧236专用设备原为Shutdown，本轮短暂boot后也恢复Shutdown。不重置/删除用户模拟器、不动当前Mac已安装fix255或系统代理。旧8fd29aa/旧SDK归档保留，本机约135GiB空闲，不裁剪里程碑。正式Mac命名241、原生Mac/TV237业务接入与真实签名/真机VPN/支付恢复/自动切换验收仍未完成；本轮只完成iOS/iPad开发。购买入口继续默认关闭，网站/后台恢复检测有效，未更改商店购买引导策略。未合Client main、未发正式tag/Release、未改NAS或正式下载。

持久工件：scripts/archive-verified-sdk.py、scripts/verify-isolated-recovery.py、scripts/isolated-api-fixture.py与docs/evidence/apple258白名单；完整方法/依赖/参数/读写范围/风险/回退在各docstring和本报告，最终manifest列SHA。GitHub固定提交回下载字节/SHA一致后归档；.build SDK/日志/假设备数据不入Git。Trilium17主题与实际AI记忆账本/共享执行/协作板的最终同步状态以项目笔记apple258-final-20261029及本地ops/apple-sync258-20261029/trilium-final-receipt.json为准；内部复核与用户实机验收分开。
