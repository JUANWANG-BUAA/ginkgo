# BUAA Assistant - 接口文档（直连验证版）

> **修订说明（2026-10-13）**：本版重写了旧版接口文档。旧版混杂了三类不可靠内容：
> (1) 把 UBAA 中转服务器的 `/api/v1/*` 路由当成了北航上游直连接口——本项目仅直连，这些接口全部不可用；
> (2) 若干端点（byxt `courseTable.do`、byxt `grade.do`、`opac/api.php`、`uc/api/uc/userinfo`）在任何已知实现中都不存在；
> (3) 部分字段名与真实响应不符。
> 本版所有 ✅ 标记的内容均从 UBAA（BUAASubnet/BBAA）仓库的**在用代码**逐条核对重写，行号引用以该仓库为准。

### 0.0 修订对照记录（旧版 → 本版）

| # | 条目 | 旧版内容 | 本版内容 | 证据 |
|---|------|----------|----------|------|
| 1 | GSMIS 课表请求体 | `ZC=10&XNXQDM=2025-2026-1&XH=<学号>&XQDM=1` | `ZC=&XNXQDM=<学期码>&XH=&XQDM=`（仅学期码有值） | `GraduateScheduleUpstream.kt:50-55` |
| 2 | GSMIS 学期码格式 | `2025-2026-1` | `\d{4}[123]`（如 `20251`），代码强校验 | `GsmisSchedule.kt:16` |
| 3 | GSMIS 用户探测 | `getUserInfo.do` | 删除（全仓库无此请求，身份判定由 byxt §2.1 完成） | 全仓 grep |
| 4 | 本科课表端点 | `GET courseTable.do?xnxqdm=` | `POST student/getMyScheduleDetail.do`，表单 `termCode/type=week/week` | `LocalScheduleApi.kt:106-121` |
| 5 | 本科学期列表字段 | `XNXQDM/XNXQMC/DQZC` | `itemCode/itemName/selected/itemIndex` | `Schedule.kt:13-19` |
| 6 | 成绩端点 | byxt `grade.do`（JSON） | buaascore GET+POST 同址，POST 表单 `xq/year`，响应 JSON `e/m/d` | `LocalGradeApi.kt:33-79`、`Grade.kt:57-73` |
| 7 | 成绩数据源 A | byxt 大写拼音 DTO | 该 DTO（`cxwdcj`/WID/KCM）为死代码，唯一在用源是 buaascore | `GradeService.kt:119` |
| 8 | 图书馆借阅 | `opac/api.php?url=loan`（当作可用） | 降级为 ⚠️ 待验证探索项 | 全仓无 borrow/loan 实现 |
| 9 | 第 6-15 节九大系统 | UBAA `/api/v1/*` 中转路由 | 全部移除并说明（§7），直连需另行逆向 | `BBAA/docs/tech/server-routes.md` |
| 10 | SSO 验证码 | 未记载 | 补全（§1.3：检测正则、图片端点、`captcha`+`captchaResponse` 双字段同值） | `LocalConnectionAuth.kt:832-834,629-636,935-948` |
| 11 | SSO 密码过期页 | 未记载 | 补全（§1.5：`_eventId=ignoreAndContinue`，仅跳过一次） | `LocalConnectionAuth.kt:894-907` |
| 12 | 图书馆鉴权头 | `Authorization: Bearer <JWT>`（想当然的标准格式） | `Authorization: bearer<token>`（小写、无空格） | `LocalLibBookApi.kt:275` |
| 13 | 研究生课表数据格式 | HTML 表格 | JSON（`jgList/rwList/jcfaList`，成功码 `"1"`） | `GsmisSchedule.kt:24-37` |
| 14 | **保留** | GSMIS 基址 `gsapp/sys/wdkbapp`、buaascore URL、图书馆 CAS 入口与 v4 端点、`ZZWBKJ_ZHIHUAWEI` 加密方案、CAS 表单流 | 原样保留，仅补齐细节 | 各对应文件 |
| 15 | SSO 登录表单字段 | `rememberMe=false`（硬编码） | 实测无此字段；改为「页面隐藏字段全量回传」通用策略 | 2026-10-13 登录页实测（§1.2 注记） |

## 0. 文档约定

### 0.1 证据分级

| 标记 | 含义 | 使用规则 |
|------|------|----------|
| ✅ 已验证 | UBAA 仓库有在用实现，且经真实账号端到端验收 | 可直接按此实现 |
| ⚠️ 待验证 | 无任何在用实现参考，属推测 | **必须先抓包验证**，验证前不得写实现代码 |
| —— 中转 | UBAA 中转服务器路由 | 本项目（仅直连）不可用，本文档不展开 |

### 0.2 脱敏声明

