// lib/providers/workspace_provider.dart

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/workspace.dart';
import '../models/panel.dart';

const _uuid = Uuid();
const _prefKey = 'workspace_v1';
const _connKey  = 'connection_v1';

// ─── connection config ────────────────────────────────────────────────────────

class ConnectionConfigNotifier extends StateNotifier<ConnectionConfig> {
  ConnectionConfigNotifier() : super(const ConnectionConfig()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_connKey);
    if (raw != null) {
      try {
        state = ConnectionConfig.fromJson(jsonDecode(raw));
      } catch (_) {}
    }
  }

  Future<void> update(ConnectionConfig cfg) async {
    state = cfg;
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(_connKey, jsonEncode(cfg.toJson()));
  }
}

final connectionConfigProvider =
    StateNotifierProvider<ConnectionConfigNotifier, ConnectionConfig>(
  (ref) => ConnectionConfigNotifier(),
);

// ─── workspace ────────────────────────────────────────────────────────────────

class WorkspaceNotifier extends StateNotifier<List<WorkspaceTab>> {
  int activeIndex = 0;

  WorkspaceNotifier()
      : super([WorkspaceTab.empty('workspace 1')]) {
    _load();
  }

  WorkspaceTab get activeTab => state[activeIndex.clamp(0, state.length - 1)];

  // ── tabs ──────────────────────────────────────────────────────────────────
  void addTab({String? name}) {
    final tab = WorkspaceTab.empty(name ?? 'workspace ${state.length + 1}');
    state = [...state, tab];
    activeIndex = state.length - 1;
    _save();
  }

  void removeTab(int idx) {
    if (state.length <= 1) return;
    final next = [...state]..removeAt(idx);
    activeIndex = (idx - 1).clamp(0, next.length - 1);
    state = next;
    _save();
  }

  void renameTab(int idx, String name) {
    state = [
      for (var i = 0; i < state.length; i++)
        i == idx ? state[i].copyWith(name: name) : state[i],
    ];
    _save();
  }

  void setActive(int idx) {
    activeIndex = idx.clamp(0, state.length - 1);
    state = [...state]; // notify
  }

  // ── panels ────────────────────────────────────────────────────────────────
  void addPanel(String topic, {String msgType = '', int? tabIdx}) {
    final ti = tabIdx ?? activeIndex;
    final tab = state[ti];
    final panel = PanelConfig(
      id: _uuid.v4(),
      topic: topic,
      msgType: msgType,
    );
    state = [
      for (var i = 0; i < state.length; i++)
        i == ti ? tab.copyWith(panels: [...tab.panels, panel]) : state[i],
    ];
    _save();
  }

  void removePanel(String panelId, {int? tabIdx}) {
    final ti = tabIdx ?? activeIndex;
    final tab = state[ti];
    state = [
      for (var i = 0; i < state.length; i++)
        i == ti
            ? tab.copyWith(
                panels: tab.panels.where((p) => p.id != panelId).toList())
            : state[i],
    ];
    _save();
  }

  void updatePanel(PanelConfig updated, {int? tabIdx}) {
    final ti = tabIdx ?? activeIndex;
    final tab = state[ti];
    state = [
      for (var i = 0; i < state.length; i++)
        i == ti
            ? tab.copyWith(
                panels: tab.panels
                    .map((p) => p.id == updated.id ? updated : p)
                    .toList())
            : state[i],
    ];
    _save();
  }

  void setColumns(int cols, {int? tabIdx}) {
    final ti = tabIdx ?? activeIndex;
    state = [
      for (var i = 0; i < state.length; i++)
        i == ti ? state[i].copyWith(columns: cols.clamp(1, 4)) : state[i],
    ];
    _save();
  }

  // ── persistence ───────────────────────────────────────────────────────────
  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(state.map((t) => t.toJson()).toList());
    prefs.setString(_prefKey, raw);
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw != null) {
      try {
        final list = (jsonDecode(raw) as List)
            .map((e) => WorkspaceTab.fromJson(e as Map<String, dynamic>))
            .toList();
        if (list.isNotEmpty) {
          state = list;
        }
      } catch (_) {}
    }
  }
}

final workspaceProvider =
    StateNotifierProvider<WorkspaceNotifier, List<WorkspaceTab>>(
  (ref) => WorkspaceNotifier(),
);
