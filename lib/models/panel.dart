// lib/models/panel.dart

import 'package:flutter/foundation.dart';
import 'rosbridge.dart';

enum PanelMode { latest, streaming, history }

class PanelConfig {
  final String id;
  final String topic;
  final String msgType;
  final PanelMode mode;
  final int bufferSize;
  final bool paused;
  final bool pinned;

  const PanelConfig({
    required this.id,
    required this.topic,
    this.msgType = '',
    this.mode = PanelMode.streaming,
    this.bufferSize = 100,
    this.paused = false,
    this.pinned = false,
  });

  PanelConfig copyWith({
    String? topic,
    String? msgType,
    PanelMode? mode,
    int? bufferSize,
    bool? paused,
    bool? pinned,
  }) =>
      PanelConfig(
        id: id,
        topic: topic ?? this.topic,
        msgType: msgType ?? this.msgType,
        mode: mode ?? this.mode,
        bufferSize: bufferSize ?? this.bufferSize,
        paused: paused ?? this.paused,
        pinned: pinned ?? this.pinned,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'topic': topic,
        'msgType': msgType,
        'mode': mode.name,
        'bufferSize': bufferSize,
        'pinned': pinned,
      };

  factory PanelConfig.fromJson(Map<String, dynamic> j) => PanelConfig(
        id: j['id'] as String,
        topic: j['topic'] as String,
        msgType: j['msgType'] as String? ?? '',
        mode: PanelMode.values.firstWhere(
          (e) => e.name == j['mode'],
          orElse: () => PanelMode.streaming,
        ),
        bufferSize: j['bufferSize'] as int? ?? 100,
        pinned: j['pinned'] as bool? ?? false,
      );
}

class PanelState {
  final PanelConfig config;
  final List<TopicMessage> messages;
  final double msgRate;          // Hz
  final DateTime? lastReceived;
  final int totalCount;

  const PanelState({
    required this.config,
    this.messages = const [],
    this.msgRate = 0,
    this.lastReceived,
    this.totalCount = 0,
  });

  PanelState copyWith({
    PanelConfig? config,
    List<TopicMessage>? messages,
    double? msgRate,
    DateTime? lastReceived,
    int? totalCount,
  }) =>
      PanelState(
        config: config ?? this.config,
        messages: messages ?? this.messages,
        msgRate: msgRate ?? this.msgRate,
        lastReceived: lastReceived ?? this.lastReceived,
        totalCount: totalCount ?? this.totalCount,
      );
}
