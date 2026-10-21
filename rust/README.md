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

当前已接入认证、主要只读应用层、进程内快照和签到 / 图书馆实验写路径；真实写入与 Windows 主机仍未验收。会话身份统一保存在 `Identity`；可丢弃内存状态的中毒锁整体重置，路线枚举保留完整值，持久化锁中毒继续返回错误。实现范围、既往真实只读和最近登录失败见 [镜像现状](../docs/MIRROR-IMPLEMENTATION.md)；共享契约覆盖见 [fixtures](../fixtures/README.md)。
