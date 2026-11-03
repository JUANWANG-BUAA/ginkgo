# UBAA 原源码执行、请求差分与版本回归证据（2026-11-03）

本轮把参考从“读过源码”推进到实际运行固定 UBAA 源码，并保存双实现请求。**仍不能签署全协议 100% 对齐或真实故障已修复**：本轮覆盖两个认证阶段场景、一个 WebVPN 附加认证场景和六个业务读取场景；其他分支、Android 网络引擎和用户故障现场未被这些实验覆盖。真实账号、学校请求、应用/模拟器启动和真实写操作均未执行。

## 固定参考与可复现执行

- UBAA：`e8a397fcb35a68147eee65a94c66ffb84e2f09fe`，从本地仓库 `git archive` 提取该提交的 `shared/src` 到临时目录；业务实现和原测试不改。此提交与用户在用 UBAA 安装包的对应关系未获确认。
- Kotlin `2.3.20`、Ktor `3.4.1`、serialization `1.10.0`、datetime `0.7.1`、coroutines `1.10.2`、settings `1.3.0`，与参考版本目录一致。使用 JDK 21、Gradle 9.4.1，仅构建 JVM target；不宣称原 Android 工程构建通过。
- 隔离工程 `scripts/ubaa-reference` 省去与本任务无关的 Android/iOS/JS 配置及 BuildKonfig 插件，以本地常量 `offline-reference` 和 `https://invalid.invalid` 代替生成的版本/中转地址；学校认证、业务、Cookie 和 Ktor 实现保持原文。测试设置为内存合成存储，JVM Preferences 也指定临时目录。
- 新探针经 JVM 反射调用原文私有 `buildLocalUpstreamClient`，仅把其引擎参数替换为 MockEngine，保留原 Cookie/JSON/超时/日志配置；不另写一套参考客户端配置。原生 25 项测试仍沿用各自原有 mock 工厂。
- 先单独从公开 Maven/Gradle 仓库解析依赖，此阶段不运行测试；之后 `--offline` 编译/测试，并使用 macOS `sandbox-exec` 拒绝非本机网络。沙箱对公共 Maven 域名的 curl 检查返回域名解析失败。Gradle 本机进程通信仍获准，测试的学校响应由 MockEngine/HttpTransport 内存返回。

命令（`JAVA_HOME` 指向 JDK 21，`gradle` 指向本机 Gradle 9.4.1）：

```sh
python3 scripts/check-ubaa-reference.py \
  --ubaa-root /path/to/UBAA --gradle /path/to/gradle \
  --output docs/_audit/2026-11-03-ubaa-wire-evidence.json
```

冷环境可先追加 `--prepare-dependencies`，该选项明确允许公开构建依赖下载；学校访问仍由测试阶段沙箱禁止。脚本缺依赖、构建失败、测试失败、跳过、缺结果时均拒绝通过；业务字段存在差异默认失败。`--observe-differences` 仅供诊断，不把不同结果写成通过。历史版本的已知失败按独立矩阵报告，不冒充产品测试全绿。

## 实际执行与修正前后证据

UBAA 原生 `LocalAuthServiceBackendTest`（6）、`LocalAuthSessionStoreTest`（1）、`ConnectionRuntimeTest`（2）、`LocalSigninApiBackendTest`（8）、`LocalScheduleApiBackendTest`（5）、`LocalLibBookApiBackendTest`（3）全部通过，共 25 项。另加 3 项认证探针和 1 项业务采集测试，共 29 项通过。原生图书馆测试包含合成预约/取消，所有请求仍仅在 MockEngine 内返回，未产生学校写入。

业务采集测试使用共同的 `business-responses.json`，分别调用 UBAA 的 `ScheduleApi.getTerms`、`SigninApi.getTodayClasses`、`LocalLibBookApiBackend.getLibraries`，以及当前 Ginkgo 的共享 `load_grade_terms`（调用 `fetch_terms`，与课表同源）、`load_checkin_on_date`、`load_library_venues`。双方注入已登录的合成身份，**不把业务测试中的身份注入算作真实登录通过**。日期由参考运行记录后传给 Rust；本次签到为成功空列表，学期和图书馆为非空列表。

