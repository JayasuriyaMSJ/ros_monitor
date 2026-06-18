// lib/screens/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/workspace.dart';
import '../providers/workspace_provider.dart';
import '../services/rosbridge_service.dart';
import '../theme/app_theme.dart';
import '../widgets/topic_panel.dart';
import '../widgets/topic_sidebar.dart';


class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _sidebarOpen = true;

  @override
  Widget build(BuildContext context) {
    final tabs = ref.watch(workspaceProvider);
    final ws   = ref.watch(workspaceProvider.notifier);
    final activeIdx = ws.activeIndex.clamp(0, tabs.length - 1);
    final activeTab = tabs[activeIdx];

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyT, control: true):
            () => ws.addTab(),
        const SingleActivator(LogicalKeyboardKey.keyW, control: true):
            () => ws.removeTab(activeIdx),
        const SingleActivator(LogicalKeyboardKey.backslash, control: true):
            () => setState(() => _sidebarOpen = !_sidebarOpen),
      },
      child: Focus(
        autofocus: true,
        child: Column(
          children: [
            // ── tab bar ────────────────────────────────────────────────────
            _TabBar(
              tabs: tabs,
              activeIdx: activeIdx,
              onSelect: (i) => setState(() => ws.setActive(i)),
              onAdd: ws.addTab,
              onClose: ws.removeTab,
              sidebarOpen: _sidebarOpen,
              onToggleSidebar: () =>
                  setState(() => _sidebarOpen = !_sidebarOpen),
              columns: activeTab.columns,
              onSetColumns: (c) => ws.setColumns(c),
            ),

            // ── main area ──────────────────────────────────────────────────
            Expanded(
              child: Row(
                children: [
                  if (_sidebarOpen) ...[
                    const TopicSidebar(),
                    const VerticalDivider(
                        width: 1, color: AppTheme.border),
                  ],
                  Expanded(
                    child: _PanelGrid(
                      tab: activeTab,
                      onAddPanel: () => _showAddDialog(context, activeTab),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddDialog(BuildContext context, WorkspaceTab tab) {
    showDialog(
      context: context,
      builder: (_) => _AddPanelDialog(tab: tab),
    );
  }
}

// ── tab bar ───────────────────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  final List<WorkspaceTab> tabs;
  final int activeIdx;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;
  final ValueChanged<int> onClose;
  final bool sidebarOpen;
  final VoidCallback onToggleSidebar;
  final int columns;
  final ValueChanged<int> onSetColumns;

  const _TabBar({
    required this.tabs,
    required this.activeIdx,
    required this.onSelect,
    required this.onAdd,
    required this.onClose,
    required this.sidebarOpen,
    required this.onToggleSidebar,
    required this.columns,
    required this.onSetColumns,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      color: AppTheme.bg1,
      child: Row(
        children: [
          // sidebar toggle
          _TabIconBtn(
            icon: sidebarOpen ? Icons.view_sidebar : Icons.view_sidebar_outlined,
            tooltip: 'toggle sidebar  (ctrl+\\)',
            onTap: onToggleSidebar,
          ),
          const VerticalDivider(width: 1, indent: 6, endIndent: 6),

          // tabs
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < tabs.length; i++)
                  _Tab(
                    tab: tabs[i],
                    active: i == activeIdx,
                    onSelect: () => onSelect(i),
                    onClose: tabs.length > 1 ? () => onClose(i) : null,
                  ),
                // new tab
                _TabIconBtn(
                  icon: Icons.add,
                  tooltip: 'new workspace  (ctrl+T)',
                  onTap: onAdd,
                ),
              ],
            ),
          ),

          // column controls
          const VerticalDivider(width: 1, indent: 6, endIndent: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Text('cols:',
                    style: AppTheme.ui(size: 11, color: AppTheme.textMuted)),
                const SizedBox(width: 4),
                for (final c in [1, 2, 3, 4])
                  _ColBtn(
                    n: c,
                    active: columns == c,
                    onTap: () => onSetColumns(c),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final WorkspaceTab tab;
  final bool active;
  final VoidCallback onSelect;
  final VoidCallback? onClose;

  const _Tab({
    required this.tab,
    required this.active,
    required this.onSelect,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelect,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? AppTheme.accent : Colors.transparent,
              width: 2,
            ),
          ),
          color: active ? AppTheme.bg2 : Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tab.name,
              style: AppTheme.ui(
                size: 12,
                color: active ? AppTheme.textPrim : AppTheme.textSec,
                weight: active ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
            if (onClose != null) ...[
              const SizedBox(width: 6),
              InkWell(
                onTap: onClose,
                child: const Icon(Icons.close,
                    size: 11, color: AppTheme.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TabIconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _TabIconBtn(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 32,
          child: Icon(icon, size: 14, color: AppTheme.textSec),
        ),
      ),
    );
  }
}

class _ColBtn extends StatelessWidget {
  final int n;
  final bool active;
  final VoidCallback onTap;

  const _ColBtn(
      {required this.n, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 20,
        height: 20,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
            color: active ? AppTheme.accent.withValues(alpha: 0.2) : Colors.transparent,
          border: Border.all(
            color: active ? AppTheme.accent : AppTheme.border,
          ),
        ),
        alignment: Alignment.center,
        child: Text('$n',
            style: AppTheme.ui(
                size: 10,
                color: active ? AppTheme.accent : AppTheme.textMuted)),
      ),
    );
  }
}

// ── panel grid ────────────────────────────────────────────────────────────────

class _PanelGrid extends StatelessWidget {
  final WorkspaceTab tab;
  final VoidCallback onAddPanel;

  const _PanelGrid({required this.tab, required this.onAddPanel});

  @override
  Widget build(BuildContext context) {
    if (tab.panels.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.dashboard_customize_outlined,
                size: 48, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            Text('no panels',
                style: AppTheme.ui(size: 16, color: AppTheme.textSec)),
            const SizedBox(height: 8),
            Text('click a topic in the sidebar, or add manually',
                style: AppTheme.ui(size: 13, color: AppTheme.textMuted)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('add panel'),
              onPressed: onAddPanel,
            ),
          ],
        ),
      );
    }

    final cols = tab.columns;
    final panels = tab.panels;

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          for (var r = 0; r < (panels.length / cols).ceil(); r++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    for (var c = 0; c < cols; c++) ...[
                      if (c > 0) const SizedBox(width: 6),
                      Expanded(
                        child: () {
                          final idx = r * cols + c;
                          if (idx >= panels.length) return const SizedBox();
                          return TopicPanel(key: ValueKey(panels[idx].id), config: panels[idx]);
                        }(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── add panel dialog ──────────────────────────────────────────────────────────

class _AddPanelDialog extends ConsumerStatefulWidget {
  final WorkspaceTab tab;
  const _AddPanelDialog({required this.tab});

  @override
  ConsumerState<_AddPanelDialog> createState() => _AddPanelDialogState();
}

class _AddPanelDialogState extends ConsumerState<_AddPanelDialog> {
  final _topicCtrl = TextEditingController();
  final _typeCtrl  = TextEditingController();
  String? _selected;

  @override
  void dispose() {
    _topicCtrl.dispose();
    _typeCtrl.dispose();
    super.dispose();
  }

  void _add() {
    final topic = _selected ?? _topicCtrl.text.trim();
    if (topic.isEmpty) return;
    ref.read(workspaceProvider.notifier).addPanel(topic, msgType: _typeCtrl.text.trim());
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final topicsAsync = ref.watch(rosTopicsProvider);
    final topics = topicsAsync.value ?? [];

    return AlertDialog(
      backgroundColor: AppTheme.bg2,
      title: Text('add topic panel', style: AppTheme.ui(size: 14, weight: FontWeight.w600)),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // dropdown from discovered topics
            if (topics.isNotEmpty) ...[
              Text('from discovered topics:',
                  style: AppTheme.ui(size: 11, color: AppTheme.textSec)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selected,
                isExpanded: true,
                decoration: InputDecoration(
                  hintText: 'select topic…',
                  filled: true,
                  fillColor: AppTheme.bg1,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                ),
                dropdownColor: AppTheme.bg2,
                style: AppTheme.mono(size: 12),
                items: topics
                    .map((t) => DropdownMenuItem(
                          value: t.name,
                          child: Text(t.name,
                              style: AppTheme.mono(size: 12),
                              overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _selected = v;
                    _topicCtrl.text = v ?? '';
                    final info = topics.firstWhere((t) => t.name == v,
                        orElse: () => topics.first);
                    _typeCtrl.text = info.type;
                  });
                },
              ),
              const SizedBox(height: 16),
              const Divider(color: AppTheme.border),
              const SizedBox(height: 8),
            ],

            // manual entry
            Text('or enter manually:',
                style: AppTheme.ui(size: 11, color: AppTheme.textSec)),
            const SizedBox(height: 8),
            TextField(
              controller: _topicCtrl,
              style: AppTheme.mono(size: 12),
              decoration: const InputDecoration(labelText: 'topic path'),
              onChanged: (_) => setState(() => _selected = null),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _typeCtrl,
              style: AppTheme.mono(size: 12),
              decoration: const InputDecoration(
                  labelText: 'message type  (optional)'),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('cancel'),
        ),
        ElevatedButton(
          onPressed: _add,
          child: const Text('add panel'),
        ),
      ],
    );
  }
}
