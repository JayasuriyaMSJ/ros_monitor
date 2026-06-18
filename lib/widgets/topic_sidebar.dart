// lib/widgets/topic_sidebar.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/rosbridge.dart';
import '../providers/workspace_provider.dart';
import '../services/rosbridge_service.dart';
import '../theme/app_theme.dart';

class TopicSidebar extends ConsumerStatefulWidget {
  const TopicSidebar({super.key});

  @override
  ConsumerState<TopicSidebar> createState() => _TopicSidebarState();
}

class _TopicSidebarState extends ConsumerState<TopicSidebar> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  final Set<String> _expanded = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topicsAsync = ref.watch(rosTopicsProvider);

    return Container(
      width: 260,
      color: AppTheme.bg1,
      child: Column(
        children: [
          // header
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                Text('topics',
                    style: AppTheme.ui(
                        size: 11,
                        color: AppTheme.textSec,
                        weight: FontWeight.w600)),
                const Spacer(),
                topicsAsync.when(
                  data: (t) => Text('${t.length}',
                      style: AppTheme.ui(size: 11, color: AppTheme.textMuted)),
                  loading: () => const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.5)),
                  error: (e, _) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),

          // search
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _searchCtrl,
              style: AppTheme.mono(size: 11),
              decoration: InputDecoration(
                hintText: 'filter topics…',
                prefixIcon:
                    const Icon(Icons.search, size: 14, color: AppTheme.textMuted),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 13),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
            ),
          ),

          // topic tree
          Expanded(
            child: topicsAsync.when(
              data: (topics) => _buildTree(topics),
              loading: () => const Center(
                child: Text('waiting for topics…',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              ),
              error: (e, _) => Center(
                child: Text('error: $e',
                    style: const TextStyle(
                        color: AppTheme.err, fontSize: 11)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTree(List<RosTopicInfo> topics) {
    final filtered = _query.isEmpty
        ? topics
        : topics.where((t) => t.name.toLowerCase().contains(_query)).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          _query.isEmpty ? 'no topics\nconnect and click refresh' : 'no matches',
          textAlign: TextAlign.center,
          style: AppTheme.ui(size: 11, color: AppTheme.textMuted),
        ),
      );
    }

    // group by namespace
    final grouped = <String, List<RosTopicInfo>>{};
    for (final t in filtered) {
      grouped.putIfAbsent(t.namespace, () => []).add(t);
    }
    final namespaces = grouped.keys.toList()..sort();

    return ListView(
      children: [
        for (final ns in namespaces) ...[
          _NamespaceHeader(
            namespace: ns,
            count: grouped[ns]!.length,
            expanded: _expanded.contains(ns),
            onTap: () => setState(() {
              if (_expanded.contains(ns)) {
                _expanded.remove(ns);
              } else {
                _expanded.add(ns);
              }
            }),
          ),
          if (_expanded.contains(ns) || _query.isNotEmpty)
            for (final t in grouped[ns]!)
              _TopicRow(
                topic: t,
                onAdd: () => _addPanel(t),
              ),
        ],
      ],
    );
  }

  void _addPanel(RosTopicInfo t) {
    ref.read(workspaceProvider.notifier).addPanel(t.name, msgType: t.type);
  }
}

class _NamespaceHeader extends StatelessWidget {
  final String namespace;
  final int count;
  final bool expanded;
  final VoidCallback onTap;

  const _NamespaceHeader({
    required this.namespace,
    required this.count,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        color: AppTheme.bg2,
        child: Row(
          children: [
            Icon(
              expanded ? Icons.expand_more : Icons.chevron_right,
              size: 14,
              color: AppTheme.textSec,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                namespace,
                style: AppTheme.mono(
                    size: 11,
                    color: AppTheme.accent,
                    weight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text('$count',
                style: AppTheme.ui(size: 10, color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  final RosTopicInfo topic;
  final VoidCallback onAdd;

  const _TopicRow({required this.topic, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final shortName = topic.name.replaceFirst(topic.namespace, '');

    return InkWell(
      onTap: onAdd,
      child: Padding(
        padding: const EdgeInsets.only(left: 24, right: 8, top: 3, bottom: 3),
        child: Row(
          children: [
            const Icon(Icons.radio_button_unchecked,
                size: 8, color: AppTheme.textMuted),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shortName,
                    style: AppTheme.mono(size: 11, color: AppTheme.textPrim),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (topic.type.isNotEmpty)
                    Text(
                      topic.type.split('/').last,
                      style: AppTheme.ui(size: 9, color: AppTheme.textMuted),
                    ),
                ],
              ),
            ),
            Tooltip(
              message: 'add panel',
              child: Icon(Icons.add, size: 14, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
