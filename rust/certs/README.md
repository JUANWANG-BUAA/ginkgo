# TLS 中间证书（作用域受限）

`globalsign_gcc_r3_dv_tls_ca_2020.pem`
- Subject: `C=BE, O=GlobalSign nv-sa, CN=GlobalSign GCC R3 DV TLS CA 2020`
- Issuer: `OU=GlobalSign Root CA - R3, O=GlobalSign, CN=GlobalSign`
- 有效期：2020-07-28 → 2029-03-18，`CA:TRUE, pathlen:0`
- 来源：叶子证书 AIA `http://secure.globalsign.com/cacert/gsgccr3dvtlsca2020.crt`（2026-10-23 取得）
- SHA-256：`3e5b6c95080dcc8c80afc1f2d7cec76da0201e895064655f04c3c7c5d438ead2`

用途与边界（详见 `docs/API.md` §6.1）：
- 仅因 `space.lib.buaa.edu.cn` **只下发叶子证书**、缺少该中间证书，导致严格 rustls 客户端无法完成校验。
- 只加入该主机的专用 HTTP client（`adapters/reqwest_transport.rs` 的 `scoped_client`），**不影响其他主机与系统信任库**。
- 回滚：删除本目录与 `reqwest_transport.rs` 中的 `INCOMPLETE_CHAIN_*` 常量即可，其余代码无需改动。
- 这是公开证书，不含私钥；不得在此目录放置任何密钥或账号材料。
