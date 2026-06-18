// lib/widgets/topic_panel.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/panel.dart';
import '../models/rosbridge.dart';
import '../providers/panel_provider.dart';
import '../providers/workspace_provider.dart';
import '../theme/app_theme.dart';

final _timeFmt = DateFormat('HH:mm:ss.SSS');

// Hz options shown in the limiter dropdown
const _kHzOptions = [0, 5, 10, 20, 30, 50];

class TopicPanel extends ConsumerWidget {
  final PanelConfig config;

  const TopicPanel({super.key, required this.config});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(panelProvider(config));

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bg1,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          _PanelHeader(config: config, state: state),
          const Divider(height: 1, color: AppTheme.border),
          Expanded(child: _PanelBody(state: state)),
        ],
      ),
    );
  }
}

// ── header ────────────────────────────────────────────────────────────────────

class _PanelHeader extends ConsumerWidget {
  final PanelConfig config;
  final PanelState state;

  const _PanelHeader({required this.config, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ns = config.topic.contains('/')
        ? '/${config.topic.split('/')[1]}'
        : '';
    final shortTopic = config.topic.replaceFirst(ns, '');
    final isLive = state.lastReceived != null &&
        DateTime.now().difference(state.lastReceived!).inSeconds < 3;

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: AppTheme.bg2,
      child: Row(
        children: [
          // live indicator
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isLive ? AppTheme.accentAlt : AppTheme.textMuted,
            ),
          ),
          const SizedBox(width: 6),

          // namespace in accent
          if (ns.isNotEmpty) ...[
            Text(ns,
                style: AppTheme.mono(
                    size: 10,
                    color: AppTheme.accent,
                    weight: FontWeight.w500)),
            Text(shortTopic,
                style: AppTheme.mono(size: 10, color: AppTheme.textSec)),
          ] else
            Text(config.topic,
                style: AppTheme.mono(size: 10, color: AppTheme.textSec)),

          const Spacer(),

          // rate
          Text(
            '${state.msgRate.toStringAsFixed(1)} Hz',
            style: AppTheme.mono(size: 10, color: AppTheme.textMuted),
          ),
          const SizedBox(width: 8),

          // msg count
          Text(
            '${state.totalCount}',
            style: AppTheme.mono(size: 10, color: AppTheme.textMuted),
          ),
          const SizedBox(width: 8),

          // Hz limiter dropdown
          _HzChip(config: config),
          const SizedBox(width: 4),

          // mode dropdown
          _ModeChip(config: config),
          const SizedBox(width: 4),

          // RAW toggle
          _IconBtn(
            icon: state.rawMode ? Icons.data_object : Icons.account_tree_outlined,
            tooltip: state.rawMode ? 'tree view' : 'raw JSON',
            active: state.rawMode,
            onTap: () => ref.read(panelProvider(config).notifier).toggleRawMode(),
          ),

          // pause
          _IconBtn(
            icon: config.paused ? Icons.play_arrow : Icons.pause,
            tooltip: config.paused ? 'resume' : 'pause',
            onTap: () => ref.read(panelProvider(config).notifier).togglePause(),
          ),

          // clear
          _IconBtn(
            icon: Icons.delete_sweep_outlined,
            tooltip: 'clear',
            onTap: () => ref.read(panelProvider(config).notifier).clearBuffer(),
          ),

          // copy latest
          _IconBtn(
            icon: Icons.copy_outlined,
            tooltip: 'copy latest message',
            onTap: () {
              if (state.messages.isNotEmpty) {
                Clipboard.setData(ClipboardData(
                    text: const JsonEncoder.withIndent('  ')
                        .convert(state.messages.last.msg)));
              }
            },
          ),

          // close
          _IconBtn(
            icon: Icons.close,
            tooltip: 'close panel',
            onTap: () => ref
                .read(workspaceProvider.notifier)
                .removePanel(config.id),
          ),
        ],
      ),
    );
  }
}

// ── Hz limiter chip ───────────────────────────────────────────────────────────