本文档所有示例均使用合成数据：学号一律用 `sy2501001`，姓名用「李文」「张三」等通用占位，Cookie/token 值均为 `xxx` 形式占位。任何真实学号、姓名、Cookie、票据**禁止**写入本仓库（含测试快照与提交历史）。

### 0.3 通用请求约定

- 所有业务请求默认由共享 Cookie 的 `URLSession` 会话发出（Cookie 自动携带与保存）。
- 需要「Ajax 风格」的接口（各节单独注明）统一附加：
  ```http
  Accept: application/json, text/javascript, */*; q=0.01
  X-Requested-With: XMLHttpRequest
  Referer: <对应系统入口页，各节注明>
  ```
- 超时建议：连接 10s / 请求 30s（对齐 UBAA `LocalConnectionAuth.kt:314-317`）。
- **重定向策略**：认证链路上的请求必须用不自动跟随重定向的会话手动逐跳处理（见 §1.6）；业务数据请求可自动跟随。

---

## 1. 统一认证（SSO + UC）✅

对照实现：`BBAA/shared/src/commonMain/kotlin/cn/edu/ubaa/api/local/LocalConnectionAuth.kt`（988 行，下称 LCA）。

### 1.1 流程总览

```
┌────────────┐
│ 1. GET /login │──3xx──→ 已有会话 ──→ 4. 激活 UC ──→ 5. 验证会话 ──→ 完成
│ (禁自动重定向) │
└─────┬──────┘
      └──200──→ 解析登录页：execution / 验证码 / 提示文字
                    │
              2. (如需) 拉取验证码图片
                    │
              3. POST /login 提交表单（隐藏字段全量回传）
                    │
              3.5 (如遇) 密码过期跳过页 → POST ignoreAndContinue
                    │
              3.6 手动跟随重定向 + 错误检测
                    │
              4. 激活 UC ──→ 5. 验证会话 ──→ 完成
```

要点：**不需要手动管理 TGT/ST**。CAS 票据流转完全由 Cookie（`CASTGC` 等）+ 重定向链自动完成，客户端唯一要做的是持有 Cookie 并手动跟随重定向。仅图书馆（§5）需要手动从 URL 中提取票据。

### 1.2 获取登录页

```http
GET https://sso.buaa.edu.cn/login
```

- 使用**不跟随重定向**的请求（Swift: `URLSession` 配置 delegate 拦截重定向，或逐跳手动请求）。
- 响应 3xx → 已存在有效会话（Cookie 中已有 CASTGC），直接跳到 §1.5。
- 响应 200 → HTML 登录页，解析以下三样：

| 目标 | 提取方式 | 对照 |
|------|----------|------|
| `execution` 令牌 | 正则 `<input[^>]*name=["']execution["'][^>]*value=["']([^"']+)["']` | LCA:824-828 |
| 验证码配置 | 正则 `config\.captcha\s*=\s*\{\s*type:\s*['"]([^'"]+)['"],\s*id:\s*['"]([^'"]+)['"]` | LCA:832-834 |
| 预登录提示 | `div.tip-text` 内容（如「账号已锁定」），有则直接报错终止 | LCA:836-841 |

> **2026-10-13 实测记录**（无认证 GET，7195B）：`execution` 字段存在，值为 **JWT 三段结构**，含 `+` 与 `/` 字符——**表单提交时必须正确 percent-encode**（Swift 的 `URLComponents.queryItems` 默认行为即正确，勿手工拼接把 `+` 当空格）；默认页**无** `config.captcha`（验证码仅风控触发，与 §1.3 一致）；表单 input 实测共 6 个：`username/password/submit/type/execution/_eventId`，**没有 `rememberMe`**（旧版文档硬编码 `rememberMe=false` 无依据，见 §0.0 表第 15 条）。CasPageParser 三条正则与实测页面匹配。

### 1.3 验证码（旧版文档缺失，本节补全）

北航 SSO 在风控触发时要求验证码。**这是登录模块的硬需求，不是可选项。**

1. **检测**：登录页 HTML 中出现 `config.captcha = { type: '...', id: '...' }` 即需要验证码（§1.2 正则）。
2. **获取图片**：
   ```http
   GET https://sso.buaa.edu.cn/captcha?captchaId=<id>
   ```
   返回 JPEG 二进制，客户端转 Base64 内嵌展示（LCA:629-636）。
3. **提交**：登录表单中 `captcha` 与 `captchaResponse` **两个字段都填同一个用户输入值**（LCA:935-948）。只填一个会失败。
4. 若已检测到需要验证码但用户未输入，直接返回「需要验证码验证」错误并附上图片，不发起登录请求（LCA:484-493）。

### 1.4 提交登录

