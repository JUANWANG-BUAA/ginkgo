# BUAA Assistant - UBAA 原项目全链路架构透视

本文档的目标：**读完这一篇，一眼看穿 UBAA 的底层设计**。从数据如何流入、如何加密、如何存储、如何请求、如何响应、如何渲染，全链路无死角。

---

## 0. 一句话总结

UBAA 是一个 **Kotlin Multiplatform 六平台客户端 + Ktor 中转服务端** 的校园服务聚合系统。客户端通过三种连接模式（直连/WebVPN/服务器中转）访问北航 14 个业务系统，服务端维护用户会话并代理请求。核心矛盾在于：跨平台抽象带来的代码膨胀和平台妥协，远超其解决的问题。

---

## 1. 系统全景图

```
┌─────────────────────────────────────────────────────────────────────┐
│                        CLIENT (6 platforms)                          │
│  Android · iOS · Desktop (JVM) · Web Wasm · Web JS · Server JAR    │
│                                                                      │
│  ┌──────────┐   ┌──────────────┐   ┌──────────────────────────┐    │
│  │ Compose  │──▶│  ViewModel   │──▶│  *Api (14 features)      │    │
│  │ UI       │   │  (15 total)  │   │  ┌─────────┐ ┌────────┐ │    │
│  │ Screens  │   │  StateFlow   │   │  │ Relay   │ │ Local  │ │    │
│  └──────────┘   └──────────────┘   │  │ Backend │ │ Backend│ │    │
│                                     │  └────┬────┘ └───┬────┘ │    │
│                                     └───────┼──────────┼──────┘    │
│                                              │          │           │
└──────────────────────────────────────────────┼──────────┼───────────┘
                                               │          │
              ┌────────────────────────────────┘          │
              │                                           │
              ▼                                           ▼
┌─────────────────────────┐              ┌──────────────────────────┐
│   UBAA SERVER (Ktor)    │              │   BUAA UPSTREAM SYSTEMS  │
│   ubaa.mofrp.top:2021   │              │                          │
│                         │              │  sso.buaa.edu.cn  (CAS)  │
│  JWT Auth               │              │  uc.buaa.edu.cn   (UC)   │
│  Redis Sessions         │              │  byxt.buaa.edu.cn (教务) │
│  Cookie Jar (Redis)     │─────────────▶│  gsmis.buaa.edu.cn(研教务)│
│  Per-user HttpClient    │              │  app.buaa.edu.cn  (成绩) │
│  14 Feature Services    │              │  booking.lib.buaa.edu.cn │
│                         │              │  bykc.buaa.edu.cn (博雅) │
│                         │              │  judge.buaa.edu.cn(希冀) │
│                         │              │  spoc.buaa.edu.cn (SPOC) │
│                         │              │  cgyy.buaa.edu.cn (场馆) │
│                         │              │  i.buaa.edu.cn    (iHome)│
│                         │              │  d.buaa.edu.cn    (WebVPN)│
└─────────────────────────┘              └──────────────────────────┘
```

---

## 2. 连接模式：请求如何路由

### 2.1 三种模式

```kotlin
enum class ConnectionMode {
    DIRECT,       // 校园网直连上游（需在校内或已连 VPN）
    WEBVPN,       // 通过 d.buaa.edu.cn WebVPN 网关（URL 重写 + AES-CFB 加密主机名）
    SERVER_RELAY  // 通过 UBAA 中转服务器（JWT 认证 + Redis 会话）
}
```

### 2.2 路由分发链

```
ScheduleApi.getTerms()
  │
  ├── backendProvider() ──▶ ConnectionRuntime.currentMode()
  │
  ├── DIRECT ──▶ LocalScheduleApiBackend
  │               └── localUpstreamUrl("https://byxt.buaa.edu.cn/...")
  │                   └── 原样返回（不重写）
  │                   └── PersistentLocalCookieStorage 管理 Cookie
  │
  ├── WEBVPN ──▶ LocalScheduleApiBackend
  │               └── localUpstreamUrl("https://byxt.buaa.edu.cn/...")
  │                   └── LocalWebVpnSupport.toWebVpnUrl()
  │                       └── "https://d.buaa.edu.cn/https/{AES-CFB加密主机名}/..."
  │                   └── PersistentLocalCookieStorage 管理 Cookie
  │
  └── SERVER_RELAY ──▶ RelayScheduleApiBackend
                        └── ApiClient (Ktor)
                            └── GET https://ubaa.mofrp.top:2021/api/v1/schedule/terms
                            └── Authorization: Bearer <JWT>
                            └── Ktor Auth 插件自动刷新 token
```

### 2.3 关键文件

| 文件 | 职责 |
|------|------|
| `shared/.../api/ConnectionRuntime.kt` | 模式管理、切换时清理所有状态 |
| `shared/.../api/core/ApiFactory.kt` | 按模式分发到 Relay 或 Local Backend |
| `shared/.../api/core/ApiClient.kt` | Relay 模式的 HTTP 客户端（Bearer token 管理） |
| `shared/.../api/local/LocalWebVpnSupport.kt` | WebVPN URL 重写（AES-CFB 加密主机名） |

---

## 3. 加密体系：7 种密码方案

UBAA 对接的北航系统使用了多种加密方案，UBAA 必须全部实现。

### 3.1 加密方案总览

