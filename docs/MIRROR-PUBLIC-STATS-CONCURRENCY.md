# 公共统计并发缓存回归（2026-10-21）

在独立 `fix/mirror-public-stats-concurrency` 工作树、基线 `16e4ac6` 开发，未修改主工作树、版本或发包入口，未操作模拟器。

## 复现与修复

公共统计页与设置自检通过同一 application 读取公开统计。原实现仅在网络请求前查询缓存；两个同时开始的非强制读取都看到空缓存，会发出两次相同 GET。使用受控 transport 与 semaphore 固定在网络等待点，旧实现请求数为2，回归要求1而失败，未依赖 sleep 或实网时序。

修复增加公共统计专用异步请求锁，保留锁前新鲜快照快速返回，锁后再次查缓存。第一个请求成功后，排队的普通读取复用它的实际时间戳和数据；强制刷新仍有各自请求语义，按顺序执行。强制请求期间的普通缓存命中不等待网络。取消中的任务通过 guard 析构释放锁，后续显式重试可继续。

没有改变公开URL、解析、五分钟TTL、Cookie隔离、失败保留旧结果、无需账号或clearCache行为；不涉及签到/预约等写操作。不是用户此前所有页面迟缓的根因证明。

## 验证

- `cargo test -p ginkgo_core public_stats --lib`：2项通过，其余164项未跑；包含先红后绿并发回归和既有Cookie隔离/缓存/失败保留链路。
- 全workspace all-targets/all-features Clippy `-D warnings`、fmt check通过。
- Android aarch64 bridge交叉检查通过，确认异步guard满足桥接约束；没有FRB API/DTO变更，不需生成绑定。
- 无Flutter/UI修改，未重复widget或长设备测试。新并发路径未做设备/实网验收，未纳入当前Alpha2发布包；后续由根任务选择整合后核验。