```http
POST https://sso.buaa.edu.cn/login
Content-Type: application/x-www-form-urlencoded
```

表单字段（LCA `buildCasLoginParameters`，909-933 行）：

| 字段 | 值 | 说明 |
|------|-----|------|
| `<页面全部隐藏字段>` | 原值回传 | **通用收集策略**：解析登录页所有 `<input>`，`type=hidden` 的全部按 name=value 回传；勾选的 checkbox 也回传。不要硬编码字段清单，上游加字段时自动兼容 |
| `username` | 学号 | |
| `password` | 密码 | |
| `submit` | `登录` | |
| `_eventId` | `submit` | 页面已有则用页面值 |
| `type` | `username_password` | 页面已有则用页面值 |
| `captcha` / `captchaResponse` | 用户输入 | 仅验证码场景（§1.3） |

### 1.5 密码过期跳过页（容易遗漏的分支）

提交后可能落在「密码过期 / 账号存在安全风险」提示页，页面特征：含 `continueForm`、`ignoreAndContinue` 字样或「密码过期」文案（LCA:894-899）。处理：重新提取该页 `execution`，POST：

```http
POST https://sso.buaa.edu.cn/login
execution=<新execution>&_eventId=ignoreAndContinue
```

（LCA:903-907）。此跳过只做一次，再次遇到同样页面视为登录失败。

### 1.6 手动跟随重定向与错误检测

提交登录后，用不跟随重定向的会话**逐跳** GET `Location`（相对路径按当前 URL 拼接，LCA:688-704）。每跳结束检查最终响应：

| 特征 | 判定 | 对照 |
|------|------|------|
| 最终 URL 含 `exception.message=` | 其后内容即上游错误消息 | LCA:670-673 |
| HTTP 401，或页面重新出现 `execution` 输入框 | 账号或密码错误 | LCA:674-681 |
| `div#errorDiv`、`.errors`、`tip-text` 有内容 | 其文本即错误消息 | LCA:843-869 |

### 1.7 激活 UC 会话

登录链走完后，必须访问一次 UC 激活地址，否则 `uc/status` 不认会话：

```http
GET https://uc.buaa.edu.cn/api/login?target=https%3A%2F%2Fuc.buaa.edu.cn%2F%23%2Fuser%2Flogin
```

（LCA:753-756）

### 1.8 会话验证（登录成功的唯一判据）

```http
GET https://uc.buaa.edu.cn/api/uc/status
Accept: application/json, text/javascript, */*; q=0.01
X-Requested-With: XMLHttpRequest
```

响应：

```json
{
  "code": 0,
  "data": { "username": "sy2501001", "name": "李文", "schoolid": "sy2501001" }
}
```

判定规则（LCA:333-366）：

- `code == 0`（**Int 比较**）且 `data != null` → 有效，`data.schoolid`/`data.name` 即用户信息；
- 非 200、body 以 `<` 开头（HTML）、`code != 0`、`data == null` → 会话无效；
- **5xx 是暂时性错误，不得清除本地会话**（上游抖动会误杀登录态）。判定无效后先别急着清 Cookie：UBAA 的做法是「业务系统报未登录 → 复核 `uc/status` → 复核确认无效才清」（LCA:369-384），建议照抄这个两步确认。

> ⚠️ `uc.buaa.edu.cn/api/uc/userinfo` 端点：UBAA 代码中**不存在**调用（只有 `status` 与 `login`），旧版文档所载响应结构未经验证。如需用户详情（院系/邮箱），先抓包确认再实现。

### 1.9 登出

```http
GET https://sso.buaa.edu.cn/logout
```

无论成败，清空本地会话与 Cookie（LCA:613-622）。

### 1.10 业务系统「未登录」通用判定模式

所有业务系统共用这套判定（课表/成绩/图书馆各自的实现里都有一份）：

```
未登录 ⇐ HTTP 401
      ‖ 最终落在 sso.buaa.edu.cn（URL 判断）
      ‖ 响应是 HTML 且含 input[name=execution] 或「统一身份认证」字样
```

触发后走 §1.8 的复核流程再决定是否清会话、要求重新登录。

---

## 2. 课表 — 本科生（BYXT）✅

基址 `https://byxt.buaa.edu.cn`，认证 = 共享 Cookie 会话（登录后首次访问会经 CAS 302 自动建立 JSESSIONID，无需手动处理票据）。
对照实现：`BBAA/shared/src/commonMain/kotlin/cn/edu/ubaa/api/local/LocalScheduleApi.kt`（下称 LSA）。

### 2.1 门户探测与身份判定

```http
GET https://byxt.buaa.edu.cn/jwapp/sys/homeapp/api/home/currentUser.do
```

