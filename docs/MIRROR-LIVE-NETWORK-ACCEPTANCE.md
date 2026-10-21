# 手动登录的学校接口耗时验收

`flutter/integration_test/live_network_test.dart` 默认跳过，仅在账号持有人现场时启用。脚本显示正常 LoginPage，由本人在模拟器输入，不从聊天、命令参数、文件或临时服务器接收凭据。

```sh
cd flutter
flutter test integration_test/live_network_test.dart -d emulator-5554 --dart-define=GINKGO_MANUAL_LIVE_NETWORK=true
```

登录等待最多5分钟。建立会话后依次对图书馆场馆、当前预约、iclass当天、研究生学籍及执行报告执行普通读取、重复读取、强制刷新。每项完成即在检查页发布，不离开页面等候；工具仅记录轮次、枚举索引、毫秒、条数、缓存标记、旧结果和错误码。研究生响应没有缓存标记，不按耗时猜命中。

脚本不截图，不保存正文，不调用签到/预约/取消。失败仍记为待验收。finally中正式signOut并restore确认signedOut/未记住；设备结束后另外只检查shared_prefs/ginkgo_secure_credentials.xml不存在或为空，不输出文件内容。integration_test会替换app入口，结束必须重新构建/安装正常main入口APK。

此入口仅覆盖读取与耗时发布；真实业务页面切换/下拉刷新、历史日期/分页、非空字段人工核对仍需分别记录，不能代替所有模块或所有线路验收。实际执行结果尚未取得，不计为真实通过。

开发验证：入口analyze通过；首次写文件误带flutter前缀未成功，修正工作目录后完成。未为等待登录运行18分钟全模块脚本，未执行已知不收敛mirror_test.dart。

## 2026-10-21 本轮设备恢复

完成 BYKC（46秒）、研究生（26秒）、作业修正后（39秒）、图书馆（70秒）各自合成 smoke 后，重新构建正常 main 入口 Android debug APK 并安装；无障碍树仅确认“统一身份认证”存在和工作台不存在，run-as仅检查文件名确认 ginkgo_secure_credentials.xml 不存在，未输出其内容。当前等待账号持有人本人登录，不复用历史聊天密码。

签名 release 候选也已构建，但与设备当时 debug 签名冲突，安装返回 INSTALL_FAILED_UPDATE_INCOMPATIBLE；没有卸载来清除潜在会话，改用同 debug 签名正常 main 包恢复。该候选未公开发布，不能把构建成功写为 Alpha2 发布或真实验收完成。