| 场景 | 双方请求数 | 修正前不同字段组 | 修正后不同字段组 |
| --- | --- | --- | --- |
| 直连本科探测及学期 | 2 / 2 | 2 个 headers 组 | 0 |
| 直连签到入口、app session、当天查询 | 3 / 3 | 3 个 headers 组 | 0 |
| 直连图书馆 CAS、token、场馆 | 3 / 3 | 3 个 headers 组 | 0 |
| WebVPN 本科探测及学期 | 2 / 2 | 2 个 headers 组 | 0 |
| WebVPN 签到入口、app session、当天查询 | 3 / 3 | 3 个 headers 组 | 0 |
| WebVPN 图书馆 CAS、token、场馆 | 3 / 3 | 3 个 headers 组 | 0 |

合计双方各 16 条请求。完整合成请求保存在 [修正前 JSON](2026-11-03-ubaa-wire-before.json) 与 [修正后 JSON](2026-11-03-ubaa-wire-evidence.json)，包含参考提交、合成响应摘要、请求方法、URL、头、body 和结果数量。修正由真实执行到的差异驱动：

1. UBAA `buildLocalUpstreamClient` 安装 ContentNegotiation，实际 Ktor 请求追加 `application/json` Accept。静态只复制 `applyScheduleHeaders` / `applyHeaders` 会遗漏这一步；签到原 Rust 头还与参考不同。现按已采集值对齐本科探测/查询、签到读取和图书馆公共头。
2. Rust URL 解析器把 `https://booking.lib.buaa.edu.cn` 的空路径规范化为 `/`；UBAA `LocalWebVpnSupport.toWebVpnUrl` 保留空路径，导致 WebVPN 图书馆 Origin/Referer 原先多一个斜杠。现保留空路径与显式 `/` 的区别；带路径的 URL 仍保留原路径，新增合成回归。

本轮未证明上述请求头差异会被学校拒绝，**不将它们认定为用户掉线的原因**。修正前证据已实际捕获差异，修正后沿用相同响应文件的 SHA-256；并非修改预期以隐藏不同。共享响应位于 `rust/crates/ginkgo_upstream/tests/data/ubaa-business-responses.json`；从实际 Kotlin 采集结果固化 `ubaa-business-wire.json`，日期模板化，加入常规 Rust 测试 `reference_business_wire_capture`，因此普通本地门禁/CI 无需 Kotlin 也会检查这些独立预期。更新 golden 需重新执行固定参考并审查；常规门禁不会自动重写它。

字段比较对头名小写化，对 query/form 的重复字段保留并排序，JSON 按值比较；Cookie 对顺序规范化。原始请求仍完整保留。采集点分别是 Ktor MockEngine 的准备后请求和 Ginkgo 的 HttpRequest 模型，未包含 CIO/reqwest/Android 引擎后加的默认 UA、压缩、连接头、TLS、HTTP 版本等线级行为。结果仅比较数量，未声称全部 DTO 字段相等。本轮六个业务场景没有响应 Cookie，不覆盖 Cookie 过期、SameSite、账号切换及持久化。

输入校对中，新增场景初稿漏了 UBAA `TermResponse` 必需的 nullable `msg` 字段，导致解码失败后退到未配置的研究生响应；测试确实失败。按原 DTO 和原生测试补入 `msg:null` 后重新运行，未修改 UBAA 实现或放宽成功断言。这次测试输入错误不算产品缺陷，后续请求修正前后使用同一份已校正输入。

## 历史版本与 UBAA 的直接执行对照

`check-ubaa-reference.py` 同时运行 `check-history-session-probes.py`，将固定 UBAA 的实际阶段序列与各标签比对。此处仅规范化方法阶段/路线及成功/错误；没有把阶段相同称为请求字节相同。

| 源码 | 必须消费服务票据的合成场景 | UC 503 合成场景 |
| --- | --- | --- |
| 固定 UBAA | CAS GET → POST → 服务回调 → UC 激活 → UC 状态；成功 | CAS GET → POST → UC 激活 → UC 状态；返回错误 |
| Beta.3 / Beta.4 | 与 UBAA 上述阶段、结果一致 | 与 UBAA 上述阶段、结果一致 |
| Beta.5 | 同上 | **错误发布 SignedIn** |
| Beta.6 | **省掉服务回调，模拟 UC 10600，登录失败** | **错误发布 SignedIn** |
| Beta.7 | **省掉服务回调，模拟 UC 10600，登录失败** | 返回错误 |
| 当前工作树 | 与 UBAA 上述阶段、结果一致 | 与 UBAA 上述阶段、结果一致 |

