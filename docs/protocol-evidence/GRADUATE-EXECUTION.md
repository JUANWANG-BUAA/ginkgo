# 培养方案执行报告语义核对（2026-10-19）

本记录只包含学校前端公开脚本的字段语义，不包含任何账号响应、凭据或个人数据。本轮复核已有本机静态取证文件；没有使用真实账号发送写请求。入口为 GSMIS 的 `wdpyfazxbgappbuaa` 应用，协议沿用 API.md 修订记录 49 的既有取证。

| 证据 | 文件与行号 | 核对结果 |
|---|---|---|
| E1 | `wdpyfazxbgBS.js:44–52` | 查询 `zxbg/loadXspyfazxbgInfo.do`，`isShowSszxbg` 取 0/1。 |
| E2 | `wdpyfazxbg.js:42–49` | `code === 0` 为失败；既有真实取证成功码为 1。客户端严格接受 1。 |
| E3 | `zxbgBuilder.js:12–20` | `fa.ZDXF` 是总要求；`yhpyfaxf` 是已获培养方案要求学分；`yxxf` 是已修学分，两者不可替换；`fa.XQLHKCXF` 是校企课程学分要求，`yhxqlhkcxf` 是已获校企课程学分，均非论文学分。 |
| E4 | `zxbgBuilder.js:66–73,148–159` | 类别与多选课组各有 `yqxf/yhxf/dkhxf`；类别另有 `zsms` 与 `kclbhbzyq`。后者是合并要求说明，不能仅凭单个类别的零学分判断全部达标。 |
| E5 | `zxbgBuilder.js:95–139,178–187` | `sfwc` 区分已完成与待考核；待考核学分不能作为已获学分；按课程代码去重。 |
| E6 | `zxbgBuilder.js:20` | `scxx.FDPYYQXF/FDPYWCXF` 是分阶段培养要求与完成学分，独立核对。 |

静态脚本 SHA-256：

- `zxbgBuilder.js`：`db34981abb435d11742cca3567bcb0187e9985f6c385cd1089f20f21fb49043c`
- `wdpyfazxbg.js`：`3ab95139d383920146d2793917ad1d64c3211c2018d2ddeb2a2c3f8f1532c95c`
- `wdpyfazxbgBS.js`：`5b140f802aab926150d6b3f9a529439c7acb436bd2b0092b5f6b72ec17d3e05a`

展示规则属于本应用的保守解释：每层缺口为该层要求减已获，最低为零；父子缺口重叠，不相加。缺失已获或要求则显示待核对。跨类别合并关系尚无已核对的结构化表达，保留完整原文，不自动拆解其归属或计算合并缺口。学校执行报告本身也要求以最终学校审核为准。