| 方案 | 算法 | 密钥 | IV | 用途 | 来源系统 |
|------|------|------|-----|------|----------|
| **WebVPN 主机加密** | AES/CFB/NoPadding | `wrdvpnisthebest!` (16B) | 同密钥 | URL 中主机名加密 | d.buaa.edu.cn |
| **图书馆预约加密** | AES/CBC/NoPadding | 日期数字×2 (16B) | `ZZWBKJ_ZHIHUAWEI` | 座位预约请求体 | booking.lib.buaa.edu.cn |
| **博雅课程加密** | RSA-1024 + AES/ECB/PKCS5 | 随机 16B AES + RSA 公钥 | 无 (ECB) | 请求/响应加密 | bykc.buaa.edu.cn |
| **场馆预约签名** | MD5 | 前缀 `c640ca39...` + AppKey `8fceb735...` | - | 请求完整性签名 | cgyy.buaa.edu.cn |
| **密码哈希** | MD5 | - | - | 部分系统签名 | 各系统 |
| **SHA-1 签名** | SHA-1 | - | - | 博雅课程数据完整性校验 | bykc.buaa.edu.cn |
| **Refresh Token 哈希** | SHA-256 | - | - | Token 存储（不存原文） | UBAA 自身 |

### 3.2 WebVPN 加密详解

```
原始 URL: https://byxt.buaa.edu.cn/jwapp/sys/homeapp/...

Step 1: 提取主机名 → "byxt.buaa.edu.cn"
Step 2: AES/CFB 加密主机名
         Key = IV = "wrdvpnisthebest!"
         明文填充到 16 字节倍数 → "byxt.buaa.edu.cn" (18B → 32B with '0' padding)
         密文 = IV_hex + ciphertext_hex[:original_length*2]
Step 3: 重组 URL
         → "https://d.buaa.edu.cn/https/{encrypted_host}/jwapp/sys/homeapp/..."

安全评估: ⚠️ 密钥硬编码在客户端源码中，任何人可解密 WebVPN 流量中的主机名
```

### 3.3 博雅课程加密详解

```
请求加密流程:
1. 生成随机 16 字节 AES 密钥（从 54 字符集中选取）
2. AES/ECB/PKCS5Padding 加密 JSON 请求体
3. RSA/ECB/PKCS1Padding 加密 AES 密钥 → ak (Base64)
4. SHA-1 签名原始数据 → RSA 加密签名 → sk (Base64)
5. 发送: { encryptedData, ak, sk, ts }
6. 响应使用同一 AES 密钥加密（服务端用 RSA 私钥解密 ak 获取密钥）

RSA 公钥 (1024-bit, Base64 DER):
MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDlHMQ3B5GsWnCe7Nlo1YiG/YmH...

安全评估: ⚠️ RSA-1024 已不推荐（建议 2048+）；AES-ECB 模式不安全（相同明文产生相同密文）
```

### 3.4 图书馆预约加密详解

```
AES/CBC 加密流程:
1. 从日期字符串提取 8 位数字 → "20261013"
2. 密钥 = 数字 + 数字反转 → "20261013" + "31016202" = "2026101331016202" (16B)
3. IV = "ZZWBKJ_ZHIHUAWEI" (16B, 硬编码)
4. JSON 请求体 → PKCS7 填充 → AES/CBC/NoPadding → Base64

安全评估: ⚠️ 密钥可预测（基于日期）；IV 硬编码；无认证加密
```

### 3.5 场馆预约签名详解

```
MD5 签名流程 (CgyySigner):
1. 前缀: "c640ca392cd45fb3a55b00a63a86c618" (硬编码)
2. AppKey: "8fceb735082b5a529312040b58ea780b" (硬编码)
3. 签名载荷: prefix + path + sorted_params_concat + timestamp + " " + prefix
4. 哈希: MD5 hex digest

安全评估: ⚠️ 前缀和 AppKey 硬编码在客户端源码中；MD5 碰撞攻击可行
```

### 3.6 Refresh Token 哈希

```
SHA-256 哈希 (RefreshTokenStore):
1. 生成 32 字节随机数 → Base64url 编码 → 作为 Refresh Token
2. SHA-256(token) → 存储哈希到 Redis
3. 验证时: 对传入 token 做 SHA-256，与 Redis 中的哈希比对
4. 不存储 Token 原文 → 即使 Redis 被攻破也无法还原 Token

这是 UBAA 安全做得好的地方。
```

### 3.7 加密原语实现

```
shared/src/commonMain/kotlin/cn/edu/ubaa/api/plantform/
├── PlatformAesEcbPkcs5Padding.kt   → expect object (JVM: javax.crypto, Apple: CryptoKit, JS: WebCrypto)
├── PlatformAesCfbNoPadding.kt      → expect object
├── PlatformAesCbcNoPadding.kt      → expect object
├── PlatformRsaPkcs1Encrypt.kt      → expect object (仅加密，无解密 → 说明只有公钥)
└── PlatformMd5Hex.kt               → expect object
```

每个原语在每个平台都有独立 `actual` 实现。`LocalBykcCrypto.kt` 甚至在 commonMain 中手写了完整的 SHA-1 算法（140 行），以避免引入平台依赖。

---

## 4. 数据存储：四层存储架构

### 4.1 存储层级

