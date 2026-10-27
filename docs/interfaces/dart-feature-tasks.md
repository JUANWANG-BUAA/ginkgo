# Flutter 功能域：tasks

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。

`flutter/lib/features/tasks/` 的页面、域内组件与模型。

## RulesPage (class)

- `class RulesPage extends StatefulWidget {`  
  <sub>features/tasks/rules_page.dart:8</sub>
    - `const RulesPage({super.key, required this.service});`  <sub>:9</sub>
    - `State<RulesPage> createState() => _RulesPageState();`  <sub>:12</sub>

## TaskDraft (class)

- `class TaskDraft {`  
  <sub>features/tasks/task_editor.dart:10</sub>
    - `const TaskDraft(this.title, this.due);`  <sub>:11</sub>

## TaskEditor (class)

- `class TaskEditor extends StatefulWidget {` — User must explicitly confirm. Failed saves retain all editable fields.  
  <sub>features/tasks/task_editor.dart:16</sub>
    - `const TaskEditor({ super.key, this.title = '', this.due = '', this.sourceAssignmentId, this.isNew = true, required this.onSave, });`  <sub>:17</sub>
    - `final Future<bool> Function(TaskDraft draft) onSave;`  <sub>:28</sub>
    - `State<TaskEditor> createState() => _TaskEditorState();`  <sub>:30</sub>

## TasksPage (class)

- `class TasksPage extends StatefulWidget {`  
  <sub>features/tasks/tasks_page.dart:16</sub>
    - `const TasksPage({ super.key, this.demo = false, this.storageRoot, this.service, this.academicService, this.initialTaskId, });`  <sub>:17</sub>
    - `State<TasksPage> createState() => _TasksPageState();`  <sub>:31</sub>

## TaskRowCard (class)

- `class TaskRowCard extends StatelessWidget {` — 单条本机待办卡片。  
  <sub>features/tasks/tasks_widgets.dart:11</sub>
    - `const TaskRowCard({ super.key, required this.task, required this.highlighted, required this.targetKey, required this.busy, required this.readable, re…`  <sub>:12</sub>
    - `Widget build(BuildContext context) => Container( key: highlighted ? targetKey : ValueKey('task-container-${task.id}'), decoration: BoxDecoration( col…`  <sub>:36</sub>

## TasksHeaderActions (class)

- `class TasksHeaderActions extends StatelessWidget {` — 待办页头操作（更多 / 新增）。  
  <sub>features/tasks/tasks_widgets.dart:145</sub>
    - `const TasksHeaderActions({ super.key, required this.busy, required this.readable, required this.onMore, required this.onAdd, });`  <sub>:146</sub>
    - `Widget build(BuildContext context) => Row( mainAxisSize: MainAxisSize.min, children: [ Semantics( label: '待办更多操作', button: true, child: CupertinoButt…`  <sub>:160</sub>

## TasksPageHeader (class)

- `class TasksPageHeader extends StatelessWidget {` — 待办页头。  
  <sub>features/tasks/tasks_widgets.dart:193</sub>
    - `const TasksPageHeader({ super.key, required this.actions, required this.canPop, required this.onBack, });`  <sub>:194</sub>
    - `Widget build(BuildContext context) { if (AppleDesign.desktop(context)) { return ApplePageHeader( largeTitle: const Text('待办'), section: '工作台', subtit…`  <sub>:206</sub>