响应分类（LSA:337-394），**这一步同时完成登录探测和本科生/研究生判定**：

| 响应特征 | 判定 | 后续 |
|----------|------|------|
| 401 / 落在 SSO / HTML 含 execution | 未登录 | 走 §1.10 |
| 200，body JSON，最终 URL 含 `/jwapp/sys/byrhmhsy/` | 研究生账号落在研究生门户 | 改走 §3 GSMIS |
| 200，body 以 `{` 或 `[` 开头 | 本科生就绪 | 继续 §2.2 |
| 200，body 是 HTML（其他情况） | 上游不可用 | 报业务错误 |

### 2.2 学期列表

```http
GET https://byxt.buaa.edu.cn/jwapp/sys/homeapp/api/home/student/schoolCalendars.do
```

Ajax 头 + `Referer: https://byxt.buaa.edu.cn/jwapp/sys/homeapp/index.html`（LSA:206-213）。

响应（`code` 是**字符串** `"0"`，LSA:227-228）：

```json
{
  "code": "0",
  "msg": null,
  "datas": [
    { "itemCode": "2025-2026-1", "itemName": "2025-2026学年第1学期", "selected": true, "itemIndex": 1 }
  ]
}
```

> 旧版文档写此接口返回 `XNXQDM/XNXQMC/DQZC`——**不正确**，真实字段为 `itemCode/itemName/selected/itemIndex`（`BBAA/.../dto/Schedule.kt:13-19`）。`DQZC`（当前周次）不存在于此接口，周次信息走 §2.3。

### 2.3 周次列表

```http
GET https://byxt.buaa.edu.cn/jwapp/sys/homeapp/api/home/getTermWeeks.do?termCode=<itemCode>
```

响应 `datas: [Week]`，`Week` 字段：`startDate, endDate, term, curWeek, serialNumber, name`。当前周 = `curWeek == true` 的项。

### 2.4 周课表（核心）

```http
POST https://byxt.buaa.edu.cn/jwapp/sys/homeapp/api/home/student/getMyScheduleDetail.do
Content-Type: application/x-www-form-urlencoded

termCode=2025-2026-1&type=week&week=10
```

> 旧版文档的 `courseTable.do?xnxqdm=` **不存在**。真实端点是 `getMyScheduleDetail.do`，POST 表单，参数名 `termCode/type/week`（LSA:106-121）。

响应 `datas` 为 `WeeklySchedule`：

```json
{
  "code": "0",
  "datas": {
    "arrangedList": [{
      "courseCode": "CS101",
      "courseName": "算法设计与分析",
      "courseSerialNo": "01",
      "credit": 4.0,
      "beginTime": "08:00",
      "endTime": "09:35",
      "beginSection": 1,
      "endSection": 2,
      "placeName": "新主楼A101",
      "weeksAndTeachers": "1-16周 张三",
      "teachingTarget": null,
      "color": "#4A90D9",
      "dayOfWeek": 1
    }],
    "code": "sy2501001",
    "name": "2025-2026学年第1学期",
    "sectionTimes": [{ "section": 1, "start": "08:00", "end": "08:45" }]
  }
}
```

字段注意：

- `datas.code` 本科接口返回的是**学号**而非学期码（研究生适配才填学期码，见 `Schedule.kt` 的 `WeeklySchedule` 注释）——不要拿它当学期标识，也是 PII，展示层注意裁剪；
- `dayOfWeek` 是 1-7 整数；节次由 `beginSection/endSection` 给出（闭区间）；`beginTime/endTime` 为 `HH:mm`；
- `credit` 在 DTO 中按 `String?` 接收（上游数字/字符串不定，宽松解析）；
- `weeksAndTeachers` 是展示用文本，**周次规则以选周查询为准**（逐周拉取或自行解析）。

### 2.5 今日课表

```http
GET https://byxt.buaa.edu.cn/jwapp/sys/homeapp/api/home/teachingSchedule/detail.do?rq=2026-10-13&lxdm=student
```

`rq` 为 `yyyy-MM-dd`，`lxdm` 固定 `student`。响应 `datas: [ { bizName, place, time, shortName } ]`（LSA:131-140）。

### 2.6 考试安排

```http
GET https://byxt.buaa.edu.cn/jwapp/sys/homeapp/api/home/student/exams.do?termCode=<itemCode>
```

注意 Referer 与其他接口不同，多一级 `/home/`：`https://byxt.buaa.edu.cn/jwapp/sys/homeapp/home/index.html`（LSA:215-222）。
响应 `datas: [Exam]`，字段：`courseName, courseNo, examTimeDescription, examDate, startTime, endTime, examPlace, examSeatNo, week, examStatus, examType, taskId`。
**研究生账号访问直接 403**（错误码 `unsupported_portal`，LSA:144-148），客户端要按身份隐藏入口。