class _HzChip extends ConsumerWidget {
  final PanelConfig config;
  const _HzChip({required this.config});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<int>(
      initialValue: config.maxHz,
      tooltip: 'limit update rate',
      onSelected: (hz) => ref.read(panelProvider(config).notifier).setMaxHz(hz),
      itemBuilder: (_) => [
        for (final hz in _kHzOptions)
          PopupMenuItem(
            value: hz,
            child: Text(hz == 0 ? 'unlimited' : '$hz Hz',
                style: AppTheme.ui(size: 12)),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: config.maxHz > 0 ? AppTheme.warn : AppTheme.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.speed,
                size: 10,
                color: config.maxHz > 0 ? AppTheme.warn : AppTheme.textMuted),
            const SizedBox(width: 3),
            Text(
              config.maxHz == 0 ? '∞' : '${config.maxHz}Hz',
              style: AppTheme.ui(
                  size: 9,
                  color: config.maxHz > 0 ? AppTheme.warn : AppTheme.textSec),
            ),
          ],
        ),
      ),
    );
  }
}

// ── mode chip ─────────────────────────────────────────────────────────────────

class _ModeChip extends ConsumerWidget {
  final PanelConfig config;
  const _ModeChip({required this.config});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<PanelMode>(
      initialValue: config.mode,
      onSelected: (m) =>
          ref.read(panelProvider(config).notifier).setMode(m),
      itemBuilder: (_) => const [
        PopupMenuItem(value: PanelMode.latest,    child: Text('latest only')),
        PopupMenuItem(value: PanelMode.streaming, child: Text('streaming')),
        PopupMenuItem(value: PanelMode.history,   child: Text('history')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(config.mode.name,
                style: AppTheme.ui(size: 9, color: AppTheme.textSec)),
            const Icon(Icons.arrow_drop_down,
                size: 12, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}

// ── body ──────────────────────────────────────────────────────────────────────

class _PanelBody extends StatefulWidget {
  final PanelState state;
  const _PanelBody({required this.state});

  @override
  State<_PanelBody> createState() => _PanelBodyState();
}

class _PanelBodyState extends State<_PanelBody> {
  final _scrollCtrl = ScrollController();
  bool _autoScroll = true;

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_PanelBody old) {
    super.didUpdateWidget(old);
    if (_autoScroll &&
        widget.state.messages.length != old.state.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final msgs = widget.state.messages;
    if (msgs.isEmpty) {
      return Center(
        child: Text(
          widget.state.config.paused ? 'paused' : 'waiting for messages…',
          style: AppTheme.ui(size: 11, color: AppTheme.textMuted),
        ),
      );
    }

    // RAW mode: full pretty-printed JSON of last message
    if (widget.state.rawMode) {
      return _RawJsonView(msg: msgs.last);
    }

    // latest-only: show JSON tree of last message
    if (widget.state.config.mode == PanelMode.latest) {
      return _JsonTree(msg: msgs.last.msg, ts: msgs.last.receivedAt);
    }

    // streaming / history: scrollable list
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollEndNotification) {
          final atBottom = _scrollCtrl.position.pixels >=
              _scrollCtrl.position.maxScrollExtent - 20;
          if (_autoScroll != atBottom) setState(() => _autoScroll = atBottom);
        }
        return false;
      },
      child: Stack(
        children: [
          ListView.builder(
            controller: _scrollCtrl,
            itemCount: msgs.length,
            itemBuilder: (_, i) => _MessageRow(msg: msgs[i]),
          ),
          if (!_autoScroll)
            Positioned(
              bottom: 8,
              right: 8,
              child: FloatingActionButton.small(
                heroTag: null,
                backgroundColor: AppTheme.bg3,
                onPressed: () {
                  setState(() => _autoScroll = true);
                  _scrollCtrl.animateTo(
                    _scrollCtrl.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                  );
                },
                child: const Icon(Icons.arrow_downward, size: 16),
              ),
            ),
        ],
      ),
    );
  }
}

// ── raw JSON view ─────────────────────────────────────────────────────────────

class _RawJsonView extends StatelessWidget {
  final TopicMessage msg;
  const _RawJsonView({required this.msg});

