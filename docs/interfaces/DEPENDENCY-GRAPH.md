# Flutter 目录依赖图（生成）

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。

按目录分组统计：26 个分组节点（其中 25 个有出向依赖）、143 条跨组依赖。箭头方向为「依赖方 → 被依赖方」。

## 依赖图

```mermaid
flowchart LR
  n_app["app"]
  n_application["application"]
  n_design["design"]
  n_features_auth["features/auth"]
  n_features_bykc["features/bykc"]
  n_features_cgyy["features/cgyy"]
  n_features_checkin["features/checkin"]
  n_features_classroom["features/classroom"]
  n_features_grades["features/grades"]
  n_features_graduate["features/graduate"]
  n_features_homework["features/homework"]
  n_features_learning["features/learning"]
  n_features_library["features/library"]
  n_features_notices["features/notices"]
  n_features_reservations["features/reservations"]
  n_features_schedule["features/schedule"]
  n_features_settings["features/settings"]
  n_features_shuttle["features/shuttle"]
  n_features_tasks["features/tasks"]
  n_features_today["features/today"]
  n_infrastructure["infrastructure"]
  n_platform["platform"]
  n_root["root"]
  n_shared["shared"]
  n_widgets["widgets"]
  n_workspace["workspace"]
  n_app --> n_design
  n_app --> n_platform
  n_app --> n_shared
  n_application --> n_root
  n_application --> n_shared
  n_features_auth --> n_application
  n_features_auth --> n_design
  n_features_auth --> n_root
  n_features_auth --> n_widgets
  n_features_bykc --> n_application
  n_features_bykc --> n_design
  n_features_bykc --> n_root
  n_features_bykc --> n_shared
  n_features_bykc --> n_widgets
  n_features_cgyy --> n_application
  n_features_cgyy --> n_design
  n_features_cgyy --> n_features_reservations
  n_features_cgyy --> n_root
  n_features_cgyy --> n_shared
  n_features_cgyy --> n_widgets
  n_features_checkin --> n_application
  n_features_checkin --> n_design
  n_features_checkin --> n_features_schedule
  n_features_checkin --> n_root
  n_features_checkin --> n_shared
  n_features_checkin --> n_widgets
  n_features_classroom --> n_application
  n_features_classroom --> n_features_tasks
  n_features_classroom --> n_root
  n_features_classroom --> n_shared
  n_features_classroom --> n_widgets
  n_features_grades --> n_application
  n_features_grades --> n_design
  n_features_grades --> n_root
  n_features_grades --> n_widgets
  n_features_graduate --> n_application
  n_features_graduate --> n_design
  n_features_graduate --> n_root
  n_features_graduate --> n_widgets
  n_features_homework --> n_application
  n_features_homework --> n_design
  n_features_homework --> n_features_schedule
  n_features_homework --> n_infrastructure
  n_features_homework --> n_root
  n_features_homework --> n_shared
  n_features_homework --> n_widgets
  n_features_learning --> n_application
  n_features_learning --> n_design
  n_features_learning --> n_features_settings
  n_features_learning --> n_infrastructure
  n_features_learning --> n_widgets
  n_features_library --> n_application
  n_features_library --> n_design
  n_features_library --> n_features_reservations
  n_features_library --> n_root
  n_features_library --> n_widgets
  n_features_notices --> n_root
  n_features_notices --> n_widgets
  n_features_reservations --> n_design
  n_features_reservations --> n_features_cgyy
  n_features_reservations --> n_features_classroom
  n_features_reservations --> n_features_library
  n_features_reservations --> n_root
  n_features_reservations --> n_widgets
  n_features_schedule --> n_application
  n_features_schedule --> n_design
  n_features_schedule --> n_root
  n_features_schedule --> n_shared
  n_features_schedule --> n_widgets
  n_features_settings --> n_application
  n_features_settings --> n_design
  n_features_settings --> n_features_graduate
  n_features_settings --> n_features_learning
  n_features_settings --> n_platform
  n_features_settings --> n_root
  n_features_settings --> n_shared
  n_features_settings --> n_widgets
  n_features_shuttle --> n_design
  n_features_shuttle --> n_features_today
  n_features_shuttle --> n_root
  n_features_shuttle --> n_shared
  n_features_shuttle --> n_widgets
  n_features_tasks --> n_application
  n_features_tasks --> n_design
  n_features_tasks --> n_features_homework
  n_features_tasks --> n_root
  n_features_tasks --> n_shared
  n_features_tasks --> n_widgets
  n_features_today --> n_application
  n_features_today --> n_design
  n_features_today --> n_features_homework
  n_features_today --> n_features_schedule
  n_features_today --> n_features_tasks
  n_features_today --> n_root
  n_features_today --> n_shared
  n_features_today --> n_widgets
  n_features_today --> n_workspace
  n_infrastructure --> n_platform
  n_infrastructure --> n_shared
  n_platform --> n_application
  n_platform --> n_design
  n_platform --> n_features_settings
  n_platform --> n_infrastructure
  n_platform --> n_widgets
  n_root --> n_application
  n_root --> n_design
  n_root --> n_features_auth
  n_root --> n_infrastructure
  n_root --> n_platform
  n_root --> n_shared
  n_root --> n_widgets
  n_root --> n_workspace
  n_shared --> n_application
  n_shared --> n_design
  n_shared --> n_features_homework
  n_shared --> n_features_schedule
  n_shared --> n_root
  n_widgets --> n_application
  n_widgets --> n_design
  n_widgets --> n_shared
  n_workspace --> n_app
  n_workspace --> n_application
  n_workspace --> n_design
  n_workspace --> n_features_bykc
  n_workspace --> n_features_cgyy
  n_workspace --> n_features_checkin
  n_workspace --> n_features_classroom
  n_workspace --> n_features_grades
  n_workspace --> n_features_graduate
  n_workspace --> n_features_homework
  n_workspace --> n_features_learning
  n_workspace --> n_features_library
  n_workspace --> n_features_notices
  n_workspace --> n_features_reservations
  n_workspace --> n_features_schedule
  n_workspace --> n_features_settings
  n_workspace --> n_features_shuttle
  n_workspace --> n_features_tasks
  n_workspace --> n_features_today
  n_workspace --> n_platform
  n_workspace --> n_root
  n_workspace --> n_shared
  n_workspace --> n_widgets
```

