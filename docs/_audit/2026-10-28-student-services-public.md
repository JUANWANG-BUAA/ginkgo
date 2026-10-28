# 学生服务公开入口复核（2026-10-28）

仅匿名读取公开信息，不使用个人账号、Cookie 或学校写操作。服务目录官方入口为 [智慧北航使用指南](https://nic.buaa.edu.cn/info/1044/3785.htm)、[学生公寓办理流程](https://xszx.buaa.edu.cn/info/1173/1393.htm)、[就业资讯网](https://career.buaa.edu.cn/frontpage/buaa/html/index.html)、[学术文化](https://www.buaa.edu.cn/index/xswh1.htm)和[网络服务指南](https://nic.buaa.edu.cn/fwzn.htm)；地址由 upstream 提供。打印入口是使用指南而非直接打印页面；住宿链接是流程说明而非代办入口。

`GET https://career.buaa.edu.cn/f/recruitmentFair/ajax_calendar_list?time=2026-10` 在本机匿名请求中返回 HTTP 200，完整响应为 JSON，外层 `state=1`、`data` 为数组；该次返回 135 条。观察到字段 `id`、`title`、`campus`、`field`、`startTime`、`endTime`、`fairTypeName`、`url` 和 `status`，详情链接可为站内相对路径。记录仅说明该次公开读取，不包含个人资料或原始响应；不能以当次数量推断分页或时效。

本次首个请求 15 秒超时且只接收部分正文；延长上限的第二次才完整返回。工作树接入只读取 `state=1` 且 `data` 为数组的结果，项目字段、相对详情链接、空列表和 `state` 异常按结构变化处理；不推断 `status` 与取消的对应关系、限流规则、分页和所有日期形态。当前已有缓存、失败旧快照和合成回归；真实非空设备与网络验收另行记录。

`GET https://www.buaa.edu.cn/index/xswh1.htm` 的本次匿名复核返回 HTTP 200。列表项使用 `li id="line_u14_*"`，`h4` 为类型、`h3` 为标题，`p.sj` 内隐藏 `span` 为发布日期、其余文字为活动时间，`p.dz` 为地点；`../info/1076/<id>.htm` 是相对详情地址。页面当次显示 63 页，第 2 页指向 `xswh1/62.htm`，即倒序页码为“总页数 + 1 - 逻辑页”。实现每次先读取首页的当次总页数再请求后续页，不固定 63 或 62；无列表项视为结构变化而不是确认空。发布日期与活动时间保持独立，原文跳转不携带凭据。