---

## 3. 课表 — 研究生（GSMIS）✅

基址 `https://gsmis.buaa.edu.cn/gsapp/sys/wdkbapp`（旧版文档注明的「非旧版 /pyxx/kb/」正确）。
对照实现：`BBAA/shared/src/commonMain/kotlin/cn/edu/ubaa/api/feature/GraduateScheduleUpstream.kt`（下称 GSU）+ `model/dto/GsmisSchedule.kt`。

> 旧版与 TESTING 旧版均把研究生课表当成 HTML 表格解析——**错误**，GSMIS 课表是纯 JSON。

### 3.1 进入门户（会话探测）

```http
GET https://gsmis.buaa.edu.cn/gsapp/sys/wdkbapp/*default/index.do
```

未登录判定（GSU:120-141）：401；或最终 URL 的 host+path 为 `sso.buaa.edu.cn/login`；或 body 含 `<title>CAS Login</title>` / `name="execution"`。

> 旧版文档的 `yjsemaphome/modules/pubWork/getUserInfo.do`「用户信息探测」：UBAA 代码中**无此请求**，GSMIS 链路只有本节及 §3.2/§3.3 三个请求。研究生身份判定由 §2.1 的 byxt 探测完成。

### 3.2 开课学期查询

```http
POST https://gsmis.buaa.edu.cn/gsapp/sys/wdkbapp/modules/xskcb/kfdxnxqcx.do
```

无请求体；Ajax 头 + `Referer: .../wdkbapp/*default/index.do`（GSU:33-41）。

响应（`code` 为字符串 `"0"`，数据在 `datas.kfdxnxqcx`，GSU 模型 `GsmisSchedule.kt:7-22`）：

```json
{
  "code": "0",
  "datas": {
    "kfdxnxqcx": {
      "totalSize": 1,
      "rows": [{ "XNXQDM": "20251", "XNXQDM_DISPLAY": "2025-2026学年第1学期" }]
    }
  }
}
```

注意：GSMIS 的学期码格式是 `\d{4}[123]`（如 `20251`），**与 BYXT 的 `2025-2026-1` 不同**，两套体系不要混用。

### 3.3 课表数据（核心）

```http
POST https://gsmis.buaa.edu.cn/gsapp/sys/wdkbapp/bykb/loadXskbData.do
Content-Type: application/x-www-form-urlencoded

ZC=&XNXQDM=20251&XH=&XQDM=
```

四个参数全部传**空字符串**（除学期码），即返回全学期课表（GSU:44-61）。响应必须是 JSON（body 以 `{` 开头）。

**成功码是字符串 `"1"`**（注意与 §3.2 的 `"0"` 不同，`GsmisSchedule.kt:31`——上游自身不一致，实现时勿抽象成常量）。

响应三个顶层数组：

**`jgList[]` 排课行：**

| 字段 | 含义 | 备注 |
|------|------|------|
| `BJDM` | 教学班代码 | 与 rwList 关联键 |
| `KCDM` / `KCMC` | 课程代码 / 课程名 | |
| `XNXQDM` | 学期码 | 必须等于所查学期（校验点） |
| `XQ` | 星期 1-7 | |
| `KSJCDM` / `JSJCDM` | 起止节次 | 数字 |
| `ZCBH` | 周次位图 | 每字符 `'0'`/`'1'`，下标+1=周次 |
| `JASMC` | 教室名 | |
| `JGJSXM` | 教师姓名 | |
| `JCFADM` | 节次方案代码 | 关联 jcfaList |
| `KSSJ` / `JSSJ` | 起止时间 | 数字 HHmm（如 `800`），由节次方案回填 |

**`rwList[]` 课程任务：** `BJDM`、`XNXQDM/XNXQMC`、`XF`（学分）、`SCSKRQ`（首次上课日期，用于反推学期起点，见下）。

**`jcfaList[].skjcList[]` 节次方案：** `JCFADM`、`DM`（节次号）、`KSSJ/JSSJ`。

**学期起点反推**（GSU:42-68）：用 `SCSKRQ` 减去最早排课的周偏移，推算开学日期；结果必须唯一且为周一，否则视为上游数据异常。这个算法建议原样移植——它是处理上游不给开学日期的必要补丁。

---

## 4. 成绩（buaascore）✅

基址 `https://app.buaa.edu.cn/buaascore/wap/default/index`（GET 与 POST 是**同一个 URL**）。
对照实现：`BBAA/shared/src/commonMain/kotlin/cn/edu/ubaa/api/local/LocalGradeApi.kt`（下称 LGA）。

