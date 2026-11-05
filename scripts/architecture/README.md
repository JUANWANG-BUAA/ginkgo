# 架构静态分析工具

此目录是独立开发工具，不是应用运行依赖。图节点与边来自解析器，人工只维护展示与分析结论。

## 生成与校验

先安装仓库固定的 Flutter / Rust 工具链、Android ARM64 Rust target 和 NDK 28.2.13676358，解析 Flutter 依赖。另需 PATH 中的 `ast-grep`（本次 0.51.0）和默认 Rust 工具链的 `rust-analyzer` 组件（`rustup component add rust-analyzer`）。Dart 工具包单独锁定 analyzer 10.2.0；实际工具版本写入快照。

在仓库根目录执行：

```sh
python3 scripts/architecture/generate.py
python3 scripts/architecture/test_collectors.py
python3 scripts/architecture/check_snapshot.py
```

生成器依次运行 Dart 类型解析、Rust LSP、Kotlin AST、Cargo metadata 和导入索引，再输出 [工程网页](../../docs/architecture/index.html)。源码及分析器在扫描前后必须相同，否则拒绝生成。`ANDROID_HOME` 可指定 SDK；自定义 NDK 可设置 `CC_aarch64_linux_android` / `AR_aarch64_linux_android`。当前生成流程在 macOS 上验证，未宣称 Windows 运行验证。

`check_snapshot.py` 无需安装分析器，检查新增、删除和修改的源文件、锁文件及提取器哈希；它不能替代语义解析。网页样式或阅读说明调整无需重新扫描。原始结果与 LSP 日志保留在忽略的 `artifacts/local/architecture-analysis/`；不要提交个人凭据或运行日志。

## 各工具的证据范围

| 工具 | 提取 | 限制 |
| --- | --- | --- |
| Dart analyzer | Resolved AST、调用目标、构造、函数引用、闭包、await、类型继承中的方法实现 | 接口调用指向声明；候选实现不等于实际接收者；函数值可能无法静态解析 |
| rust-analyzer | documentSymbol → prepareCallHierarchy → outgoingCalls；trait implementation | Android cfg，过程宏禁用，测试排除；无法准备的符号逐项报告；Rust 闭包调用归入外层函数 |
| ast-grep | Kotlin function、lambda、call_expression | 仅语法位置，目标始终未解析；顶层初始化调用尚未归属 |
| Cargo metadata | workspace 内 crate 声明依赖、类型与 target 条件 | 不是某平台构建后的 feature 依赖图 |
| 接口索引生成器 | Dart import / export 和强连通分量 | 词法导入关系，不是函数调用 |
| FRB 规则配对 | 生成 API 与 Rust API 的相对模块路径和命名转换 | 独立标记为映射，不冒充编译器跨语言解析 |

合并器只保留项目符号及其外部边界目标。源文件正文直接嵌入离线网页，生成绑定及 SDK 源码除外。调用位置、包含关系、实现候选与等待点分别计数；计数不代表运行频率、分支覆盖或测试覆盖。覆盖摘要见 `docs/architecture/analysis-summary.json`。

## 回归

语义 fixture 故意定义同名方法 / 函数，确保目标由接收者类型或模块解析决定；另验证回调引用不被误当直接调用、隐式构造器不撞 ID，以及接口实现候选保留。真实应用的边界由 `scripts/check-mirror-architecture.py` 和完整镜像检查负责。
