# 校园卡余额只读协议证据（2026-10-28）

## 范围与隐私

仅研究航财通校园卡余额。未读取银行卡、消费明细、充值、挂失、转账或支付密码流程，未执行任何资金写操作。本文不包含真实学号、姓名、卡号、金额、Cookie、ticket 或原始 HAR。

## 证据条目

- **E1 官方入口与公开前端**：`https://pass.cc-pay.cn/dashboard?linkfrom=pass` 的 `/index.js` 与 `/2.async.js` 定义 `GET /api/campus_cards` 和 `GET /api/campus_card/balance?stuNo=<值>`。`/13.async.js` 的页面只读取校园卡列表首项 `stuNo`，再调用余额动作。
- **E2 余额字段**：同一官方 dashboard 模块把响应的 `data.balance`、`data.unclaimedAmount`、`data.status` 写入页面状态；本客户端只投影 `balance`，不展示其余字段。
- **E3 外层结构**：官方 dashboard model 对校园卡列表读取 `response.data.data`；余额读取 `response.data.balance`。用户提供的真实请求与响应头确认这些端点返回 `application/json`，但所给 HAR 未包含响应正文，因此字段形状以 E1/E2 官方前端为据，不宣称取得了真实成功响应正文。
- **E4 统一认证入口**：登录页公开代码生成 `/login?backUrl=<当前页>&channel=BUAASSO`。匿名 GET 该入口返回 302：`https://sso.buaa.edu.cn/login?service=https%3A%2F%2Fpass.cc-pay.cn%2Flogin`。用户确认实际登录方式为北航统一认证。
- **E5 未登录失败形态**：匿名 `GET /api/campus_cards` 返回 HTTP 200，正文 `success=false,type=401`；匿名 `GET /api/user` 另含 `sub_type=4000011`。因此不能只用 HTTP 200 判定成功，业务 `type=401` 按会话失效处理。
- **E6 客户端合成契约**：`fixtures/campus_card/` 按 E1–E5 构造正常金额、合法零余额、未登录和畸形金额；不来自个人数据。真实 App 统一认证回跳、余额与官网一致性仍未验收。

## 实现边界

采用 `pass.cc-pay.cn/login?...&channel=BUAASSO` 建立现有学校会话，然后依次读取校园卡列表和余额。`stuNo` 只在 Rust 进程内传递，不跨 FFI、不写日志、不落盘；金额以整数分存储。用户主动点击才查询，页面默认遮挡，离页/后台/切账号清除；不接通用查询快照，不轮询，不提供任何资金写入口。
