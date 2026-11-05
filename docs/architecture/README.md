# 工具生成的工程架构

打开 [架构浏览器](index.html)，从入口函数逐级查看被调用函数、调用方、回调引用、实现候选与源码位置。所有节点与边由静态工具输出生成，不维护手绘调用边。

- Dart：Dart analyzer 解析类型与 AST，提取函数、构造调用、回调引用、闭包归属、await 和接口实现关系。
- Rust：rust-analyzer LSP 的 documentSymbol、prepareCallHierarchy、outgoingCalls、implementation；以 Android ARM64 target 解析。
- Android Kotlin：ast-grep 的语法树提取函数、lambda 和调用点。未做 Kotlin 类型解析，调用目标保留为未解析。
- Dart 目录导入：复用接口生成器；Rust crate 依赖：Cargo metadata。两者不等于函数调用。
- FRB：仅将生成 API 模块与 Rust 同路径、同名转换的公开入口标成“生成绑定配对”；这是生成规则匹配，不是编译器跨语言证明。

静态调用图不表示运行时先后顺序或分支一定执行。回调注册、接口实现、contains 和 await 分开显示；动态接收者、宏展开、目标平台条件编译、JNI 和 MethodChannel 的跨语言连接有明确覆盖限制，不猜测补线。

生成器与运行方式见 [分析工具](../../scripts/architecture/README.md)。数据快照包含工具版本、源文件 SHA-256、解析错误与未能准备调用层级的函数；源码变化后必须重新生成。长期待办仍只维护在 [MIRROR-TODO](../MIRROR-TODO.md)。

本次审图后的工程优化与证据边界见 [交接审计](../_audit/2026-11-05-engineering-handoff.md)。网页的函数邻域每侧最多显示 12 个符号，完整位置保留在下方表格；不是以局部图冒充完整运行轨迹。
