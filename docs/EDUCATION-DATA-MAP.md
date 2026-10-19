# 教育系统只读数据地图（2026-10-18）

> 本文记录一次经用户明确授权的真实账号只读探测，用于判断博雅、图书馆研讨室、研究生教务与 SPOC 还有哪些数据可以接入。只发送查询请求；没有选课、退选、签到、预约、取消、评教或作业提交。正文不记录账号、姓名、学号、证件号、手机号、Cookie、Token 或完整响应。

> **当前产品范围更正（2026-10-19）**：维护者确认图书馆座位预约可行，产品不提供图书馆研讨室预约；研讨室仅指教学楼 CGYY。下文图书馆 seminar 是历史协议材料，不能据此宣称功能已提供。培养方案按执行报告的总要求、类别、课组逐层展示缺口；字段更正见 [执行报告取证记录](protocol-evidence/GRADUATE-EXECUTION.md)。

## 1. 结论

当前研究生账号可以实际读取：

| 系统 | 已取证数据 | 本次结果 |
|---|---|---|
| 博雅 BYKC | 资料、配置、课程库、课程详情、已选课程、博雅统计 | 74 门课程、5 个二级类别、14 门带签到配置、0 门已选 |
| 图书馆研讨室 | 可预约日期、筛选条件、45 个空间、容量/楼层/设备、逐日占用时段 | 当天起 3 天、5 类空间、2 个校区、45 个空间 |
| 研究生教务 GSMIS | 学籍摘要、培养方案头部/章节/课程、成绩、考试数量 | 培养方案 10 个章节、59 门计划课程；当前成绩 0、考试 0 |
| SPOC | 当前学期、11 门课程、13 项作业、课程教学数据 | 教学数据接口返回约 18 KB JSON |
| BYXT 本科教务 | 菜单、应用、待办、通知、成绩、考试、学籍、培养方案、成长档案等 API 线索 | 当前为研究生账号，BYXT `currentUser.do` 返回上游 NullPointer，需本科账号验收 |

## 2. 博雅 BYKC

### 2.1 登录

1. 通过当前网络路线 GET：

```text
https://bykc.buaa.edu.cn/sscv/cas/login
```

2. 跟随 SSO 登录/服务激活重定向，最终 URL 的 `token` 查询参数就是后续 `auth_token` / `authtoken`。
3. 所有业务接口均为 `POST https://bykc.buaa.edu.cn/sscv/<apiName>`。

### 2.2 请求加密

- 每次请求生成 16 字节随机 AES key。
- 请求 JSON 使用 AES-ECB + PKCS#7 加密，Base64 后作为原始请求 body。
- `ak`：同一 AES key 的 RSA-PKCS#1 v1.5 加密，Base64。
- `sk`：请求明文字节 SHA-1 十六进制字符串的 RSA-PKCS#1 v1.5 加密，Base64。
- `ts`：毫秒时间戳。
- Header：`auth_token`、`authtoken`、`ak`、`sk`、`ts`、`Content-Type: application/json; charset=UTF-8`。
- 响应可能是 Base64 JSON 字符串，使用同一 AES key ECB 解密。

### 2.3 已验证只读 API

| API | 请求 | 可读取内容 |
|---|---|---|
| `getUserProfile` | `{}` | 学生类型、班级、学院、当前学期；不要在 UI 持久化真实姓名/工号等无关字段 |
| `getAllConfig` | `{}` | 校区、学院、角色、学期起止日期、当前学期候选 |
| `queryStudentSemesterCourseByPage` | `{pageNumber,pageSize}` | 课程总数/页数；本月实测 74 门、2 页 |
| `queryCourseById` | `{id}` | 单门课程详情 |
| `queryChosenCourse` | `{startDate,endDate}` | 已选课程、签到状态、通过状态、成绩、作业和签到信息 |
| `queryStatisticByUserId` | `{}` | `validCount` 与按类别/子类别的应完成数、已完成数 |

课程对象可读取字段包括：课程名、教师、地点、起止日期、选课窗口、退选截止、容量/当前人数、类别、校区、课程简介、签到类型/配置、作业要求、是否已选。

