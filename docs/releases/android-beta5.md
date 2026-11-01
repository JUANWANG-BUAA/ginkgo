# Ginkgo Android 0.1.0-beta.5

- 登录不再被学校目录卡住：统一认证通过即可进入，验证码可正常显示、提交与重试。
- 课表日期行七列完整显示，周课表/每日清单/学期/考试四项不再被裁切。
- 作业详情与列表状态一致，不再出现「列表已提交、详情待完成」。
- 首页不再首屏读取签到，滚动与后台刷新更稳定。

提醒：本轮修复了登录与验证码链路，但签到、作业提交、图书馆借阅等学校写入仍须逐次确认；校外网络下 UC 目录不可达时，签到、图书馆等依赖下游会话的模块仍可能提示需要重新验证。真实学校写入、物理设备与完整 live 验收末段仍未完成。

[功能与接口协议总览](../FEATURES-AND-PROTOCOLS.md) · [回归修复记录](../_audit/2026-11-01-beta4-hotfix-regression.md) · [GitHub Release](https://github.com/JUANWANG-BUAA/ginkgo/releases/tag/android-v0.1.0-beta.5) · [脱敏反馈](https://github.com/JUANWANG-BUAA/ginkgo/issues/new?template=android-beta.md)