  @override
  Widget build(BuildContext context) {
    final text = const JsonEncoder.withIndent('  ').convert(msg.msg);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: SelectableText(
        text,
        style: AppTheme.mono(size: 11, color: AppTheme.textPrim),
      ),
    );
  }
}

// ── single message row ────────────────────────────────────────────────────────

class _MessageRow extends StatefulWidget {
  final TopicMessage msg;
  const _MessageRow({required this.msg});

  @override
  State<_MessageRow> createState() => _MessageRowState();
}

class _MessageRowState extends State<_MessageRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final ts = _timeFmt.format(widget.msg.receivedAt);
    final preview = _flatPreview(widget.msg.msg);

    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.border, width: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(ts,
                    style: AppTheme.mono(size: 10, color: AppTheme.accent)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _expanded ? '' : preview,
                    style: AppTheme.mono(size: 11, color: AppTheme.textSec),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 13,
                  color: AppTheme.textMuted,
                ),
              ],
            ),
            if (_expanded) _JsonTree(msg: widget.msg.msg),
          ],
        ),
      ),
    );
  }

  String _flatPreview(Map<String, dynamic> msg) {
    try {
      return jsonEncode(msg).replaceAll(RegExp(r'\s+'), ' ');
    } catch (_) {
      return msg.toString();
    }
  }
}

// ── JSON tree ─────────────────────────────────────────────────────────────────

// Threshold: arrays longer than this are shown as a summary pill instead of
// being fully rendered (prevents UI freeze on PointCloud2, Image, etc.)
const _kMaxInlineList = 32;
const _kMaxDepth = 10;

class _JsonTree extends StatelessWidget {
  final Map<String, dynamic> msg;
  final DateTime? ts;