另一个已执行的 Beta.7 冷恢复探针：实际 WebVPN 登录成功却保存 Automatic 偏好；冷恢复从直连 UC 开始，在模拟 10600 下删除快照/退出，若记住密码则额外密码登录。当前工作树保存 WebVPN，恢复只请求网关 UC 且不提交密码。详细输入前提与观察见 [历史复现](2026-11-03-beta-history-offline-reproduction.md)。这些是**已复现的源码缺陷和条件性行为差异**；本次没有用户设备的对应路线、启动阶段或响应证据，不能宣称它们穷尽或唯一解释真实故障。测试 panic 是断言失败，未取得 Android 进程崩溃堆栈。

## 不能机械合并的参考差异

新探针实际执行固定 UBAA 的 WebVPN `login`：`CAS_GET:vpn → CAS_POST:vpn → CALLBACK:vpn → UC_ACTIVATE:vpn → UC_STATUS:vpn → CAS_GET:direct → CAS_POST:direct → CALLBACK:vpn → UC_ACTIVATE:direct`。最后四步来自 `establishDirectSsoSession`；其中绝对服务回调又被 `resolveRedirectUrl` 按当前模式包装到 VPN。此为所设合成回调下的可复现行为，并非学校现场的新观察。Ginkgo 没有无条件照搬第二次密码提交；用户关于风控的约束不能被“逐字一致”掩盖。

Beta.3 的业务期自动换路线、固定 UBAA 的显式模式、当前 Ginkgo 的登录时选路后固定模式也不同。当前直连不可达的签到探针仍不自动换 WebVPN；其账号身份在该实验中保留。恢复策略、未知 UC 分类、Cookie/Keystore、密码到期目标、写入不重放等既有差异见 [前次审计](2026-11-03-offline-session-parity-and-agent-review.md)。未覆盖和待决项只维护在 [MIRROR-TODO](../MIRROR-TODO.md)，不以本轮有限对照关闭全协议事项。

## 为什么此前有源码和文档仍然改坏

能由提交和执行证据确认的原因是：`2c85a6c` 将 UC 当目录而在失败时发布身份；`5215a1b` 以避免重新进入 CAS 为由截断非 CAS 服务回调；Beta.7 持久化混用了偏好与有效路线。相应离线场景现在能抓到实际结果差异。旧 FIFO mock 不校验 URL/方法/顺序，当前代码与预期同时变化仍可能全绿。此次实际 Ktor 执行又证明：阅读模块头函数也会漏掉客户端插件追加的头，必须检查完整调用组合。

参考版本、输入、判定器和覆盖范围应独立记录。测试通过、协议锁刷新和已发布均不能替代协议事实或未覆盖链路；`readiness=blocked` 时公开 Beta.7 的记录也不能反过来证明验收通过。本轮保留修正前证据和显式差异列表，没有将所有不同标成修复、没有宣称已确定全部真实事故原因。涉及认证、Cookie/路由的工作树修改仍须按 COLLABORATION 人工审查，未发布。

## 最终本地检查

- `check-ubaa-reference.py`：退出 0。固定 UBAA 原源码及原客户端工厂执行 29 项测试；六个业务场景、双方各 16 条准备后请求，比较范围内零字段差异；历史观察符合记录矩阵。参考与当前 Rust 源码摘要保存在修正后 JSON。
- `CARGO_NET_OFFLINE=true bash scripts/check-mirror.sh`：退出 0，架构/文档/协议锁、格式、workspace 全 target/feature 严格 Clippy、core/upstream/workspace 测试、Flutter analyze、761 项 Flutter 单元/widget 测试、FRB 再生成零差异通过。新增 golden 已在这次门禁执行。
- `check-session-regressions.py` 随完整门禁执行：9/9 能编译的错误变体被测试检出；新增的缺 Ktor JSON Accept、空路径误补 `/` 均由 UBAA 独立 golden 抓住，未将编译失败算作检出。
- 参考请求采集改为直接调用原私有工厂后，重新执行上述独立参考差分仍通过；此后的变更仅为文档/协议锁同步。API 文档与链接检查、`git diff --check` 通过。修正前/后响应文件 SHA-256 相同。

未构建或安装新 APK，未运行物理设备/Windows 主机、真实学校或写入验收，未提交/发布。本次通过不改变发布阻断；剩余覆盖和策略决策继续保留在唯一 TODO。
