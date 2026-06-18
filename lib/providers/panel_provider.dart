// lib/providers/panel_provider.dart

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/panel.dart';
import '../models/rosbridge.dart';
import '../services/rosbridge_service.dart';

// ─── per-panel notifier ───────────────────────────────────────────────────────

class PanelNotifier extends StateNotifier<PanelState> {
  final Ref _ref;
  StreamSubscription? _msgSub;
  String? _subId;

  // rate tracking
  final _rateWindow = <DateTime>[];
  Timer? _rateTimer;

  PanelNotifier(PanelConfig config, this._ref)
      : super(PanelState(config: config)) {
    _subscribe();
    _rateTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _updateRate(),
    );
  }

  void _subscribe() {
    final svc = _ref.read(rosBridgeServiceProvider);
    _subId = svc.subscribe(state.config.topic, type: state.config.msgType);

    _msgSub = svc.messageStream.listen((frame) {
      if (frame['topic'] != state.config.topic) return;
      if (state.config.paused) return;

      final msg = TopicMessage.fromFrame(frame);
      _rateWindow.add(msg.receivedAt);

      List<TopicMessage> updated;
      if (state.config.mode == PanelMode.latest) {
        updated = [msg];
      } else {
        updated = [...state.messages, msg];
        final max = state.config.bufferSize;
        if (updated.length > max) {
          updated = updated.sublist(updated.length - max);
        }
      }

      state = state.copyWith(
        messages: updated,
        lastReceived: msg.receivedAt,
        totalCount: state.totalCount + 1,
      );
    });
  }

  void _updateRate() {
    final cutoff = DateTime.now().subtract(const Duration(seconds: 2));
    _rateWindow.removeWhere((t) => t.isBefore(cutoff));
    final rate = _rateWindow.length / 2.0;
    state = state.copyWith(msgRate: rate);
  }

  void togglePause() {
    state = state.copyWith(
      config: state.config.copyWith(paused: !state.config.paused),
    );
  }

  void clearBuffer() {
    state = state.copyWith(messages: []);
  }

  void setMode(PanelMode mode) {
    state = state.copyWith(config: state.config.copyWith(mode: mode));
  }

  void setBufferSize(int size) {
    state = state.copyWith(config: state.config.copyWith(bufferSize: size));
  }

  void updateConfig(PanelConfig config) {
    // resubscribe if topic changed
    final topicChanged = config.topic != state.config.topic;
    state = state.copyWith(config: config, messages: topicChanged ? [] : null);
    if (topicChanged) {
      _unsubscribe();
      _subscribe();
    }
  }

  void _unsubscribe() {
    if (_subId != null) {
      _ref.read(rosBridgeServiceProvider).unsubscribe(_subId!, state.config.topic);
    }
    _msgSub?.cancel();
    _msgSub = null;
    _subId = null;
  }

  @override
  void dispose() {
    _rateTimer?.cancel();
    _unsubscribe();
    super.dispose();
  }
}

// family provider — keyed by panel id
final panelProvider =
    StateNotifierProvider.family<PanelNotifier, PanelState, PanelConfig>(
  (ref, config) => PanelNotifier(config, ref),
);
