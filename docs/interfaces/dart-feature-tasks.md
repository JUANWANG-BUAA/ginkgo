# Flutter 功能域：tasks

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。
`flutter/lib/features/tasks/` 的页面、域内组件与模型。

## features/tasks/task_editor.dart

- `class TaskDraft`
  <sub>class · features/tasks/task_editor.dart:11</sub>
    - `const TaskDraft(this.title, this.due);`  <sub>:12</sub>
- `class TaskEditor extends StatefulWidget` — User must explicitly confirm. Failed saves retain all editable fields.
  <sub>class · features/tasks/task_editor.dart:17</sub>
    - `const TaskEditor({ super.key, this.title = '', this.due = '', this.sourceAssignmentId, this.isNew = true, required this.onSave, });`  <sub>:18</sub>
    - `final Future<bool> Function(TaskDraft draft) onSave;`  <sub>:29</sub>
    - `State<TaskEditor> createState() => …`  <sub>:31</sub>

## features/tasks/tasks_page.dart

- `class TasksPage extends StatefulWidget`
  <sub>class · features/tasks/tasks_page.dart:18</sub>
    - `const TasksPage({ super.key, this.storageRoot, required this.service, required this.fileActions, this.academicService, this.initialTaskId, });`  <sub>:19</sub>
    - `State<TasksPage> createState() => …`  <sub>:35</sub>

## features/tasks/tasks_widgets.dart

- `class TaskRowCard extends StatelessWidget` — 单条本机待办卡片。
  <sub>class · features/tasks/tasks_widgets.dart:11</sub>
    - `const TaskRowCard({ super.key, required this.task, required this.highlighted, required this.targetKey, required this.busy, required this.readable, required this.locating, required this.onToggle, required this.onMore, required this.onSource, });`  <sub>:12</sub>
    - `Widget build(BuildContext context) => …`  <sub>:36</sub>
- `class TasksHeaderActions extends StatelessWidget` — 待办页头操作（更多 / 新增）。
  <sub>class · features/tasks/tasks_widgets.dart:144</sub>
    - `const TasksHeaderActions({ super.key, required this.busy, required this.readable, required this.onMore, required this.onAdd, });`  <sub>:145</sub>
    - `Widget build(BuildContext context) => …`  <sub>:159</sub>
- `class TasksPageHeader extends StatelessWidget` — 待办页头。
  <sub>class · features/tasks/tasks_widgets.dart:192</sub>
    - `const TasksPageHeader({ super.key, required this.actions, required this.canPop, required this.onBack, });`  <sub>:193</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:205</sub>