> 旧版文档给出的 byxt `grade.do` JSON 接口**不存在**。UBAA 的 `Grade.kt` 中确有一套 `WID/XNXQDM/KCM/XSZCJ` 大写拼音字段的 DTO，但它是**死代码**（全仓库无引用，`cxwdcj` 结构仅存在于 DTO 文件内）；服务端与本地两条链路（`server/.../grade/GradeService.kt:119`、LGA:117）都只用 buaascore。

### 4.1 会话激活（GET）

```http
GET https://app.buaa.edu.cn/buaascore/wap/default/index
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8
```

此请求只为激活上游会话 + 登录探测（判定规则同 §1.10），返回的 HTML **不解析**（LGA:33-34, 109-114）。

### 4.2 成绩查询（POST）

```http
POST https://app.buaa.edu.cn/buaascore/wap/default/index
Content-Type: application/x-www-form-urlencoded
Accept: application/json, text/javascript, */*; q=0.01
X-Requested-With: XMLHttpRequest
Referer: https://app.buaa.edu.cn/buaascore/wap/default/index

xq=1&year=2025-2026
```

`termCode` 拆分规则（`Grade.kt:77-85`）：`^(\d{4}-\d{4})-(\d+)$`，如 `2025-2026-1` → `year=2025-2026`、`xq=1`。

> **研究生注意（2026-10-13 查漏发现）**：GSMIS 学期码是 `20251` 形式（§3.2），本接口只接受 `2025-2026-1` 形式，调用前必须归一化：取前 4 位为学年起（`20251` → year `2025-2026`、xq `1`；`20252` → xq `2`）。UBAA 原工程**没有**做这个转换（`GraduateSchedule.terms()` 原样透传 `20251`，`parseBuaaScoreTermCode` 收到即抛错，server 中转 `GradeService.kt:54` 同样如此）——研究生直连查成绩在原工程是不可用的，这是本项目要明确补上的缺口。

> 返回是 **JSON，不是 HTML**（旧版文档写「响应：HTML 页面」，错误）。

### 4.3 响应结构

外层是单字母封装：

```json
{
  "e": 0,
  "m": "",
  "d": {
    "xxx-1": {
      "kcmc": "算法设计与分析",
      "kch": "CS101",
      "xf": 4.0,
      "kccj": 92,
      "fslx": "百分制",
      "kclx": "必修"
    }
  }
}
```

- `e` 是 **Int**，`0` 为成功（与 BYXT 的字符串 `"0"` 又不一样——再次提醒勿统一抽象）；
- `d` 是 `Map<String, BuaaScoreCourse>`（key 为课程标识，无业务含义，遍历即可）；
- **`xf`（学分）与 `kccj`（成绩）类型不稳定**：同一字段有时是数字有时是字符串。Swift 侧建议先以 `JSON` 原始值接收，再 `asText` 转 `Double?`（`Grade.kt:87-98` 的做法）；
- `gradePoint`（绩点）上游**不提供**，客户端自行按成绩制映射（TESTING.md §2.2 的映射表需先与学校公布的等级制核对）。

---

## 5. 图书馆座位（booking.lib v4）✅

基址 `https://booking.lib.buaa.edu.cn`。
对照实现：`BBAA/shared/.../local/LocalLibBookApi.kt`（下称 LLB）、`LocalLibBookCrypto.kt`、`LocalLibBookHttpClient.kt`。

### 5.1 CAS 登录链（与 §1 不同，需要手动提取票据）

1. 用**不跟随重定向**的会话 GET：
   ```http
   GET https://sso.buaa.edu.cn/login?service=https%3A%2F%2Fbooking.lib.buaa.edu.cn%2Fv4%2Flogin%2Fcas
   ```
2. 手动逐跳跟随 302（**最多 8 跳**），每跳从「当前请求 URL」和「Location 头」提取 `cas` 参数；正则 `[?&#]cas=([^&#]+)`，**查询串和 fragment（`#cas=...`）都要兼容**（LLB:334-399）。
3. 拿到 cas 令牌后换业务 token：
   ```http
   POST https://booking.lib.buaa.edu.cn/v4/login/user
   Content-Type: application/json

   { "cas": "<cas令牌>" }
   ```
   响应 `data.member.token` 即业务 token；缺失则登录失败（LLB:323-330）。
4. **后续所有业务请求的鉴权头**（LLB:275，逐字符对齐）：
   ```http
   Authorization: bearer<token>
   ```
   小写 `bearer`，**与 token 之间没有空格**。这不是标准 Bearer 方案，用通用 HTTP 库默认行为会拼出 `Bearer <token>` 而鉴权失败。
5. 登录失效判定：响应 `message`/`msg` 含「登录失效」「请重新登录」「未登录」→ 清 token 重新走 CAS，**重试一次**，仍失败才报错（LLB:280-292）。

