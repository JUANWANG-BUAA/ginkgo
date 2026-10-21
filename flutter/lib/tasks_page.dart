import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:path_provider/path_provider.dart';

import 'apple_widgets.dart';
import 'src/rust/api/live.dart' as live;

class TasksPage extends StatefulWidget {
  const TasksPage({super.key, this.demo = false, this.storageRoot});
  final bool demo;
  final String? storageRoot;
  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  List<Map<String, dynamic>> tasks = [];
  String? root, error;
  bool busy = true, readable = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      root =
          widget.storageRoot ??
          '${(await getApplicationSupportDirectory()).path}/tasks';
      await edit('load');
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = '无法读取本机待办，请重试。';
        });
      }
    }
  }

  Future<bool> edit(
    String action, {
    Map<String, dynamic>? task,
    String? title,
    String? due,
  }) async {
    if (root == null) return false;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await live.editTasks(
        root: root!,
        demo: widget.demo,
        action: action,
        id: task?['id'] as String?,
        title: title,
        due: due,
        completed: action == 'toggle' ? !(task!['completed'] as bool) : null,
      );
      if (!mounted) return false;
      setState(() {
        busy = false;
        if (result.payload != null) {
          tasks = (jsonDecode(result.payload!) as List)
              .cast<Map<String, dynamic>>();
          readable = true;
        }
        if (result.failure != null) {
          error = '待办读取或保存失败。为保护本机数据，请重试后再编辑。';
          readable = false;
        }
      });
      return result.failure == null;
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          readable = false;
          error = '本机待办暂不可用，请重试。';
        });
      }
      return false;
    }
  }

  Future<void> editor([Map<String, dynamic>? task]) async {
    final saved = await Navigator.of(context).push<_TaskDraft>(
      CupertinoPageRoute(builder: (_) => _TaskEditor(task: task)),
    );
    if (saved != null && mounted) {
      await edit(
        task == null ? 'add' : 'update',
        task: task,
        title: saved.title,
        due: saved.due,
      );
    }
  }

  Future<void> remove(Map<String, dynamic> task) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('删除待办？'),
        content: Text(task['title'] as String),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await edit('delete', task: task);
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    child: CustomScrollView(
      key: const Key('tasks-scroll'),
      slivers: [
        ApplePageHeader(
          largeTitle: const Text('待办'),
          border: null,
          trailing: AppleGlassButton(
            label: '新增待办',
            onPressed: busy || !readable ? null : () => editor(),
            child: const Icon(CupertinoIcons.add),
          ),
        ),
        SliverList.list(
          children: [
            if (busy)
              const Padding(
                padding: EdgeInsets.all(24),
                child: CupertinoActivityIndicator(),
              ),
            if (error != null)
              AppleSection(
                children: [
                  AppleEmptyState(
                    title: error!,
                    description: '原有数据不会被覆盖。',
                    action: '重试',
                    onAction: load,
                    error: true,
                  ),
                ],
              ),
            if (!busy && readable && tasks.isEmpty)
              const AppleSection(
                children: [
                  AppleEmptyState(
                    title: '暂无待办',
                    description: '点击右上角添加，待办仅保存在此设备。',
                  ),
                ],
              ),
            for (final completed in [false, true])
              if (tasks.any((t) => t['completed'] == completed))
                AppleSection(
                  header: Text(completed ? '已完成' : '待完成'),
                  children: [
                    for (final task in tasks.where(
                      (t) => t['completed'] == completed,
                    ))
                      AppleListTile(
                        leading: CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: busy || !readable
                              ? null
                              : () => edit('toggle', task: task),
                          child: Icon(
                            completed
                                ? CupertinoIcons.checkmark_circle_fill
                                : CupertinoIcons.circle,
                          ),
                        ),
                        title: Text(
                          task['title'] as String,
                          style: TextStyle(
                            decoration: completed
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        subtitle: Text(task['due'] as String),
                        trailing: CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: busy || !readable
                              ? null
                              : () => remove(task),
                          child: const Icon(CupertinoIcons.trash, size: 20),
                        ),
                        onTap: busy || !readable ? null : () => editor(task),
                      ),
                  ],
                ),
            const SizedBox(height: 96),
          ],
        ),
      ],
    ),
  );
}

class _TaskDraft {
  const _TaskDraft(this.title, this.due);
  final String title, due;
}

class _TaskEditor extends StatefulWidget {
  const _TaskEditor({this.task});
  final Map<String, dynamic>? task;
  @override
  State<_TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<_TaskEditor> {
  late final TextEditingController title = TextEditingController(
    text: widget.task?['title'] as String?,
  );
  late DateTime due =
      DateTime.tryParse(widget.task?['due'] as String? ?? '') ?? DateTime.now();
  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    navigationBar: CupertinoNavigationBar(
      middle: Text(widget.task == null ? '新增待办' : '编辑待办'),
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: title.text.trim().isEmpty
            ? null
            : () => Navigator.pop(
                context,
                _TaskDraft(
                  title.text.trim(),
                  '${due.year}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}',
                ),
              ),
        child: const Text('保存'),
      ),
    ),
    child: SafeArea(
      child: ListView(
        children: [
          AppleSection(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: CupertinoTextField(
                  key: const Key('task-title'),
                  controller: title,
                  placeholder: '待办内容',
                  maxLength: 500,
                  maxLines: 3,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text('截止日期'),
          ),
          SizedBox(
            height: 216,
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              initialDateTime: due,
              onDateTimeChanged: (value) => due = value,
            ),
          ),
        ],
      ),
    ),
  );
}
