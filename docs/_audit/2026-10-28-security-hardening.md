# 安全加固与模块化接口审计（2026-10-28）

## 范围

检查凭据与敏感数据、日志/TLS、账号隔离、写操作保护、缓存生命周期、上游输入校验、依赖公告及 domain/core/upstream/bridge/Flutter 分层。未使用真实账号，未执行学校写操作，未改变学校端点、参数或成功码。

## 已实施

- `cargo audit` 后升级 `tokio 1.54.0 → 1.54.1`、`rustls-webpki 0.103.15 → 0.103.16`、`webpki-roots 1.0.9 → 1.0.11`，清除相应公告。
- `tasks_store.rs` 临时文件使用 Unix `0600`，新增合成权限测试；原子替换、损坏不覆盖和账号隔离不变。
- `AccountOwner` 与代次校验归回 `session_service`，CGYY、本人借阅和校园卡共用同一身份接口；上游 354 项测试通过，含账号 A→B→A 代次拒绝。
- `docs/index.html` 增加 `frame-ancestors 'none'` 与 `require-trusted-types-for 'script'; trusted-types default`；`landing.js` 不使用 `innerHTML`，保留静态下载回退。
- `API.md`、`PRIVACY.md`、`MIRROR-IMPLEMENTATION.md` 与生成接口索引同步。

## 保留风险：RUSTSEC-2023-0071

`rsa 0.9.10` 的 Marvin Attack 公告称可能影响密钥恢复的时序侧信道，当前公告没有修复版本。`ginkgo_upstream/src/adapters/bykc_http.rs` 的博雅协议确实使用 `rsa::{pkcs8::DecodePublicKey, Pkcs1v15Encrypt, RsaPublicKey}`，因此不能按“未使用依赖”删除。该依赖不是全局 TLS 或密码保险库替代品，博雅公钥加密流程保持原协议，不自行改写加密算法或宣称风险已消除。

后续只能在有经过验证的修复版本或兼容替代实现时替换，并继续用 `cargo audit` 跟踪。当前最终审计结果：上述可升级公告已清除，`rsa` 此项中单列，未设置忽略规则。

## 验证边界

真实设备文件权限、统一认证与业务一致性、物理 Android 安全行为和真实写入不由合成测试推断。完整基线与 Android 正常入口构建结果以本次命令输出为准；不使用真实账号复验。
