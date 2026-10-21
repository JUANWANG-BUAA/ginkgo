# SPOC 课程归属只读取证

2026-10-21，匿名读取学校公开 SPA 静态脚本，没有登录、Cookie 或业务写请求。用户反馈学校页面分别显示学生、教师和助教课程。

## 可复查证据

- E1：`https://spoc.buaa.edu.cn/spocnew/js/app.6850dd87.js`，SHA-256 `8bc0ae09d46efd47e851cbe8f6fd17e5fe74f5aa6de872aaef07b4d75f320cd8`。模块 `9a8c` 导出 `s → c → GET /kc/queryXskcListPage`、`q → a → GET /kc/queryJskcListPage`，参数透传 `params`；账号角色菜单显示 `role[].jsmc`，选中 `jsdm` 作为 `RoleCode`。
- E2：`https://spoc.buaa.edu.cn/spocnew/js/chunk-cbf73164.860c584f.js`，SHA-256 `825438db7e9cc1d7632b14933b720455d2e1eeb08548348109689b87d2fee363`。`mycourse/index` 的 `getXsList()` 调用 `9a8c.s(pagetion)`，结果 `list → dataList1` 展示“课程角色：学生”；`getZhuJiaoList()` 调用 `GET /kc/queryZjkcListPage`，`list → dataList2` 展示“课程角色：助教”；教师使用 `getJsList()`。默认分页 `{pageSize:100,pageNum:1}`，卡片路由使用返回的 `kcid`。

## 实现边界

账号角色与课程内身份是两个概念。优先选择名称明确为学生的账号角色，不猜测数值角色码。以学生课程列表和助教课程列表的同系统 `kcid` 分类：同时出现时保留学生身份；未知 ID 或归属查询失败时保留原作业，不依据名称或课表缺失删除。默认收起已确认助教作业，允许显示。

⚠️ 端点与分组有公开学校代码佐证；本轮尚未登录核对真实分页、返回字段和用户报告的课程。不能据此宣称真实问题完全修复。SPOC 的 `kcid` 不等于 iClass 的 `courseId`，不得跨系统直接关联；iClass 的课程内身份仍待证据，不能套用上述数值或字段。
