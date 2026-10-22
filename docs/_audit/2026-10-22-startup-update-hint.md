# 启动更新轻提示（2026-10-22）

## 实现

用户要求启动时检查一次更新，发现新版以hint提示。真实入口在首帧后与会话恢复并行启动独立检查，root生命周期内仅一次；登录/登出/主题重建/进入演示不新增检查。默认未注入的测试、离线组合及非Android平台不进行该检查。进入演示不会取消真实入口已经发起的公共版本请求，亦不请求学校数据。

- 复用既有MaintenanceService与Rust Android更新规则，不新增下载来源或修改版本比较、渠道选择、签名校验。
- version读取与checkUpdate合计8秒等待上限；失败、超时、无新版、缺APK或空版本信息均不打扰用户。timeout不取消底层已经发出的请求，但晚到结果被忽略；版本读取晚到不会再发更新请求。
- 有可用APK的新版本时显示“发现新版本 / 查看更新 / 稍后”，保持到用户查看或关闭；稍后本次运行不再提示，下次冷启动重新检查。前台外暂不显示，回来不重复请求。
- 查看进入既有软件更新页并带入版本/结果/原检查时间，不重复自动检查；用户仍可手动刷新、下载和确认安装，不自动下载安装。
- 最低版本门禁页面不显示可选hint；已有错误诊断提示优先，关闭错误后可继续显示更新hint，不改诊断记录。

## 文件

`startup_update.dart`负责单次状态和轻提示；`main.dart`持有并释放controller；`workspace_shell.dart`将可选hint放在应用home内部，支持登录页和工作区；`maintenance_pages.dart`支持初始检查快照。没有修改Rust、生成绑定、学校接口、权限、更新门禁清单或签名配置。

## 定向验证

- 五个相关生产/测试文件flutter analyze无问题。
- `flutter test --no-pub test/startup_update_test.dart test/maintenance_test.dart test/update_gate_test.dart test/session_widget_test.dart --reporter expanded`：20项通过，exit0。
- 新增6项场景覆盖：非阻塞登录与单次/关闭；缓存结果导航不重复请求、错误hint优先；失败/无新版/缺APK/不支持；总超时与迟到结果；释放/失活/恢复；最低门禁优先。
- 日志 `/tmp/ginkgo-startup-update-tests.log`。仅使用合成服务，无真实网络检查或设备截图；不等于远端新版本发现、真机安装或后台投递验收。遵用户要求不扩大全量矩阵。
- 测试中paused状态停止渲染帧，无法立刻从旧widget树断言隐藏；用inactive可渲染生命周期检查可见性，保留生产对所有非resumed状态隐藏的条件。

## 发布文案约定

Release正文与应用内更新说明保持3–5条短句，只说用户可见的改进；技术细节、测试数字与完整限制留维护记录。重要数据升级/丢失风险保留一句提醒。当前Alpha.7草稿已精简，历史发布正文未改。

当前Debug APK在新增启动检查之前构建，不包含本次新功能；正式发包需要从当前源码重建。未执行版本递增、commit/tag、远端发布或提高minBuild。