本次实测课程类别分布：安全健康 21、德育 12、美育 9、劳动教育 7、其他 1；当前学期未选课，统计为 0。博雅存在选课/退选/签到写接口，本文和产品接入均不自动调用。

## 3. 图书馆研讨室

### 3.1 认证

图书馆座位与研讨室共用：

```text
浏览器/CAS → booking.lib.buaa.edu.cn/v4/login/cas → cas 参数
POST /v4/login/user {"cas":"..."} → data.member.token
POST /v4/*
Authorization: bearer<token>
```

### 3.2 已验证只读 API

| API | 请求 | 返回 |
|---|---|---|
| `POST /v4/seminar/siftdate` | `{}` | 可预约日期；实测 3 天 |
| `POST /v4/seminar/sift` | `{}` | 研讨室筛选树 |
| `POST /v4/seminar/list` | 见下 | 分页空间列表及占用时段 |
| `POST /v4/seminar/detail` | `{"id":"..."}` | 名称、容量、楼层、校区、设备、联系方式、规则图片 |
| `POST /v4/seminar/seminar` | `{"id":"...","day":"yyyy-MM-dd"}` | 3 天轴数据、营业时间、占用时段、最小/最大时长、最少/最多人数 |

`seminar/sift` 本次返回：

- 空间类别 5 个：6 人研讨室、8 人研讨室、2-4 人研讨舱、1-2 人研讨舱、单人电话舱。
- 设备标签 4 个：控制音量、无线投屏、电子笔、电子会议屏。
- 校区 2 个、楼层 5 个。
- 日期、可预约人数范围和时间范围。

`seminar/list` 请求体：

```json
{
  "page": 1,
  "date": "yyyy-MM-dd",
  "premises": [],
  "members": "",
  "floor": [],
  "category": [],
  "room": "",
  "boutique": [],
  "name": ""
}
```

本次返回 45 个空间，分 5 页。可读取字段包括 `id`、名称、类别、校区、楼层、最少/最多人数、设备标签、图片、开放/关闭时间、逐段占用时间和 `fully_booked`。列表中的 `date[].begin_timestamp/end_timestamp` 是已占用区间；空白区间才是可预约区间。

### 3.3 已发现的写接口，未调用

```text
/v4/seminar/members   添加参与人（返回成员对象）
/v4/seminar/confirm   预约前确认
/v4/seminar/submit    提交预约
/v4/seminar/cancel    取消
/v4/seminar/leave     离馆
/v4/seminar/signin    签到
```

提交草稿包含 `area_id`、`start_date`、`end_date`、`title/title_id`、`content`、`mobile`、`time[]`、`team`、`file` 等字段。字段来自前端静态包与正常页面逻辑，但本轮没有发送确认或提交请求，因此“提交成功语义、名额竞争、取消回查”尚未验收。建议先只读接入空档查询，再单独实现需要人工确认的预约写路径。

## 4. 研究生教务 GSMIS

### 4.1 门户目录

登录 SSO 后访问：

```text
GET https://gsmis.buaa.edu.cn/gsapp/sys/yjsemaphome/portal/index.do
POST /gsapp/sys/yjsemaphome/modules/pubWork/getCanVisitAppList.do  KEYWORD=
GET  /gsapp/sys/yjsemaphome/modules/pubWork/getUserInfo.do
```

`getCanVisitAppList.do` 返回 7 个一级栏目：

1. 学籍管理：我的学籍、信息确认、学生请假、学籍异动、证明申请、单独毕业答辩等。
2. 课程学习：培养方案、方案执行报告、免修免考、学分认定、课程查询、学校课表、停课信息、期中退课、考试安排、缓考、成绩、毕业审查、评教、空闲教室、我的课表。
3. 培养环节：资格考试、文献/研究/技术综述、开题报告、中期检查、研究计划、研究学分、专业实践、学术交流、学术报告、特殊事项等。
4. 培养项目：学术成果、创新成果奖、公派留学、教改项目、国际会议资助等。
5. 学位管理：学位信息、预答辩、论文归档、优秀论文。
6. 学生活动：学生活动教室借用。
7. 服务指南：政策文件。

