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

  // ── 30fps flush buffer (Bug #2 fix) ─────────────────────────────────────────
  // Instead of calling `state =` on every incoming message (which triggers a
  // full widget rebuild for every message at 100+ Hz), we buffer messages and
  // flush to the UI at most once per _kFlushInterval.
  static const _kFlushInterval = Duration(milliseconds: 33); // ~30 fps
  final _pending = <TopicMessage>[];
  Timer? _flushTimer;
  int _pendingTotal = 0; // total count including dropped frames

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
    final cfg = state.config;

    // Convert maxHz → throttle_rate (ms). 0 = no throttle.
    final throttleMs = cfg.maxHz > 0 ? (1000 ~/ cfg.maxHz) : 0;

    _subId = svc.subscribe(
      cfg.topic,
      type: cfg.msgType,
      throttleRateMs: throttleMs,
    );

    _msgSub = svc.messageStream.listen((frame) {
      if (frame['topic'] != state.config.topic) return;
      if (state.config.paused) return;

      final msg = TopicMessage.fromFrame(frame);
      _rateWindow.add(msg.receivedAt);

      // Buffer the message; flush timer will push it to the UI
      _pending.add(msg);
      _pendingTotal++;

      // Start flush timer lazily — auto-fires at ~30fps
      _flushTimer ??= Timer.periodic(_kFlushInterval, (_) => _flush());
    });
  }

  /// Drain _pending into state in a single assignment (one widget rebuild).
  void _flush() {
    if (_pending.isEmpty) {
      // Nothing arrived — cancel the timer to avoid idle ticks
      _flushTimer?.cancel();
      _flushTimer = null;
      return;
    }

    final incoming = List<TopicMessage>.of(_pending);
    _pending.clear();

    List<TopicMessage> updated;
    if (state.config.mode == PanelMode.latest) {
      updated = [incoming.last]; // only care about the newest
    } else {
      updated = [...state.messages, ...incoming];
      final max = state.config.bufferSize;
      if (updated.length > max) {
        updated = updated.sublist(updated.length - max);
      }
    }

    state = state.copyWith(
      messages: updated,
      lastReceived: incoming.last.receivedAt,
      totalCount: state.totalCount + _pendingTotal,
    );
    _pendingTotal = 0;
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
    _pending.clear();
    _pendingTotal = 0;
    state = state.copyWith(messages: []);
  }

  void setMode(PanelMode mode) {
    state = state.copyWith(config: state.config.copyWith(mode: mode));
  }

  void setBufferSize(int size) {
    state = state.copyWith(config: state.config.copyWith(bufferSize: size));
  }

  void setMaxHz(int hz) {
    // Resubscribe with new throttle rate
    _unsubscribe();
    state = state.copyWith(
      config: state.config.copyWith(maxHz: hz),
      messages: [],
    );
    _subscribe();
  }

  void toggleRawMode() {
    state = state.copyWith(rawMode: !state.rawMode);
  }

  void updateConfig(PanelConfig config) {
    final topicChanged = config.topic != state.config.topic;
    final hzChanged    = config.maxHz  != state.config.maxHz;
    state = state.copyWith(config: config, messages: topicChanged ? [] : null);
    if (topicChanged || hzChanged) {
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

  void closePanel() {
    _rateTimer?.cancel();
    _flushTimer?.cancel();
    _unsubscribe();
  }

  @override
  void dispose() {
    closePanel();
    super.dispose();
  }
}

// family provider — keyed by panel id
final panelProvider =
    StateNotifierProvider.family<PanelNotifier, PanelState, PanelConfig>(
  (ref, config) => PanelNotifier(config, ref),
);