```
┌───────────────────────────────────────────────────────┐
│  Layer 1: Keychain / Secure Enclave (仅 macOS/iOS)    │
│  → 本项目使用，UBAA 未使用                            │
├───────────────────────────────────────────────────────┤
│  Layer 2: Settings (com.russhwolf.settings)           │
│  → UBAA 的主要持久化方案                              │
│  → 底层: SharedPreferences(Android) / NSUserDefaults  │
│  →          (Apple) / Preferences(JS) / File(JVM)     │
│  → 存储: 密码(明文!)、Token、ClientId、课表快照       │
├───────────────────────────────────────────────────────┤
│  Layer 3: Cookie Storage (PersistentLocalCookieStorage)│
│  → 底层也是 Settings                                  │
│  → 按连接模式隔离 Cookie                              │
│  → 存储: SSO TGT、JSESSIONID、各系统会话 Cookie       │
├───────────────────────────────────────────────────────┤
│  Layer 4: Redis (仅服务端)                            │
│  → 会话元数据、Cookie Jar、Refresh Token、分布式锁    │
└───────────────────────────────────────────────────────┘
```

### 4.2 客户端存储键值清单

| Store 类 | 存储内容 | 键名模式 | 安全问题 |
|----------|----------|----------|----------|
| `CredentialStore` | 用户名、密码 | `credential_username`, `credential_password` | **P0: 明文存储** |
| `AuthTokensStore` | Access Token、Refresh Token | `mode_server_relay_auth_access_token` 等 | Token 明文，但有时效 |
| `ClientIdStore` | UUID (预登录关联) | `client_id` | 无安全风险 |
| `ScheduleSnapshotStorage` | 课表 JSON 快照 | 分块存储 (4096 字符/块) + 代际索引 | 无安全风险 |
| `GradeScoreCacheStore` | 成绩摘要 | 按模式和用户隔离 | 无安全风险 |
| `PersistentLocalCookieStorage` | 上游系统 Cookie | 按模式隔离 | Cookie 含 TGT，泄漏可冒充用户 |
| `ConnectionModeStore` | 当前连接模式 | `connection_mode` | 无安全风险 |

### 4.3 服务端 Redis 键设计

```
┌─────────────────────────────────────────────────────────────────┐
│  session:{username}          Hash    会话元数据                  │
│    ├─ name, schoolid, authenticated_at, last_activity           │
│    ├─ portal_type (undergraduate/graduate)                      │
│    ├─ generation (重新登录 +1), revision (活动更新 +1)          │
│    └─ TTL: 7 天                                                │
├─────────────────────────────────────────────────────────────────┤
│  cookies:{username}          Hash    用户 Cookie Jar            │
│    ├─ field = "domain|path|name"                                │
│    ├─ value = 序列化的 Cookie (9 字段, \x1F 分隔)              │
│    │   格式: name\x1Fvalue\x1Fdomain\x1Fpath\x1FexpiresAt      │
│    │         \x1Fsecure\x1FhttpOnly\x1FmaxAge\x1FcreatedAt     │
│    └─ TTL: 7 天 (与 session 同步)                              │
├─────────────────────────────────────────────────────────────────┤
│  cookies:prelogin_{clientId} Hash    预登录 Cookie              │
│    └─ TTL: 5 分钟                                              │
├─────────────────────────────────────────────────────────────────┤
│  refresh:user:{username}     Hash    Refresh Token 记录         │
│    ├─ hash, issuedAt, expiresAt                                 │
│    └─ TTL: 7 天                                                │
├─────────────────────────────────────────────────────────────────┤
│  refresh:index:{tokenHash} String   反向索引                    │
│    ├─ value = username                                          │
│    └─ TTL: 7 天                                                │
├─────────────────────────────────────────────────────────────────┤
│  lock:{scope}:{key}          String  分布式锁                   │
│    ├─ value = UUID token (Lua 脚本释放)                        │
│    └─ TTL: 20 秒                                               │
└─────────────────────────────────────────────────────────────────┘
```

### 4.4 Cookie Jar 两阶段写入

```
登录阶段 (writeThrough = false):
  Cookie → 内存 cache → 标记 dirty → 不写 Redis
  (批量缓冲，避免登录过程中频繁 Redis 写入)

登录成功后 commitSession():
  flush() → 全量写入 Redis
  setWriteThrough(true) → 后续每次 Cookie 变更立即写 Redis

读取阶段:
  首次 get() → 从 Redis 全量加载到内存
  后续 get() → 直接读内存
  每 5 秒 → 如果 writeThrough=true，从 Redis 重新同步
```

---

## 5. 认证流程：端到端数据流

### 5.1 中转模式登录（完整链路）