### 4.2 已实际读取的只读接口

| 应用 | API | 本次结果 |
|---|---|---|
| 我的成绩 `wdcjapp` | `POST /gsapp/sys/wdcjapp/modules/wdcj/xscjcx.do` | 0 条成绩 |
| 我的考试 `wdksapp` | `POST /gsapp/sys/wdksapp/modules/ksxxck/getWdksxx.do` | 考试 0、考查课 0、监考 0 |
| 我的学籍 `wdxjappbuaa` | `POST /gsapp/sys/wdxjappbuaa/modules/wdxj/xsjcxxcx.do` | 1 条学籍记录，返回学院、专业、年级、培养层次、学籍状态、班级、入学/预计毕业、校区、学习方式等大量字段 |
| 我的培养方案 `wdpyfaappbuaa` | `POST /modules/pyfaxq/gjxhcxdyfadm.do` | 当前培养方案代码 1 个 |
| 我的培养方案 | `GET /modules/pyfaxq/facx.do` | 方案头部 1 条：名称、学院、专业、总学分、学位课学分、审核状态等 |
| 我的培养方案 | `GET /modules/pyfaxq/gjfadmhqdydpyfanr.do` | 10 个培养方案章节 |
| 我的培养方案 | `POST /modules/pyfaxq/pyfakcxxcx.do` | 59 门计划课程，含课程名、课程代码、学分、课程类别、考核方式、开课学期、是否必修 |

学籍记录包含身份证号、手机号、家庭住址、政治面貌、导师等敏感字段。产品接入必须使用字段白名单，只展示学院、专业、年级、培养层次、学籍状态、班级、入学/预计毕业、校区和学习方式，不缓存完整响应。

## 5. SPOC

### 5.1 账号与模块

本次 `sys/casLogin` 成功：

- 角色：学生。
- `routerList` 6 项：登录页、数字教材详情页、教师教学、学生学习、教学评价、教学管理。
- 当前学期接口返回 `dqxq/mrxq/dqrq/dqz/xqj/pjmrrq`。
- `/jxkj/queryKclb` 返回 **11 门课程**。
- 现有作业接口返回 **13 项作业**。
- `/jxkj/queryJxkjData` 返回约 18 KB JSON，可作为课程教学数据入口。

### 5.2 学生相关只读 API 线索

静态包和后端调用点中已发现：

| 数据 | API |
|---|---|
| 学期/课程 | `component/queryXnxq`、`jxkj/queryKclb`、`jxkj/queryJxkjData` |
| 课程内容树/学习内容 | `kcnr/queryKcnrTree`、`kcnr/queryByPageNewXs`、`kcnr/queryWjBykcid` |
| 作业列表/详情/提交状态 | `kczy/queryXsZyList`、`kczy/queryKczyInfoByid`、`kczy/queryXsSubmitKczyInfo` |
| 作业评阅/批阅结果 | `kczy/queryPycjList`、`kczy/queryPywj`、`kczy/queryXsPyKczyInfo` |
| 课程文件 | `coursecenter/kcfiles`、`fileManagerSystem/queryFileByIds`、`fileManagerSystem/downLoadFile` |
| 课程通知 | `coursecenter/notice` |
| 讨论/学习小组 | `coursecenter/discuss`、`coursecenter/discussinfo`、`coursecenter/studyteam` |
| 课程录播 | `coursecenter/kcrecord` |
| 课程信息 | `coursecenter/kcxx`、`coursecenter/kczy/zycjpyList` |
| 数字教材 | `/kcnr/querySzjcInfo`、`/kc/querySzjcInfoBybookid` |

其中通知/文件接口还需要课程内容树返回的 `nodeid` 或 `sslmid/sskcid` 参数，不能只传 `kcid`。`kczy/submitKcz`、`kczy/submitKcz2`、发帖、发作业、上传文件等写接口没有执行。

## 6. BYXT 本科教务可读目录线索

BYXT 前端包公开声明了以下读接口，适合本科账号后续验收：

