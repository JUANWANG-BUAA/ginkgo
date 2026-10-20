# Ginkgo Rust workspace

- `ginkgo_core`：领域模型、学校时间、合成仓库与应用用例，无 Flutter 依赖。
- `ginkgo_flutter_bridge`：粗粒度 typed FFI DTO 与映射，FRB 2.12.0 生成绑定。
- `../fixtures`：共享黄金样例，Rust 测试从仓库读取，不复制为测试常量。

从仓库根目录执行 `scripts/check-mirror.sh`。单独运行 Rust：

```sh
cd rust
cargo fmt --all --check
cargo clippy --workspace --all-targets --all-features --locked -- -D warnings
cargo test --workspace --locked
```

若本地 `stable` 已是 1.99.0，可以设置 `RUSTUP_TOOLCHAIN=stable` 复用它。辅助脚本会先检查再选择，避免重复安装。

当前已有认证核心（CAS/UC/Cookie/WebVPN/单次恢复）、平台凭据保险库、真实只读应用层（空教室/课表/今天/成绩）、5 分钟进程内快照和 FRB 真实会话命令；作业仍为合成切片，真实账号只读验收、Windows/macOS 保险库实机与写操作尚未完成。详见 `../docs/RUST-FLUTTER-PORT.md` 与 `../docs/MIRROR-IMPLEMENTATION.md`。