```
┌─────────┐     ┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│  Login   │     │  UBAA       │     │  sso.buaa    │     │  uc.buaa    │
│  Screen  │     │  Server     │     │  .edu.cn     │     │  .edu.cn    │
└────┬─────┘     └──────┬──────┘     └──────┬───────┘     └──────┬──────┘
     │                  │                    │                     │
     │ 1. POST /auth/preload {clientId}      │                     │
     │─────────────────▶│                    │                     │
     │                  │ 2. 创建 PreLoginCandidate              │
     │                  │    GET /login → 获取 execution token    │
     │                  │───────────────────▶│                     │
     │                  │◀───────────────────│                     │
     │ 3. {captchaRequired, execution}       │                     │
     │◀─────────────────│                    │                     │
     │                  │                    │                     │
     │ 4. POST /auth/login {username, password, execution, clientId}
     │─────────────────▶│                    │                     │
     │                  │ 5. 获取 per-user Mutex                  │
     │                  │ 6. 尝试复用已有 session → 失败          │
     │                  │ 7. 获取分布式锁 (Redis SET NX PX)       │
     │                  │ 8. 获取信号量 (bulkhead, max=6)         │
     │                  │ 9. POST /login {username, password}     │
     │                  │───────────────────▶│                     │
     │                  │◀───────────────────│                     │
     │                  │ 10. 检查 302 + CASTGC Cookie            │
     │                  │ 11. GET uc.buaa.edu.cn/api/login?...    │
     │                  │────────────────────────────────────────▶│
     │                  │◀────────────────────────────────────────│
     │                  │ 12. GET uc.buaa.edu.cn/api/uc/status    │
     │                  │────────────────────────────────────────▶│
     │                  │◀────────────────────────────────────────│
     │                  │ 13. commitSession() → Redis 写入        │
     │                  │ 14. issueLoginTokens() → JWT + Refresh  │
     │ 15. {user, accessToken, refreshToken, expiresAt}          │
     │◀─────────────────│                    │                     │
     │                  │                    │                     │
     │ 16. 保存 Token → AuthTokensStore      │                     │
     │ 17. 保存密码 → CredentialStore (明文!) │                     │
     │ 18. 切换到主界面                       │                     │
```

### 5.2 Token 生命周期

```
Access Token:  JWT, 30 分钟有效期
  ├─ payload: {sub: username, iss: "UBAA", aud: ..., iat, exp}
  ├─ 每次请求自动附加 (Ktor Auth 插件)
  └─ 401 时自动触发 refresh

Refresh Token: 32 字节随机数, SHA-256 哈希后存储, 7 天有效期
  ├─ 旋转策略: 每次 refresh 废弃旧 token, 发放新 token
  ├─ Redis 双键: refresh:user:{username} + refresh:index:{hash}
  └─ 失败时清除所有 Token

Session: 7 天有效期
  ├─ 每 5 分钟清理过期 session
  ├─ 重新登录 → generation +1 (旧 session 失效)
  └─ 活动更新 → revision +1
```

---

## 6. 数据模型：17 个 DTO 文件

### 6.1 DTO 全景

```
shared/src/commonMain/kotlin/cn/edu/ubaa/model/dto/
├── Auth.kt          → LoginRequest, LoginResponse, UserData, CaptchaInfo, TokenRefresh*
├── Schedule.kt      → Term, Week, CourseClass, WeeklySchedule, TodayClass, SectionTime
├── Grade.kt         → Grade, GradeData, BuaaScoreResponse, BuaaScoreCourse
├── GraduateSchedule.kt → 研究生课表 (GSMIS HTML 解析中间结构)
├── GsmisSchedule.kt → GSMIS 课表适配
├── Exam.kt          → 考试安排
├── UserInfo.kt      → 用户详细信息
├── Signin.kt        → 签到课程、签到请求
├── Spoc.kt          → SPOC 作业
├── Judge.kt         → 希冀作业
├── Bykc.kt          → 博雅课程 (含加密序列化)
├── Cgyy.kt          → 场馆预约
├── LibBook.kt       → 图书馆座位预约 (含加密请求体)
├── Ygdk.kt          → 阳光体育
├── Ihome.kt         → iHome 诉求广场
├── Classroom.kt     → 教室查询
└── Evaluation.kt    → 课程评价
```

### 6.2 上游字段命名问题

UBAA 的 DTO 直接使用上游系统的字段名，通过 `@SerialName` 映射：

```kotlin
// Grade.kt — 成绩 DTO
@Serializable
data class Grade(
    @SerialName("WID") val id: String?,           // 上游: WID (无意义缩写)
    @SerialName("XNXQDM") val termCode: String?,  // 上游: XNXQDM (学年学期代码)
    @SerialName("KCM") val courseName: String?,    // 上游: KCM (课程名)
    @SerialName("XF") val credit: Double?,         // 上游: XF (学分)
    @SerialName("XSZCJ") val score: String?,       // 上游: XSZCJ (显示成绩)
    @SerialName("JD") val gradePoint: String?,     // 上游: JD (绩点)
    @SerialName("SFJG_DISPLAY") val passed: String?, // 上游: 是否及格
)
```

**问题**：DTO 字段名被上游绑定，上游改名则客户端崩溃。没有稳定的领域模型层。
（注：本表展示的 `Grade` DTO 在 UBAA 中是死代码，在用的成绩模型是 `BuaaScoreCourse`，见 §6.3 更正版；`@SerialName` 绑定上游字段的问题在 `BuaaScoreCourse`、`GsmisSchedule` 等在用 DTO 中同样存在。）

### 6.3 成绩系统的数据源（更正版）

> **更正（2026-10-13）**：本节旧版记载了「数据源 A: byxt `grade.do`」。经核对，`Grade.kt` 中确有一套 `WID/XNXQDM/KCM/XSZCJ` 大写拼音字段的 DTO（`GradeResponseDatas.cxwdcj` 结构），但它是**死代码**——全仓库（shared 与 server）无任何引用。服务端与本地两条链路实际都只使用 buaascore。