### 5.2 业务端点（全部 POST JSON）

公共头：`Accept: application/json, text/plain, */*`、`X-Requested-With: XMLHttpRequest`、`Origin/Referer: https://booking.lib.buaa.edu.cn`，外加浏览器 UA（Chrome 桌面版，LLB:413）。

| 端点 | 用途 | 请求体关键字段 | 响应关键路径 |
|------|------|----------------|--------------|
| `space/pcTopFor` | 楼馆列表 | `day` | `data.list[]`：`id,name,free_num,total_num,children[]` |
| `space/pick` | 分区列表 | `premisesIds`（**字符串**，单个楼馆 ID）、`categoryIds:[]`、`storeyIds:[]`（可选单元素）、`boutiqueIds:[]`、`date` | `data.area[]`：`id,name,premises_id|premisesId,storey_id|storeyId,free_num,total_num` |
| `Space/map` | 分区详情/时段 | `id` | `data.area.{id,name}`；`data.date.list[].{day|date, times[].{id,start,end}}` |
| `Space/seat` | 座位列表 | `id,day,label_id:[],start_time,end_time,begdate:"",enddate:""` | `data.list[]`：`id,name,no,status,status_name`；`status=="1"` 可用 |
| `space/confirm` | **预约（加密，§5.3）** | `aesjson: <密文>` | `data.bookInfo{...}` |
| `member/seat` | 我的预约 | `type:"1",page,limit` | `data.data[]|data.list[]` + 分页字段 |
| `space/cancel` | 取消预约 | `id` | 看 code/message |

- 响应外层 `{ code: Int, message|msg, data }`，**`code` 为 0 或 1 都算成功**（LLB:293-301）。
- 字段名大量存在 `snake_case`/`camelCase` 双写变体（表中用 `|` 列出），解析层两种都要接受。

### 5.3 预约请求加密（AES-CBC）

仅 `space/confirm` 需要（LLB:242）：

```
明文 JSON：{ "seat_id": ..., "segment": ..., "day": "2026-10-13", "start_time": "", "end_time": "" }
密钥：取 day 中的 8 位数字 + 其反转拼接（"20261013" + "31016020"）= 16 字节
IV：固定 "ZZWBKJ_ZHIHUAWEI"
填充：手动 PKCS7 到 16 字节倍数（算法本身 NoPadding）
算法：AES-CBC-NoPadding → Base64 → 作为 aesjson 字段提交
```

（`LocalLibBookCrypto.kt:12-46`）

**Swift 实现注意**：CryptoKit **不支持 AES-CBC**（只有 GCM/ChaChaPoly）。需用 CommonCrypto 的 `CCCrypt`（kCCAlgorithmAES, kCCModeCBC 需手动处理填充，因为上游是 NoPadding+手动 PKCS7）。ARCHITECTURE.md §2 的「仅 CryptoKit」口径已按此修订。

### 5.4 TLS 证书链问题（macOS 风险点）

`booking.lib.buaa.edu.cn` 呈现的证书链不被 JVM/Android 信任，UBAA 在这两个平台对该域名做了**仅限图书馆客户端**的放宽信任（`LocalLibBookHttpClient.kt` 注释 + jvm/android actual）。**iOS/macOS（Darwin 引擎）没有做任何放宽**——可能系统信任该链，也可能同样失败。macOS 首次联调时把这一项列为必测项；若失败，处理方案与安全代价需单独评估（不建议静默全站放宽）。

---

## 6. 图书馆借阅查询 ⚠️（待验证，探索性目标）

**现状**：UBAA 没有借阅查询功能（全仓库无 borrow/loan/续借 相关实现），旧版文档的 `lib.buaa.edu.cn/opac/api.php?url=loan` 已于 **2026-10-13 实测证伪**（`/opac/`、`/opac/api.php`、`/opac/user/loans` 均返回 404；lib 官网首页为 JS 渲染的 SPA 壳，静态 HTML 无目录系统入口）。本功能无任何参考实现，列为探索项，验证完成前不进入正式里程碑。

验证清单（按 COLLABORATION.md 的逆向流程执行）：

- [ ] 浏览器登录图书馆 OPAC（lib.buaa.edu.cn），确认借阅页真实 URL 与是否独立于 booking.lib 的会话；
- [ ] 抓取 HAR，定位借阅列表 XHR（若为前端渲染）或服务端渲染 HTML 结构；
- [ ] 确认续借操作的端点、方法与 CSRF 要求（写操作，验证时只用本人账号只读部分）；
- [ ] 产出 `_audit` 取证文档（格式参照 `BBAA/docs/_audit/2026-09-17-ihome-api.md` 的证据分级写法）后再更新本节。

