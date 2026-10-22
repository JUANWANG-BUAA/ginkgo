import 'package:flutter/cupertino.dart';

import 'today_presentation.dart';
import 'workspace_shortcut_preferences.dart';

@immutable
class WorkspaceShortcut {
  const WorkspaceShortcut({
    required this.id,
    required this.title,
    required this.icon,
  });

  final String id;
  final String title;
  final IconData icon;
}

/// Local-only pinned entry points. The caller owns navigation and supplies
/// stable IDs (not display names). Editing never invokes [onOpen].
class WorkspaceShortcuts extends StatefulWidget {
  const WorkspaceShortcuts({
    super.key,
    required this.accountId,
    required this.demo,
    required this.choices,
    required this.onOpen,
    this.storageRoot,
  });

  final String? accountId;
  final bool demo;
  final List<WorkspaceShortcut> choices;
  final ValueChanged<String> onOpen;
  final String? storageRoot;

  @override
  State<WorkspaceShortcuts> createState() => _WorkspaceShortcutsState();
}

class _WorkspaceShortcutsState extends State<WorkspaceShortcuts>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  late WorkspaceShortcutPreferences _preferences;
  List<String>? _draft;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  void _attach() {
    _preferences = WorkspaceShortcutPreferences(
      accountId: widget.accountId,
      demo: widget.demo,
      storageRoot: widget.storageRoot,
    );
    // restore may finish synchronously for memory-only sessions.
    _preferences.restore();
    _preferences.addListener(_changed);
  }

  void _detach() {
    _preferences.removeListener(_changed);
    _preferences.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant WorkspaceShortcuts oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accountId != widget.accountId ||
        oldWidget.demo != widget.demo ||
        oldWidget.storageRoot != widget.storageRoot) {
      _detach();
      _draft = null;
      _attach();
    }
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  // First declaration wins if a caller accidentally supplies duplicate IDs.
  Map<String, WorkspaceShortcut> get _choices {
    final result = <String, WorkspaceShortcut>{};
    for (final choice in widget.choices) {
      if (WorkspaceShortcutPreferences.validIds([choice.id])) {
        result.putIfAbsent(choice.id, () => choice);
      }
    }
    return result;
  }

  List<String> get _defaults => WorkspaceShortcutPreferences.defaultIds
      .where(_choices.containsKey)
      .toList();

  Future<void> _save() async {
    final owner = _preferences;
    final draft = _draft;
    if (draft == null) return;
    final saved = await owner.save(draft);
    // An earlier account's I/O may complete after a switch or unmount.
    if (!mounted || !identical(owner, _preferences)) return;
    if (saved) setState(() => _draft = null);
  }

  Widget _button(String label, String key, VoidCallback? action) =>
      CupertinoButton(
        key: ValueKey(key),
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        onPressed: action,
        child: Text(label),
      );

  Widget _entry({
    required String id,
    required String title,
    required IconData icon,
    required VoidCallback? action,
    bool? selected,
  }) => Semantics(
    selected: selected,
    child: CupertinoButton(
      key: ValueKey(
        selected == null ? 'shortcut-open-$id' : 'shortcut-choice-$id',
      ),
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onPressed: action,
      child: Row(
        children: [
          ExcludeSemantics(child: Icon(icon, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Text(title, textAlign: TextAlign.start)),
          const SizedBox(width: 12),
          ExcludeSemantics(
            child: Icon(
              selected == null
                  ? CupertinoIcons.chevron_right
                  : selected
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.circle,
              size: 20,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _message(String text) =>
      Padding(padding: const EdgeInsets.all(16), child: Text(text));

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final choices = _choices;
    final selected = _preferences.ids ?? _defaults;
    final visible = selected.where(choices.containsKey).toList();
    final draft = _draft;
    final editable = _preferences.ready && !_preferences.saving;
    return TodayVisualSection(
      key: const Key('workspace-shortcuts'),
      header: const Text('常用服务'),
      footer: Text(
        _preferences.memoryOnly
            ? '当前仅临时记忆，不写入本机偏好。'
            : '仅保存在本机当前账号，不影响学校数据或个人待办。',
      ),
      children: [
        if (_preferences.loading) _message('正在读取常用服务偏好…'),
        if (_preferences.error != null) ...[
          _message(_preferences.error!),
          if (!_preferences.ready && !_preferences.loading)
            _button('重试读取', 'shortcuts-retry', _preferences.restore),
        ],
        if (draft == null) ...[
          if (visible.isEmpty) _message('暂无常用服务，可点编辑选择。'),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns =
                  constraints.maxWidth >= 300 &&
                      MediaQuery.textScalerOf(context).scale(17) <= 20
                  ? 2
                  : 1;
              return Wrap(
                children: [
                  for (final id in visible)
                    SizedBox(
                      width: constraints.maxWidth / columns,
                      child: _entry(
                        id: id,
                        title: choices[id]!.title,
                        icon: choices[id]!.icon,
                        action: () => widget.onOpen(id),
                      ),
                    ),
                ],
              );
            },
          ),
          if (selected.any((id) => !choices.containsKey(id)))
            _message('部分已选服务暂不可用，原偏好已保留。'),
          _button(
            '编辑',
            'shortcuts-edit',
            editable ? () => setState(() => _draft = List.of(selected)) : null,
          ),
        ] else ...[
          _message('已选 ${draft.length}/4 项 · 最多选择 4 项，也可全部取消。'),
          for (final id in {...choices.keys, ...draft})
            _entry(
              id: id,
              title: choices[id]?.title ?? '暂不可用的服务（$id）',
              icon: choices[id]?.icon ?? CupertinoIcons.question_circle,
              selected: draft.contains(id),
              action: !editable || (!draft.contains(id) && draft.length >= 4)
                  ? null
                  : () => setState(() {
                      if (draft.contains(id)) {
                        draft.remove(id);
                      } else {
                        draft.add(id);
                      }
                    }),
            ),
          Wrap(
            children: [
              _button(
                '取消',
                'shortcuts-cancel',
                editable ? () => setState(() => _draft = null) : null,
              ),
              _button(
                '恢复默认',
                'shortcuts-defaults',
                editable ? () => setState(() => _draft = _defaults) : null,
              ),
              _button(
                _preferences.saving ? '正在保存…' : '保存',
                'shortcuts-save',
                editable ? _save : null,
              ),
            ],
          ),
        ],
      ],
    );
  }
}
