// lib/models/workspace.dart

import 'package:uuid/uuid.dart';
import 'panel.dart';

const _uuid = Uuid();

class WorkspaceTab {
  final String id;
  final String name;
  final List<PanelConfig> panels;
  final int columns;

  const WorkspaceTab({
    required this.id,
    required this.name,
    this.panels = const [],
    this.columns = 2,
  });

  WorkspaceTab copyWith({
    String? name,
    List<PanelConfig>? panels,
    int? columns,
  }) =>
      WorkspaceTab(
        id: id,
        name: name ?? this.name,
        panels: panels ?? this.panels,
        columns: columns ?? this.columns,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'columns': columns,
        'panels': panels.map((p) => p.toJson()).toList(),
      };

  factory WorkspaceTab.fromJson(Map<String, dynamic> j) => WorkspaceTab(
        id: j['id'] as String,
        name: j['name'] as String,
        columns: j['columns'] as int? ?? 2,
        panels: (j['panels'] as List? ?? [])
            .map((p) => PanelConfig.fromJson(p as Map<String, dynamic>))
            .toList(),
      );

  factory WorkspaceTab.empty(String name) =>
      WorkspaceTab(id: _uuid.v4(), name: name);
}

class ConnectionConfig {
  final String host;
  final int port;
  final bool autoReconnect;

  const ConnectionConfig({
    this.host = 'localhost',
    this.port = 9090,
    this.autoReconnect = true,
  });

  String get uri => 'ws://$host:$port';

  ConnectionConfig copyWith({String? host, int? port, bool? autoReconnect}) =>
      ConnectionConfig(
        host: host ?? this.host,
        port: port ?? this.port,
        autoReconnect: autoReconnect ?? this.autoReconnect,
      );

  Map<String, dynamic> toJson() =>
      {'host': host, 'port': port, 'autoReconnect': autoReconnect};

  factory ConnectionConfig.fromJson(Map<String, dynamic> j) =>
      ConnectionConfig(
        host: j['host'] as String? ?? 'localhost',
        port: j['port'] as int? ?? 9090,
        autoReconnect: j['autoReconnect'] as bool? ?? true,
      );
}
