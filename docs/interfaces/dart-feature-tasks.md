# Flutter 功能域：tasks

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。

`flutter/lib/features/tasks/` 的页面、域内组件与模型。

## features/tasks/rules_page.dart

- `class RulesPage extends StatefulWidget`  
  <sub>class · features/tasks/rules_page.dart:8</sub>
    - `const RulesPage( {…}`  <sub>:9</sub>
    - `State<RulesPage> createState() => _RulesPageState();`  <sub>:12</sub>

## features/tasks/task_editor.dart

- `class TaskDraft`  
  <sub>class · features/tasks/task_editor.dart:10</sub>
    - `const TaskDraft(this.title, this.due);`  <sub>:11</sub>
- `class TaskEditor extends StatefulWidget` — User must explicitly confirm. Failed saves retain all editable fields.  
  <sub>class · features/tasks/task_editor.dart:16</sub>
    - `const TaskEditor( {…}`  <sub>:17</sub>
    - `final Future<bool> Function(TaskDraft draft) onSave;`  <sub>:28</sub>
    - `State<TaskEditor> createState() => _TaskEditorState();`  <sub>:30</sub>

## features/tasks/tasks_page.dart

- `class TasksPage extends StatefulWidget`  
  <sub>class · features/tasks/tasks_page.dart:16</sub>
    - `const TasksPage( {…}`  <sub>:17</sub>
    - `State<TasksPage> createState() => _TasksPageState();`  <sub>:31</sub>

## features/tasks/tasks_widgets.dart

- `class TaskRowCard extends StatelessWidget` — 单条本机待办卡片。  
  <sub>class · features/tasks/tasks_widgets.dart:11</sub>
    - `const TaskRowCard( {…}`  <sub>:12</sub>
    - `Widget build(BuildContext context) => Container( key: highlighted ? targetKey : ValueKey('task-container-$ {…}`  <sub>:36</sub>
- `class TasksHeaderActions extends StatelessWidget` — 待办页头操作（更多 / 新增）。  
  <sub>class · features/tasks/tasks_widgets.dart:145</sub>
    - `const TasksHeaderActions( {…}`  <sub>:146</sub>
    - `Widget build(BuildContext context) => Row( mainAxisSize: MainAxisSize.min, children: [ … : onAdd, child: const Icon(CupertinoIcons.add), ), ), ], );`  <sub>:160</sub>
- `class TasksPageHeader extends StatelessWidget` — 待办页头。  
  <sub>class · features/tasks/tasks_widgets.dart:193</sub>
    - `const TasksPageHeader( {…}`  <sub>:194</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:206</sub>