  const _JsonTree({required this.msg, this.ts});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: _buildNode(msg, 0),
    );
  }

  Widget _buildNode(dynamic value, int depth) {
    if (depth >= _kMaxDepth) {
      return Text('…',
          style: AppTheme.mono(size: 10, color: AppTheme.textMuted));
    }

    if (value is Map) {
      if (value.isEmpty) {
        return Text('{}',
            style: AppTheme.mono(size: 11, color: AppTheme.textMuted));
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: value.entries.map((e) {
          return Padding(
            padding: EdgeInsets.only(left: depth * 12.0),
            child: _isLeaf(e.value)
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${e.key}: ',
                          style: AppTheme.mono(
                              size: 11, color: AppTheme.textSec)),
                      Expanded(
                        child: Text(
                          _formatLeaf(e.value),
                          style: AppTheme.mono(
                              size: 11, color: _leafColor(e.value)),
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${e.key}:',
                          style: AppTheme.mono(
                              size: 11,
                              color: AppTheme.accent,
                              weight: FontWeight.w500)),
                      _buildNode(e.value, depth + 1),
                    ],
                  ),
          );
        }).toList(),
      );
    }

    if (value is List) {
      return _buildList(value, depth);
    }

    return Text(_formatLeaf(value),
        style: AppTheme.mono(size: 11, color: _leafColor(value)));
  }

  Widget _buildList(List<dynamic> list, int depth) {
    if (list.isEmpty) {
      return Text('[]',
          style: AppTheme.mono(size: 11, color: AppTheme.textMuted));
    }

    // ── integer / byte array ─────────────────────────────────────────────────
    // ROS byte arrays (uint8[], int8[], etc.) arrive as large int lists.
    // Rendering them would freeze the UI; show a summary pill instead.
    if (list.every((e) => e is int)) {
      if (list.length > _kMaxInlineList) {
        return _ArraySummaryPill(
          label: '📦 byte array',
          count: list.length,
          detail: 'int[${list.length}]',
          onCopy: () {
            // Copy as comma-separated hex for debugging
            final hex = list.take(64).map((e) => '0x${(e as int).toRadixString(16).padLeft(2, '0')}').join(', ');
            final suffix = list.length > 64 ? ', … (+${list.length - 64} more)' : '';
            Clipboard.setData(ClipboardData(text: '$hex$suffix'));
          },
        );
      }
      // Short int array — show inline
      return Text(
        '[${list.join(', ')}]',
        style: AppTheme.mono(size: 10, color: AppTheme.textMuted),
      );
    }

    // ── float array ─────────────────────────────────────────────────────────
    // float32[] / float64[] descriptors, pose covariance, etc.
    if (list.every((e) => e is num)) {
      if (list.length > _kMaxInlineList) {
        final nums = list.cast<num>();
        final mn = nums.reduce((a, b) => a < b ? a : b);
        final mx = nums.reduce((a, b) => a > b ? a : b);
        final preview = nums.take(6).map((e) {
          if (e is double) return e.toStringAsFixed(3);
          return e.toString();
        }).join(', ');
        return _ArraySummaryPill(
          label: '〜 float array',
          count: list.length,
          detail: 'float[${list.length}]  min=${mn.toStringAsFixed(4)}  max=${mx.toStringAsFixed(4)}',
          preview: '[$preview …]',
          onCopy: () {
            final csv = nums.map((e) => e.toString()).join(', ');
            Clipboard.setData(ClipboardData(text: csv));
          },
        );
      }
      // Short float array — same compact display as before
      final preview = list.take(8).map((e) {
        if (e is double) return e.toStringAsFixed(4);
        return e.toString();
      }).join(', ');
      final suffix = list.length > 8 ? '… (${list.length})' : '';
      return Text(
        '[$preview$suffix]',
        style: AppTheme.mono(size: 10, color: AppTheme.textMuted),
      );
    }

    // ── generic list (nested messages, strings, mixed) ───────────────────────
    if (list.length > _kMaxInlineList) {
      // Show first few items + count
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...list.take(8).toList().asMap().entries.map((e) {
            return Padding(
              padding: EdgeInsets.only(left: depth * 12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('[${e.key}] ',
                      style: AppTheme.mono(size: 10, color: AppTheme.textMuted)),
                  Expanded(child: _buildNode(e.value, depth + 1)),
                ],
              ),
            );
          }),
          Padding(
            padding: EdgeInsets.only(left: depth * 12.0),
            child: Text(
              '  … and ${list.length - 8} more items',
              style: AppTheme.mono(size: 10, color: AppTheme.textMuted),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: list.asMap().entries.map((e) {
        return Padding(
          padding: EdgeInsets.only(left: depth * 12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('[${e.key}] ',
                  style: AppTheme.mono(
                      size: 10, color: AppTheme.textMuted)),
              Expanded(child: _buildNode(e.value, depth + 1)),
            ],
          ),
        );
      }).toList(),
    );
  }

  bool _isLeaf(dynamic v) =>
      v is String || v is num || v is bool || v == null;

  String _formatLeaf(dynamic v) {
    if (v == null) return 'null';
    if (v is double) return v.toStringAsFixed(6);
    return v.toString();
  }

  Color _leafColor(dynamic v) {
    if (v is num)  return const Color(0xFF79C0FF);  // blue
    if (v is bool) return AppTheme.warn;
    if (v == null) return AppTheme.textMuted;
    return const Color(0xFFA5D6FF);  // string — lighter blue
  }
}

// ── array summary pill ────────────────────────────────────────────────────────

class _ArraySummaryPill extends StatelessWidget {
  final String label;
  final int count;
  final String detail;
  final String? preview;
  final VoidCallback onCopy;

  const _ArraySummaryPill({
    required this.label,
    required this.count,
    required this.detail,
    this.preview,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: detail,
      child: InkWell(
        onTap: onCopy,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: AppTheme.bg3,
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$label ($count)',
                style: AppTheme.mono(size: 10, color: AppTheme.textSec),
              ),
              if (preview != null) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    preview!,
                    style: AppTheme.mono(size: 10, color: AppTheme.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const SizedBox(width: 6),
              const Icon(Icons.copy, size: 10, color: AppTheme.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

// ── helpers ───────────────────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;

  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon,
              size: 14,
              color: active ? AppTheme.accent : AppTheme.textMuted),
        ),
      ),
    );
  }
}