```text
api/home/menus.do
api/home/myApps.do
api/home/myTodo.do
api/home/commonLink/queryCommonLink.do
api/home/announcement.do
api/home/messages_pc.do
api/home/student/schoolCalendars.do
api/home/student/courses.do
api/home/student/exams.do
api/home/student/scores.do
api/home/student/educational-program.do
api/home/student/academic-status.do
api/home/student/applys.do
api/home/student/academic-career-navigation.do
api/home/student/academic-career-term.do
api/home/student/academic-career-matter.do
api/home/student/getMyScheduleDetail.do
api/home/teachingSchedule/detail.do
```

本次研究生账号调用 `currentUser.do` 返回 `#E2140600091 NullPointer`，因此这些接口不能仅凭静态包宣称当前账号可用。本科成绩/考试/学籍/培养方案需要本科账号做同样的只读验证。

## 7. 实现状态与下一步

已在 Ginkgo iOS 落地并完成真实账号 live UI 验证；macOS 已补齐同三类数据页面（2026-10-19），编译与自动化测试通过，但尚未做真实窗口 live 验收：

> 2026-10-19 调整：侧栏“研讨室”改为**教学楼 CGYY**（`cgyy.buaa.edu.cn`），协议见 [API.md](API.md) §6B；本节 §3 的图书馆 `v4/seminar` 只读/预约代码保留，但不再是“研讨室”入口。培养方案进度发现课程列表是课程池（59 门/114 学分），方案最低总学分为 32；2026-10-19 已从 `wdpyfazxbg` 微应用定位并接入 `zxbg/loadXspyfazxbgInfo.do`，返回 9 个类别及 `dxzList` 课组的要求/已获/待考核学分，客户端按结构化类别展示；总学分仍以 `fa.ZDXF` 为准。

- **博雅只读**：课程库、类别筛选、课程详情、已选课程、完成统计；实测 74 门课程。macOS 页面使用课程卡片、类别菜单、详情 sheet 和统计进度条；iOS 详情补签到配置。
- **研讨室空档与预约**：日期/类别/校区筛选、容量、设备、逐日占用与可预约空档；实测 45 个空间。2026-10-19 在空档页上增加预约写路径（参与人解析、空档复核、二次确认、confirm/submit 分支、失败不自动重试）；macOS 与 iOS 均有原生表单。**真实预约写操作未验收**。
- **研究生教务**：学籍白名单摘要、培养方案章节与计划课程、成绩和考试数量；平台应用目录虽被解析，但没有对应的客户端业务流程，因此不在“学籍信息”页展示。实测 10 章方案、59 门计划课程、7 类 46 个应用。macOS 与 iOS 共用学分地图和进度状态模型。
- **数据展示口径**：执行报告 `yhpyfaxf` 是方案已认定学分，`yxxf` 是全校累计已修学分，两者分开显示；当前学期课表精确匹配到课程后显示在修，学期或课程学分未确认时显示待核对。总缺口仍按“要求 − 方案已认定”计算，在修/待考核不抵扣。类别、课组、课程分别显示状态；无法精确匹配执行层级的在修课程单独列出。空列表、字段缺失和请求失败分开显示；不展示证件号、手机号等敏感字段。

下一步建议：

1. **SPOC 课程中心只读**：课程列表、内容树、通知、文件和作业详情；不接讨论发帖/作业提交。
2. **研讨室预约真实往返**：用本人在学校页面正常预约一次，核对 `seminar/confirm` / `seminar/submit` 的成功响应、参与人校验、名额竞争、取消回查；在此之前客户端不宣称已验收。教学楼 `cgyy.buaa.edu.cn` 系统含滑块验证码，按项目红线不自动绕过，需单独评估人工完成验证码的交互方案。
3. **图书馆座位状态操作真实往返**：签到、临时离开、完全离开需要真实账号逐项验收；重点确认空 `points` 是否被接受、暂离时限、重复提交与失败文案。
4. **研究生培养环节**：开题、中期、学术报告、专业实践、学位信息等按模块继续做字段白名单。
5. **本科 BYXT**：需要本科账号继续取证。
