# iOS提取码按钮与PC功能对齐核对 · 263

2026-10-30 / Codex。产品 `3948487782dd22429a7c0e34f159313fd39f8770` 已推分支`codex/code-entry-20261030`，前一恢复点9d469dd104d0af1cb03c2b76899eee2e054adf68。本轮是iOS/iPad开发，未合main/未签名/未发布IPA或商店，也未改PC正式2.5.48、Android2.11.51、NAS或后台。

## 页面与入口

修改`apple/ClashClient/Sources/Shenxianyun/ShenxianyunHomeView.swift`：用现有SXYActionRow钥匙玻璃按钮替换首页内嵌TextField；初次“输入提取码”、绑定后“切换提取码”，均复用ShenxianyunImportView真实输入sheet与prepare/install/select/commit路径。初次无保存码点击启动也打开sheet，导入完成后由用户手动启动，不偷偷开启VPN。运行时不显示切码项，原handleImported拒绝live tunnel/transitioning，避免更换正在计量的设备凭据。停止与运行均显示expiry/未知待同步；普通首页不显示累计上下行，内部设备计量上报没有删改。

## 仓库同步事实

本次重新fetch核验Client upstream/main仍e3e647283b1593a61dba622f13cd499deeda9b8b，对应官方iOS1.0.13(151)，已是本开发HEAD祖先，没有遗漏新的上游Client提交。自有fork业务已推，origin/main仍3b8ea95，是旧主干；“已同步开发分支”不等同“已合主干/已发布”。神仙云仍0.1.0(1)开发身份，保留品牌、AppGroup与scheme，不改上游版本号冒充自己的正式版。

依赖fork Clash origin/main=5365826544dd6f2ac7ce694d540fa533301591e2、Clash-Adapter=d47c04a3556a67f95929aaa15ae624c7df631e74，与最新fetch上游main均0/0；Dependencies.lock.json继续kernel4b7d5f53/adapter09fbc0d7正式配对，库存未重置。0/0只证明fork同步，编译仍消费正式pin而不是任意新HEAD。

## 与PC的对应和差异

| 功能 | PC本轮开发 | iOS/iPad本轮开发 |
|---|---|---|
| 已绑定的切码入口 | 玻璃按钮/弹窗 | 钥匙玻璃按钮/原导入sheet |
| 圆形启动、连接后显示配置 | 已有 | 已有 |
| 停止后到期日期/首页不显示流量 | 已有 | 本轮补齐 |
| 运行中更换提取码 | 先关本App代理/TUN、停核心后输入 | 运行中隐藏切码项，先手动停止 |
| 两列节点/自动项固定在前 | 已有 | 已有；自动策略依赖实际配置，不伪造自动组 |
| 到期加时、额度恢复、订阅文件迁移 | 原码/原受管配置自动更新 | 原token/URL/profileID成功落地后更新与ack |
| 后台检查 | 桌面进程存活时持续监控 | 前台/回前台有效，后台/未运行受系统生命周期限制 |
| PC `setting` 本机模式 | 可不连代理进入本机配置管理 | 尚无同名命令；连接后的设置仍复用原上游界面 |
| 升级 | NAS优先、GitHub备用；Mac手动DMG | 自有签名/商店和专属升级发现尚未完成 |
| 续费入口 | 桌面网站入口 | 网站/后台恢复检查已接，应用内外购入口仍受原分发开关控制 |

不能笼统称两端功能完全一致。1.0.13模块/覆写/来源查看等上游改进已随258合入，具体业务接入/真实隧道/自动故障切换/支付体验另验；原生Mac/TV237缺口仍保留，不因iOS页面变化称全部Apple平台完成。

## 验证、操作与回退

Xcode27.1/SDK27.1本机准确源Debug arm64+x86_64与Release arm64模拟器均BUILD SUCCEEDED，主App与3扩展身份/0.1.0(1)/架构及主程序SHA核验通过。云端40916103836品牌通过，但两个Mac任务没有runner、steps=[]即取消；annotations明确托管macOS arm64容量不足/多次未能取得runner，未执行源码，不称云端编译成功。评估363将本轮UI-only云编译/服务门禁替代为准确源本机完整编译、服务/回环/Release/真实隔离UI，保留云端原失败；内部264等待容量恢复补跑，不降SDK/签名/目标，不是用户待办。服务层59发现、57通过2模式跳过，回环与Release测试按模式另外执行；品牌检查通过。PC准确源12b37af392e786d9679e6d7bee9d781f19c0943b的7实际callback回归/27恢复/17启动与前端CI40916060520通过。

专用Shenxianyun iPhone263与iPad263/iOS26.5，DEBUG只允许127.0.0.1 fixture211；首次按钮、导入sheet、绑定后切码/expiry的3张原始截图和检索说明在docs/evidence/code263。iPad真实假提取码已安装原profile/source文件，无生产请求/VPN；sheet由现有DEBUG参数呈现，Computer Use名称/完整路径均无法识别Simulator，未换其它鼠标/键盘自动化，也不称按钮实际点击已验收。初次截白屏为启动未渲染，最终截图在渲染完成后核对；sheet下方是新模拟器系统滑行键盘提示。

`.build/DerivedData258`在已验证SDK基础增量构建，Debug全双架构；Release显式ARCHS=arm64，CODE_SIGNING_ALLOWED=NO。假服务及新设备只由本任务创建并最终停掉，不删用户模拟器/不碰已安装Mac App。开发改动需重建安装才生效；回退revert本轮UI提交，无数据/schema迁移、不删除原账号。SDK/旧258源码和恢复点保留，不机械裁剪。

本轮日志/机器回执在`/Users/cgnay/Desktop/claude/rc/ops/code-switch263-20261030`与`.build/code263-*`，脚本/截图明确版本、依赖、范围、风险与失效条件；GitHub按固定提交下载核SHA，Trilium项目当前态/构建/功能/运维/记忆/实际AI账本与PC对应页在最终核验后同步。评估362/363；计划先写双方变更日志code263-plan-20261030。无签名IPA、生产账号、真实VPN/支付验收，不能将编译/截图/服务mock扩张为正式客户端验收。

最终隔离App/两专用模拟器已Shutdown，假服务端口53500已关闭；用户设备和当前Mac App/系统代理未改。云端原始状态/官方annotations在docs/evidence/code263/ci-capacity.json，本机证据verification.json与3图有检索文字/来源/SHA/失效条件。后置文档/证据提交不改变已编译产品3948487，故文档提交明确skip ci，准确源产品CI失败与本机替代仍如实保留。