---

## 7. 本期不接入的系统（中转接口说明）

旧版文档第 6-15 节（博雅 BYKC、SPOC、操场 CGYY、阳光打卡 YGDK、iHome、空闲教室、课程评价、iclass 签到、考试安排中转版）记载的 `/api/v1/*` 路径全部是 **UBAA Ktor 中转服务器的自有路由**（见 `BBAA/docs/tech/server-routes.md`），不是北航上游直连协议。本项目架构为仅直连（ARCHITECTURE.md §9.1.3），这些接口**无法使用**；上述系统若未来要接入，每个都需按 §6 的逆向流程重新取证（其中博雅/操场还涉及上游自定义加密，见 DEEP-ARCHITECTURE-REVIEW.md §3）。此处不再罗列。

---

## 8. 统一错误处理

```swift
enum APIError: Error {
    // 网络
    case noConnection, timeout, tlsFailure
    // 认证（判定依据见 §1.10，勿只看单一状态码）
    case sessionExpired      // uc/status 复核确认无效
    case invalidCredentials  // 登录页错误特征（§1.6）
    case captchaRequired(CaptchaChallenge)  // §1.3，附图片
    case passwordExpiryPage  // §1.5，可自动跳过一次
    // 业务
    case upstreamError(Int, String?)   // 各系统 code!=成功值
    case graduatePortalUnsupported     // §2.6 研究生访本科考试
    // 解析
    case unexpectedResponse            // 结构与本文档不符 → 触发快照回归排查
}
```

错误处理策略保持旧版框架（sessionExpired → 刷新会话重试一次；captchaRequired → 弹验证码；upstreamError → 展示上游消息），但**会话过期的判定必须走 §1.8 的两步确认**，避免上游 5xx 抖动导致误登出。

## 9. 请求拦截器

旧版的 RetryInterceptor/CookieInterceptor 思路保留，修订两点：

1. **自动重试只对幂等 GET 开启**。POST（尤其预约、选课类写操作）不自动重发——上游切换语义下重发会反向操作（教训见 `BBAA/docs/features/ihome.md` 的写操作约束）。
2. Cookie 注入交给 `HTTPCookieStorage`（或独立 `URLSession` 的默认行为），**不要**手拼 Cookie 头——图书馆 CAS 链依赖 Set-Cookie 的域/path 语义，手拼容易丢 `HttpOnly` 标记的票据。

---

## 附录 A：已验证 URL 总表

| 系统 | URL | 认证 | 数据格式 |
|------|-----|------|----------|
| SSO | `https://sso.buaa.edu.cn/login`（+`/captcha`、`/logout`） | 表单 CAS | HTML |
| UC | `https://uc.buaa.edu.cn/api/login`、`/api/uc/status` | SSO Cookie | JSON |
| 本科教务 | `https://byxt.buaa.edu.cn/jwapp/sys/homeapp/api/home/...`（`currentUser.do`、`student/schoolCalendars.do`、`getTermWeeks.do`、`student/getMyScheduleDetail.do`、`teachingSchedule/detail.do`、`student/exams.do`） | SSO Cookie | JSON |
| 研究生教务 | `https://gsmis.buaa.edu.cn/gsapp/sys/wdkbapp/...`（`*default/index.do`、`modules/xskcb/kfdxnxqcx.do`、`bykb/loadXskbData.do`） | SSO Cookie | JSON |
| 成绩 | `https://app.buaa.edu.cn/buaascore/wap/default/index`（GET+POST 同址） | SSO Cookie | JSON |
| 图书馆座位 | `https://booking.lib.buaa.edu.cn/v4/...`（`login/cas`、`login/user`、`space/*`、`member/seat`） | CAS→token | JSON |
| 图书馆借阅 | 待验证（§6） | ? | ? |

## 附录 B：Cookie / Token 清单

| 名称 | 归属 | 说明 |
|------|------|------|
| `CASTGC` | sso.buaa.edu.cn | CAS TGT，HttpOnly，登录态根凭据 |
| `JSESSIONID` | byxt / gsmis / app | 各业务系统会话，CAS 首跳自动建立 |
| （图书馆）member token | booking.lib | §5.1 换取，使用方式 `Authorization: bearer<token>`（无空格） |

## 附录 C：各系统成功码速查（勿统一抽象）

| 系统 | 成功判定 | 类型 |
|------|----------|------|
| UC | `code == 0` | Int |
| BYXT | `code == "0"` | String |
| GSMIS 学期 | `code == "0"` | String |
| GSMIS 课表 | `code == "1"` | String |
| buaascore | `e == 0` | Int |
| 图书馆 | `code ∈ {0, 1}` | Int |