## 循环依赖

以下分组互相依赖，构成强连通分量。Dart 侧没有像 Rust 那样的依赖方向门禁，因此这些环不会被自动拦截；改动前先确认是否真的需要双向引用。

- **25 个分组**：`app`、`application`、`features/auth`、`features/bykc`、`features/cgyy`、`features/checkin`、`features/classroom`、`features/grades`、`features/graduate`、`features/homework`、`features/learning`、`features/library`、`features/notices`、`features/reservations`、`features/schedule`、`features/settings`、`features/shuttle`、`features/tasks`、`features/today`、`infrastructure`、`platform`、`root`、`shared`、`widgets`、`workspace`

```mermaid
flowchart LR
  n_app --> n_platform
  n_app --> n_shared
  n_application --> n_root
  n_application --> n_shared
  n_features_auth --> n_application
  n_features_auth --> n_root
  n_features_auth --> n_widgets
  n_features_bykc --> n_application
  n_features_bykc --> n_root
  n_features_bykc --> n_shared
  n_features_bykc --> n_widgets
  n_features_cgyy --> n_application
  n_features_cgyy --> n_features_reservations
  n_features_cgyy --> n_root
  n_features_cgyy --> n_shared
  n_features_cgyy --> n_widgets
  n_features_checkin --> n_application
  n_features_checkin --> n_features_schedule
  n_features_checkin --> n_root
  n_features_checkin --> n_shared
  n_features_checkin --> n_widgets
  n_features_classroom --> n_application
  n_features_classroom --> n_features_tasks
  n_features_classroom --> n_root
  n_features_classroom --> n_shared
  n_features_classroom --> n_widgets
  n_features_grades --> n_application
  n_features_grades --> n_root
  n_features_grades --> n_widgets
  n_features_graduate --> n_application
  n_features_graduate --> n_root
  n_features_graduate --> n_widgets
  n_features_homework --> n_application
  n_features_homework --> n_features_schedule
  n_features_homework --> n_infrastructure
  n_features_homework --> n_root
  n_features_homework --> n_shared
  n_features_homework --> n_widgets
  n_features_learning --> n_application
  n_features_learning --> n_features_settings
  n_features_learning --> n_infrastructure
  n_features_learning --> n_widgets
  n_features_library --> n_application
  n_features_library --> n_features_reservations
  n_features_library --> n_root
  n_features_library --> n_widgets
  n_features_notices --> n_root
  n_features_notices --> n_widgets
  n_features_reservations --> n_features_cgyy
  n_features_reservations --> n_features_classroom
  n_features_reservations --> n_features_library
  n_features_reservations --> n_root
  n_features_reservations --> n_widgets
  n_features_schedule --> n_application
  n_features_schedule --> n_root
  n_features_schedule --> n_shared
  n_features_schedule --> n_widgets
  n_features_settings --> n_application
  n_features_settings --> n_features_graduate
  n_features_settings --> n_features_learning
  n_features_settings --> n_platform
  n_features_settings --> n_root
  n_features_settings --> n_shared
  n_features_settings --> n_widgets
  n_features_shuttle --> n_features_today
  n_features_shuttle --> n_root
  n_features_shuttle --> n_shared
  n_features_shuttle --> n_widgets
  n_features_tasks --> n_application
  n_features_tasks --> n_features_homework
  n_features_tasks --> n_root
  n_features_tasks --> n_shared
  n_features_tasks --> n_widgets
  n_features_today --> n_application
  n_features_today --> n_features_homework
  n_features_today --> n_features_schedule
  n_features_today --> n_features_tasks
  n_features_today --> n_root
  n_features_today --> n_shared
  n_features_today --> n_widgets
  n_features_today --> n_workspace
  n_infrastructure --> n_platform
  n_infrastructure --> n_shared
  n_platform --> n_application
  n_platform --> n_features_settings
  n_platform --> n_infrastructure
  n_platform --> n_widgets
  n_root --> n_application
  n_root --> n_features_auth
  n_root --> n_infrastructure
  n_root --> n_platform
  n_root --> n_shared
  n_root --> n_widgets
  n_root --> n_workspace
  n_shared --> n_application
  n_shared --> n_features_homework
  n_shared --> n_features_schedule
  n_shared --> n_root
  n_widgets --> n_application
  n_widgets --> n_shared
  n_workspace --> n_app
  n_workspace --> n_application
  n_workspace --> n_features_bykc
  n_workspace --> n_features_cgyy
  n_workspace --> n_features_checkin
  n_workspace --> n_features_classroom
  n_workspace --> n_features_grades
  n_workspace --> n_features_graduate
  n_workspace --> n_features_homework
  n_workspace --> n_features_learning
  n_workspace --> n_features_library
  n_workspace --> n_features_notices
  n_workspace --> n_features_reservations
  n_workspace --> n_features_schedule
  n_workspace --> n_features_settings
  n_workspace --> n_features_shuttle
  n_workspace --> n_features_tasks
  n_workspace --> n_features_today
  n_workspace --> n_platform
  n_workspace --> n_root
  n_workspace --> n_shared
  n_workspace --> n_widgets
```