```
在用数据源: app.buaa.edu.cn (北航成绩应用)
  └── GET+POST 同一 URL /buaascore/wap/default/index（GET 激活会话，POST 表单 xq/year）
  └── 返回: {e: 0, m: "", d: {key: BuaaScoreCourse}}
  └── 字段: kcmc, kch, xf(JsonElement), kccj(JsonElement), fslx, kclx

问题: BuaaScoreCourse 的 credit 和 score 是 JsonElement 而非具体类型
      因为上游有时返回数字、有时返回字符串，需要运行时判断
```

---

## 7. 服务端架构：会话隔离模型

### 7.1 每个用户一个 HttpClient

```kotlin
// SessionManager.kt
data class UserSession(
    val username: String,
    val httpClient: HttpClient,     // ← 每个用户独立的 HTTP 客户端
    val cookieStorage: ManagedCookieStorage,  // ← Redis -backed
    @Volatile var lastActivity: Instant,
    @Volatile var portalType: PortalType?,
    @Volatile var generation: Long,
    @Volatile var revision: Long,
)
```

**设计意图**：Cookie 隔离——用户 A 的 `JSESSIONID` 不会泄漏到用户 B 的请求中。

**代价**：每个活跃用户占用一个 CIO HttpClient 实例（`maxConnectionsCount=16`, `maxConnectionsPerRoute=8`）。6 个并发登录限制 (`loginMaxConcurrency`) 防止上游过载。

### 7.2 并发控制矩阵

```
┌────────────────────────────────────────────────────────────────┐
│  层级              │ 机制              │ 粒度                   │
├────────────────────┼───────────────────┼────────────────────────┤
│  登录串行化        │ per-user Mutex    │ 同一用户同时只能一个登录│
│  全局登录并发限制  │ Semaphore(6)      │ 全服务器最多 6 个新登录 │
│  分布式锁          │ Redis SET NX PX   │ 跨实例登录互斥          │
│  Session 恢复      │ per-user Mutex    │ 同一用户同时只能一个恢复│
│  Session 校验去重  │ CompletableDeferred│ 同一用户并发校验共享结果│
│  Token 刷新        │ Mutex (客户端)    │ 同一客户端并发刷新合并  │
│  Redis Cookie 操作 │ per-user Mutex    │ 同一用户 Cookie 串行化  │
│  写操作 (iHome)    │ mutationMutex     │ 关注/支持操作串行化     │
└────────────────────────────────────────────────────────────────┘
```

### 7.3 定时清理

```kotlin
// Application.kt
val cleanupScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
cleanupScope.launch {
    while (isActive) {
        delay(5.minutes)
        sessionManager.evictExpired()        // 清除过期 session
        sessionManager.evictPreLogin()       // 清除过期预登录
        bykcService.evictExpiredClients()    // 清除各功能缓存
        cgyyService.evictExpiredClients()
        // ... 14 个功能服务的缓存清理
    }
}
```

---

## 8. 错误传播链

```
网络层 (Ktor)
  │  HttpRequestTimeoutException, SerializationException, HttpException
  ▼
safeApiCall / toUserFacingApiException()   [客户端]
StatusPages + per-route try/catch          [服务端]
  │  超时 → "请求超时，请稍后重试"
  │  401 → "登录已过期，请重新登录"
  │  422 → CaptchaRequiredResponse
  │  502 → "上游服务不可用"
  │  500 → "服务器内部错误"
  ▼
Result<T> (success / failure)
  │  成功 → 数据
  │  失败 → ApiCallException(code, message)
  ▼
ViewModel
  │  _uiState.update { it.copy(error = exception) }
  ▼
View (Compose)
  │  error?.let { ShowSnackbar(it.message) }
  │  code == "unauthenticated" → 导航到登录页
```

**服务端错误码清单**（~50+ 个）：
- 认证: `invalid_token`, `unauthenticated`, `invalid_credentials`, `captcha_*`
- 功能: `bykc_*`, `cgyy_*`, `spoc_*`, `judge_*`, `libbook_*`, `ygdk_*`, `schedule_error`, `exam_error`, `grade_error`
- iHome: `ihome_auth`, `ihome_disabled`, `ihome_protocol`, `ihome_upstream`, `ihome_error`
- 通用: `internal_server_error`, `invalid_request`

---

## 9. 14 个功能模块的 API 对照表

| # | 功能 | 上游域名 | 认证方式 | 加密 | 数据格式 | 服务端路由 |
|---|------|----------|----------|------|----------|------------|
| 1 | 认证 | sso.buaa.edu.cn | CAS TGT/ST | 无 | HTML | /api/v1/auth/* |
| 2 | 用户 | uc.buaa.edu.cn | SSO Cookie | 无 | JSON | /api/v1/user/info |
| 3 | 课表 | byxt.buaa.edu.cn | SSO→JSESSIONID | 无 | JSON | /api/v1/schedule/* |
| 4 | 成绩 | app.buaa.edu.cn | SSO→JSESSIONID | 无 | JSON | /api/v1/grade/list |
| 5 | 考试 | byxt.buaa.edu.cn | SSO→JSESSIONID | 无 | JSON | /api/v1/exam/list |
| 6 | 签到 | iclass.buaa.edu.cn | SSO→JSESSIONID | 无 | JSON+HTML | /api/v1/signin/* |
| 7 | 教室 | app.buaa.edu.cn | SSO→JSESSIONID | 无 | JSON | /api/v1/classroom/query |
| 8 | 图书馆 | booking.lib.buaa.edu.cn | CAS→LIBSESSION | AES-CBC | JSON | /api/v1/libbook/* |
| 9 | 博雅 | bykc.buaa.edu.cn | 独立登录 | RSA+AES-ECB | JSON(加密) | /api/v1/bykc/* |
| 10 | 希冀 | judge.buaa.edu.cn | SSO→JSESSIONID | 无 | HTML | /api/v1/judge/* |
| 11 | SPOC | spoc.buaa.edu.cn | CAS→Token | 无 | JSON | /api/v1/spoc/* |
| 12 | 场馆 | cgyy.buaa.edu.cn | 独立登录+签名 | HMAC 签名 | JSON | /api/v1/cgyy/* |
| 13 | 阳光体育 | ygdk.buaa.edu.cn | SSO Cookie | 无 | JSON | /api/v1/ygdk/* |
| 14 | iHome | i.buaa.edu.cn | CAS→JWT | 无 | JSON | /api/v1/ihome/* |

---

## 10. 关键设计决策的反思

### 10.1 密码明文存储 (P0)

```kotlin
// CredentialStore.kt — 实际代码
private val settings = Settings()
fun saveCredentials(username: String, password: String) {
    settings.putString("credential_username", username)
    settings.putString("credential_password", password)  // ← 明文!
}
```

**底层**: `Settings` 在 Android 上是 `SharedPreferences` (XML 文件)，在 JVM 上是 `~/.ubaa/settings.properties`。任何能读取文件的进程都能获取密码。

**应该**: macOS 用 Keychain (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`)，Android 用 EncryptedSharedPreferences。

### 10.2 WebVPN 密钥硬编码 (P1)

```kotlin
// LocalWebVpnSupport.kt
private const val keyText = "wrdvpnisthebest!"  // ← 密钥 = IV
private val keyBytes = keyText.encodeToByteArray()
private val ivBytes = keyText.encodeToByteArray()
```

这是北航 WebVPN 协议本身的限制，不是 UBAA 的 bug。但 UBAA 没有对此做任何风险提示。

### 10.3 成绩字段类型不一致

```kotlin
// BuaaScoreCourse.kt
@SerialName("xf") val credit: JsonElement? = null,     // ← 有时是数字，有时是字符串
@SerialName("kccj") val score: JsonElement? = null,     // ← 同上
```

使用 `JsonElement` 作为类型是一种 workaround，但把类型判断推迟到了运行时。应该在解析层统一转换为具体类型。

### 10.4 课表快照的崩溃安全写入

```kotlin
// ScheduleSnapshotStorage.kt — 这是 UBAA 做得好的地方
// 写入流程:
// 1. 将 JSON 分割为 4096 字符的块
// 2. 写入新块 (chunk_0_new, chunk_1_new, ...)
// 3. 更新索引指针 (generation + 1)
// 4. 删除旧块
//
// 如果写入过程中崩溃:
// - 索引仍指向旧块 → 旧数据完整
// - 新块不完整但未被索引 → 不影响读取
```

### 10.5 iHome 的 12 步 CAS 跳转

```
iHome 登录链:
1. GET i.buaa.edu.cn → 302 到 SSO
2. GET sso.buaa.edu.cn/login?service=i.buaa.edu.cn → 302 回 iHome with ticket
3. GET i.buaa.edu.cn/api/authLogin?ticket=ST-xxx → 302 到 iHome Web
4. GET i.buaa.edu.cn/web/#/login?type=0&token=xxx → 解析 token
5. 后续请求携带 token

最多跟踪 12 次重定向，每次都要检查是否到达终点
如果上游改了任何一步的重定向逻辑，整个链路断裂
```

### 10.6 依赖注入：无框架，纯手工

```kotlin
// 没有 Koin/Dagger，使用构造函数默认参数 + 全局单例
class AuthService(
    private val sessionManager: SessionManager = GlobalSessionManager.instance,
    private val refreshTokenService: RefreshTokenService = GlobalRefreshTokenService.instance,
    private val loginMetricsSink: LoginMetricsSink = NoOpLoginMetricsSink,
)

// 全局单例使用 double-checked locking
object GlobalSessionManager {
    @Volatile private var current: SessionManager? = null
    val instance: SessionManager get() {
        current?.let { return it }
        return synchronized(this) { current ?: SessionManager().also { current = it } }
    }
}
```

**优点**: 零依赖，简单直接。
**缺点**: 测试时难以替换（需要修改全局状态），单例生命周期不可控。

---

## 11. 从本项目视角的设计决策清单

| 维度 | UBAA 的做法 | 本项目 (BUAA Assistant) 的做法 | 理由 |
|------|-------------|-------------------------------|------|
| 平台 | 6 平台 KMP | macOS 原生 Swift | 不做跨平台妥协 |
| 连接模式 | 3 种 × 14 功能 = 42 个 Backend | 仅直连 | 不做 WebVPN 隧道，不做中转 |
| 密码存储 | 明文 Settings | Keychain | 硬件加密，系统级安全 |
| 凭据清理 | 切换模式时部分残留 | 登出时全量清除 | 不留残余 |
| Token 刷新 | Ktor Auth 插件 + Mutex | actor + 双重检查 | 更明确的并发语义 |
| 上游字段映射 | @SerialName 直接绑定 | 独立 Adapter 层 | 上游变化不影响领域模型 |
| 错误处理 | 50+ 错误码，客户端/服务端各一份 | 统一 AppError 枚举 | 一处定义，全链路使用 |
| 存储 | Settings (明文) | SwiftData + Keychain | 结构化存储 + 安全存储 |
| Cookie | PersistentLocalCookieStorage (Settings) | HTTPCookieStorage (系统) | 系统管理，自动过期清理 |
| DI | 构造函数默认参数 + 全局单例 | 构造函数注入 + EnvironmentObject | 可测试，生命周期清晰 |
| 加密 | expect/actual × 5 算法 | CryptoKit（GCM/ChaChaPoly）+ CommonCrypto（AES-CBC，图书馆预约） | 原生 API；注意 CryptoKit 不支持 CBC，见 API.md §5.3 |
| 状态管理 | MutableStateFlow + loadedOnce 标志 | @Observable + async/await | SwiftUI 5 原生方案 |
| 并发控制 | Mutex + Semaphore + CompletableDeferred | Swift Actor | 编译器保证串行访问 |

---

## 12. 一张图看穿全链路

```
用户输入学号密码
    │
    ▼
LoginView ──▶ AuthViewModel.login()
    │
    ▼ (viewModelScope.launch)
AuthService.login()
    │
    ├── DIRECT/WEBVPN ──────────────────────────────────────────┐
    │   LocalConnectionAuth                                     │
    │   ├── GET sso.buaa.edu.cn/login → 解析 execution         │
    │   ├── POST sso.buaa.edu.cn/login → 获取 CASTGC Cookie   │
    │   ├── PersistentLocalCookieStorage 保存 Cookie            │
    │   └── 返回 UserData                                       │
    │                                                            │
    ├── SERVER_RELAY ──────────────────────────────────────────┐│
    │   RelayAuthServiceBackend                                ││
    │   ├── POST /api/v1/auth/login ──────────────────────┐   ││
    │   │   UBAA Server                                   │   ││
    │   │   ├── per-user Mutex                            │   ││
    │   │   ├── Redis 分布式锁                            │   ││
    │   │   ├── Semaphore(6)                              │   ││
    │   │   ├── GET sso.buaa.edu.cn/login                 │   ││
    │   │   ├── POST sso.buaa.edu.cn/login                │   ││
    │   │   ├── GET uc.buaa.edu.cn/api/login              │   ││
    │   │   ├── GET uc.buaa.edu.cn/api/uc/status          │   ││
    │   │   ├── commitSession() → Redis                   │   ││
    │   │   ├── JWT 签发 (30min access + 7d refresh)      │   ││
    │   │   └── 返回 LoginResponse ──────────────────────┘   ││
    │   └── AuthTokensStore 保存 Token                        ││
    │                                                          ││
    ▼                                                          ▼▼
CredentialStore 保存密码 (⚠️ 明文)
    │
    ▼
App.kt 观察 isLoggedIn → 切换到 MainAppScreen
    │
    ▼
ScheduleViewModel.ensureScheduleLoaded()
    │
    ▼
ScheduleApi.getTerms()
    │
    ├── DIRECT ──▶ GET byxt.buaa.edu.cn/.../schoolCalendars.do
    ├── WEBVPN ──▶ GET d.buaa.edu.cn/https/{AES加密host}/...
    └── RELAY  ──▶ GET ubaa.mofrp.top/api/v1/schedule/terms
                    │
                    └── Server: sessionManager.requireSession()
                        → HttpClient (per-user, Cookie from Redis)
                        → GET byxt.buaa.edu.cn/...
                        → 解析 JSON → 返回 Term 列表
    │
    ▼
ScheduleRepository.onlineOrSaved()
    ├── 成功 → SwiftData/ScheduleStore 缓存
    └── 失败 → 读取本地快照
    │
    ▼
ScheduleView 渲染课表
```

---

## 13. 安全审计清单

| # | 问题 | 严重性 | 位置 | 本项目对策 |
|---|------|--------|------|-----------|
| 1 | 密码明文存储 | **P0** | `CredentialStore` | Keychain |
| 2 | JWT 密钥硬编码回退 | **P0** | `JwtUtil.kt` | 无服务端 |
| 3 | ~~调试模式 Cookie 日志泄漏~~ **更正（2026-10-13 核查不属实）**：现行代码 Ktor Logging 固定 `LogLevel.INFO`（`LocalConnectionAuth.kt:312`），INFO 级**不输出请求头**，Cookie 不会进日志；真实问题反而是「Logging 常开无开关、三个客户端口径不一」（见 §15） | ~~P1~~ | `LocalConnectionAuth` | OSLog `.private` |
| 4 | WebVPN 密钥硬编码 | **P1** | `LocalWebVpnSupport` | 不做 WebVPN |
| 5 | RSA-1024 密钥过短 | **P2** | `LocalBykcCrypto` | 上游限制，无法改变 |
| 6 | AES-ECB 模式不安全 | **P2** | `LocalBykcCrypto` | 上游限制 |
| 7 | AES-CBC IV 硬编码 | **P2** | `LocalLibBookCrypto` | 上游限制 |
| 8 | 成绩字段 JsonElement 类型 | **P3** | `BuaaScoreCourse` | Adapter 层转换 |
| 9 | loadedOnce 非 @Volatile | **P3** | 多个 ViewModel | @Observable 替代 |
| 10 | GlobalScope 无生命周期 | **P3** | 无（已全用 viewModelScope） | Swift Concurrency |

---

## 14. 本项目必须避免的陷阱

1. **不要复制 UBAA 的 DTO 结构**——上游字段名（`KCM`, `XF`, `XSZCJ`）不应出现在领域模型中
2. **不要复制 UBAA 的三模式架构**——只做直连，WebVPN 需求通过系统代理解决
3. **不要复制 UBAA 的 expect/actual 加密**——macOS 原生直接用 CryptoKit
4. **不要复制 UBAA 的 Settings 存储**——SwiftData + Keychain 更安全更高效
5. **不要复制 UBAA 的 HTML 解析逻辑**——每个系统的 HTML 结构都可能变化，需要独立的 Adapter + 快照回归测试
6. **不要复制 UBAA 的 per-user HttpClient**——直连模式不需要服务端会话隔离
7. **不要复制 UBAA 的 Redis 依赖**——纯客户端应用，本地存储即可
8. **不要复制 UBAA 的「等级绩点映射」**——GPA 计算埋在 UI 文件（`GradeScreen.kt:312-345`）：百分制公式 `4 - 3×(100-x)²/1600` 是北航官方已知形态，但等级制映射（优 4.0 / **良 3.5 / 中 2.8 / 及格 1.7**）查无官方出处；`GradeScreenLogicTest` 虽有覆盖，但测试锁定的只是**假设值**。本项目接入成绩模块时，等级映射必须先与教务官方规定核对（TESTING.md §2.2 已有此警告）。

---

## 15. 异常处理与日志核查（2026-10-13）

> 应「部分功能显示错误 / 没有异常处理和日志」的指控逐条核查。方法：全仓 grep + 抽样读码 + git 历史。结论：**指控部分属实**——错误处理框架整体完善（「没有做异常处理」这一说法过重），但存在一个用户可见的功能性错误、五处静默吞异常、以及客户端日志基础设施完全缺失。

### 15.1 核查结论总表

| # | 指控拆解 | 结论 | 证据 |
|---|----------|------|------|
| 1 | 客户端没有日志 | **属实** | shared/composeApp 无任何日志框架（无 kermit/napier/sentry，`libs.versions.toml` 仅 server 有 logback）；唯一「日志」是 Ktor Logging 插件 INFO 级常开。server 端达标（logback + CallLogging + requestId MDC，`Application.kt:129-135`） |
| 2 | Logging 口径不一（核查中发现） | **属实** | relay 客户端 INFO（`ApiClient.kt:52`）、本地客户端 INFO（`LocalConnectionAuth.kt:312`）、iHome 客户端 NONE（`IhomeUpstreamClient.kt:24`）——三处三种配置，无统一封装与开关 |
| 3 | 没有做异常处理 | **大部分不属实** | 错误处理框架完整：`safeApiCall` / `toUserFacingApiException` / `ApiCallException` / 每个 ViewModel 的 error 态、server StatusPages 全局兜底。68 处 `runCatching` 绝大多数是合理的防御性解析（日期/URL 解析失败返回 null，上层处理） |
| 4 | 局部静默吞异常 | **属实（5 处）** | 空 `catch (_: Exception) {}`：`AuthApi.kt:222`、`LoginStatsReporter.kt:31`（指标上报，可辩护）、server `ClassroomClient.kt:51`、`BykcService.kt:229`、`BykcClient.kt:86` |
| 5 | 部分功能显示错误 | **属实（1 例现存 + 历史多例已修）** | 现存：研究生直连查成绩必然失败，兜底 catch 把真实原因（学期码格式不被解析）吞掉，永远显示「成绩查询失败，请稍后重试」（`LocalGradeApi.kt:56` + §6.3 学期码缺口）——误导性文案；历史：2026-05 以来 11+ 个修复提交（iHome WebVPN 登录循环、课表在线加载与本地化、研究生中转回退、WebVPN 签到路径、评教 payload、会话恢复丢失等），均已修复 |
| 6 | GPA 显示正确性存疑 | **风险属实** | 等级制映射无官方出处、测试只锁假设值（§14 第 8 条）；另 `calculateGradeStatistics` 的 `courseCount = grades.size` 包含被跳过的非数值课程，与实际参与统计数不一致（轻微显示不一致） |
| 7 | 「调试模式输出完整 Cookie header」 | **不属实** | 见 §13 表第 3 行更正：Ktor Logging 固定 INFO 级，不输出请求头 |

### 15.2 对本项目的直接教训

1. **客户端日志从第一行代码就要有**：统一 OSLog 封装（`Logger(subsystem:category:)`），敏感字段 `.private`；禁止裸 `print`；所有 catch 至少留一条日志再决定吞或抛——对应 ARCHITECTURE.md §9.2.1 对策，本项目升级为硬性要求（并入 §4 合并审查清单）。
2. **兜底 catch 必须区分「预期失败」与「程序缺陷」**：研究生成绩这类「输入格式不支持」应给出可行动的具体文案（提示身份/学期数据异常），而不是通用「稍后重试」。
3. **纯计算逻辑（绩点映射等）不得埋在 UI 文件**：独立模块 + 以官方文件为准的映射表 + 黄金文件测试。
4. **写操作路径吞异常尤其危险**（BykcClient/ClassroomClient 的空 catch 均邻近写路径）：本项目写操作失败必须显式报错并保留「状态未确认」提示（API.md §9 的既定规则）。
